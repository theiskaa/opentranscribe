import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/core/export/stored_zip.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('stored_zip_test');
  });

  tearDown(() async {
    await temp.delete(recursive: true);
  });

  File target(String name) => File('${temp.path}/$name');

  Future<File> writeZip(Map<String, List<int>> files, {String name = 'a.zip'}) async {
    final file = target(name);
    final writer = await StoredZipWriter.create(file);
    for (final entry in files.entries) {
      await writer.addBytes(entry.key, entry.value);
    }
    await writer.close();
    return file;
  }

  test('a written zip reads back byte-identical files', () async {
    final files = {
      'manifest.json': utf8.encode('{"a":1}'),
      'entries/one.json': utf8.encode('{"id":"one"}'),
      'audio/otr-1.m4a': List<int>.generate(4096, (i) => i % 251),
    };
    final reader = await StoredZipReader.open(await writeZip(files));
    expect(reader.paths.toSet(), files.keys.toSet());
    for (final entry in files.entries) {
      expect(await reader.readBytes(entry.key), entry.value);
      expect(reader.sizeOf(entry.key), entry.value.length);
    }
    await reader.close();
  });

  test('an empty zip round-trips', () async {
    final reader = await StoredZipReader.open(await writeZip({}));
    expect(reader.paths, isEmpty);
    await reader.close();
  });

  test('a zero-length last entry round-trips', () async {
    final reader = await StoredZipReader.open(
      await writeZip({'a.txt': utf8.encode('x'), 'empty.bin': <int>[]}),
    );
    expect(await reader.readBytes('empty.bin'), isEmpty);
    await reader.close();
  });

  test('utf-8 entry names round-trip', () async {
    const name = 'notes/走った日 тест.md';
    final reader = await StoredZipReader.open(await writeZip({name: utf8.encode('hello')}));
    expect(reader.paths, [name]);
    expect(utf8.decode(await reader.readBytes(name)), 'hello');
    await reader.close();
  });

  test('a streamed file with a multi-byte name round-trips', () async {
    final source = target('source2.bin');
    await source.writeAsBytes(List<int>.generate(2048, (i) => (i * 13) % 256));
    final file = target('utf8name.zip');
    final writer = await StoredZipWriter.create(file);
    await writer.addFile('audio/走った.m4a', source);
    await writer.addBytes('after.txt', utf8.encode('aligned'));
    await writer.close();
    final reader = await StoredZipReader.open(file);
    expect(await reader.readBytes('audio/走った.m4a'), await source.readAsBytes());
    expect(utf8.decode(await reader.readBytes('after.txt')), 'aligned');
    await reader.close();
  });

  test('addFile produces the same bytes as addBytes of the same content', () async {
    final content = List<int>.generate(100000, (i) => (i * 7) % 256);
    final source = target('same.bin');
    await source.writeAsBytes(content);

    final streamed = target('streamed-det.zip');
    final w1 = await StoredZipWriter.create(streamed);
    await w1.addFile('a.bin', source);
    await w1.close();

    final buffered = target('buffered-det.zip');
    final w2 = await StoredZipWriter.create(buffered);
    await w2.addBytes('a.bin', content);
    await w2.close();

    expect(await streamed.readAsBytes(), await buffered.readAsBytes());
  });

  test('a streamed file round-trips through addFile and extractToFile', () async {
    final source = target('source.bin');
    final bytes = List<int>.generate(3 * 1024 * 1024 + 17, (i) => (i * 31) % 256);
    await source.writeAsBytes(bytes);
    final file = target('streamed.zip');
    final writer = await StoredZipWriter.create(file);
    await writer.addFile('audio/big.m4a', source);
    await writer.addBytes('after.txt', utf8.encode('still fine'));
    await writer.close();

    final reader = await StoredZipReader.open(file);
    final extracted = target('extracted.bin');
    await reader.extractToFile('audio/big.m4a', extracted);
    expect(await extracted.readAsBytes(), bytes);
    expect(utf8.decode(await reader.readBytes('after.txt')), 'still fine');
    await reader.close();
  });

  test('a corrupted data byte reads as malformed, and extraction leaves no file', () async {
    final file = await writeZip({'a.txt': utf8.encode('hello world')});
    final bytes = await file.readAsBytes();
    final data = ascii.encode('hello world');
    final start = _indexOf(bytes, data);
    bytes[start] ^= 0xff;
    await file.writeAsBytes(bytes);

    final reader = await StoredZipReader.open(file);
    await expectLater(reader.readBytes('a.txt'), throwsA(_zipError(StoredZipError.malformed)));
    final out = target('out.txt');
    await expectLater(
      reader.extractToFile('a.txt', out),
      throwsA(_zipError(StoredZipError.malformed)),
    );
    expect(out.existsSync(), isFalse);
    expect(File('${out.path}.partial').existsSync(), isFalse);
    await reader.close();
  });

  test('a compressed entry is rejected as unsupported, not malformed', () async {
    final file = await writeZip({'a.txt': utf8.encode('hello')});
    final bytes = await file.readAsBytes();
    final end = ByteData.sublistView(bytes, bytes.length - 22);
    final directoryOffset = end.getUint32(16, Endian.little);
    bytes[8] = 8;
    bytes[directoryOffset + 10] = 8;
    await file.writeAsBytes(bytes);

    await expectLater(StoredZipReader.open(file), throwsA(_zipError(StoredZipError.unsupported)));
  });

  test('trailing garbage reads as malformed', () async {
    final file = await writeZip({'a.txt': utf8.encode('hello')});
    await file.writeAsBytes([1, 2, 3], mode: FileMode.append);
    await expectLater(StoredZipReader.open(file), throwsA(_zipError(StoredZipError.malformed)));
  });

  test('a non-zip file reads as malformed', () async {
    final file = target('noise.bin');
    await file.writeAsBytes(List<int>.generate(100, (i) => (i * 7) % 256));
    await expectLater(StoredZipReader.open(file), throwsA(_zipError(StoredZipError.malformed)));
  });

  test('a file shorter than an end record reads as malformed', () async {
    final file = target('tiny.bin');
    await file.writeAsBytes([1, 2, 3]);
    await expectLater(StoredZipReader.open(file), throwsA(_zipError(StoredZipError.malformed)));
  });

  test('a truncated archive reads as malformed', () async {
    final file = await writeZip({'a.txt': utf8.encode('hello world, again')});
    final bytes = await file.readAsBytes();
    await file.writeAsBytes(bytes.sublist(10));
    await expectLater(StoredZipReader.open(file), throwsA(_zipError(StoredZipError.malformed)));
  });

  test('a traversing entry name reads as malformed', () async {
    final file = await writeZip({'aa/evil.txt': utf8.encode('x')});
    final bytes = await file.readAsBytes();
    _replaceAll(bytes, utf8.encode('aa/evil.txt'), utf8.encode('../evil.txt'));
    await file.writeAsBytes(bytes);
    await expectLater(StoredZipReader.open(file), throwsA(_zipError(StoredZipError.malformed)));
  });

  test('overlapping entries read as malformed', () async {
    final file = await writeZip({'a.txt': utf8.encode('hello'), 'b.txt': utf8.encode('world')});
    final bytes = await file.readAsBytes();
    final end = ByteData.sublistView(bytes, bytes.length - 22);
    final directoryOffset = end.getUint32(16, Endian.little);
    final secondEntry = directoryOffset + 46 + 'a.txt'.length;
    ByteData.sublistView(bytes).setUint32(secondEntry + 42, 0, Endian.little);
    await file.writeAsBytes(bytes);
    await expectLater(StoredZipReader.open(file), throwsA(_zipError(StoredZipError.malformed)));
  });

  test('an end record count mismatch reads as malformed', () async {
    final file = await writeZip({'a.txt': utf8.encode('one'), 'b.txt': utf8.encode('two')});
    final bytes = await file.readAsBytes();
    ByteData.sublistView(bytes, bytes.length - 22).setUint16(10, 1, Endian.little);
    await file.writeAsBytes(bytes);
    await expectLater(StoredZipReader.open(file), throwsA(_zipError(StoredZipError.malformed)));
  });

  test('zip64 sentinels read as unsupported, not malformed', () async {
    final file = await writeZip({'a.txt': utf8.encode('x')});
    final bytes = await file.readAsBytes();
    ByteData.sublistView(bytes, bytes.length - 22).setUint16(10, 0xffff, Endian.little);
    await file.writeAsBytes(bytes);
    await expectLater(StoredZipReader.open(file), throwsA(_zipError(StoredZipError.unsupported)));
  });

  test('a failed add poisons the writer and abort is the exit', () async {
    final file = target('poisoned.zip');
    final writer = await StoredZipWriter.create(file);
    await writer.addBytes('ok.txt', utf8.encode('fine'));
    await expectLater(
      writer.addFile('gone.bin', target('does-not-exist.bin')),
      throwsA(isA<FileSystemException>()),
    );
    expect(() => writer.addBytes('more.txt', []), throwsStateError);
    await expectLater(writer.close(), throwsStateError);
    await writer.abort();
    await expectLater(StoredZipReader.open(file), throwsA(_zipError(StoredZipError.malformed)));
  });

  test('close is idempotent once succeeded', () async {
    final writer = await StoredZipWriter.create(target('twice.zip'));
    await writer.addBytes('a.txt', utf8.encode('x'));
    await writer.close();
    await writer.close();
  });

  test('the writer refuses duplicate paths', () async {
    final writer = await StoredZipWriter.create(target('dup.zip'));
    await writer.addBytes('a.txt', utf8.encode('x'));
    expect(() => writer.addBytes('a.txt', utf8.encode('y')), throwsArgumentError);
    await writer.close();
  });

  test('the writer refuses absolute and traversing paths', () async {
    final writer = await StoredZipWriter.create(target('bad.zip'));
    expect(() => writer.addBytes('/etc/passwd', []), throwsArgumentError);
    expect(() => writer.addBytes('a/../b.txt', []), throwsArgumentError);
    expect(() => writer.addBytes('a/./b.txt', []), throwsArgumentError);
    expect(() => writer.addBytes(r'a\b.txt', []), throwsArgumentError);
    expect(() => writer.addBytes('a:b.txt', []), throwsArgumentError);
    expect(() => writer.addBytes('a//b.txt', []), throwsArgumentError);
    expect(() => writer.addBytes('', []), throwsArgumentError);
    await writer.close();
  });

  test('the writer refuses use after close', () async {
    final writer = await StoredZipWriter.create(target('closed.zip'));
    await writer.close();
    expect(() => writer.addBytes('a.txt', []), throwsStateError);
  });

  test('reading an absent path throws an argument error', () async {
    final reader = await StoredZipReader.open(await writeZip({'a.txt': utf8.encode('x')}));
    expect(() => reader.readBytes('missing.txt'), throwsArgumentError);
    await reader.close();
  });

  test('identical input produces identical bytes', () async {
    final files = {'b.txt': utf8.encode('two'), 'a.txt': utf8.encode('one')};
    final first = await (await writeZip(files, name: 'one.zip')).readAsBytes();
    final second = await (await writeZip(files, name: 'two.zip')).readAsBytes();
    expect(first, second);
  });
}

void _replaceAll(Uint8List haystack, List<int> needle, List<int> replacement) {
  var found = false;
  for (var i = 0; i <= haystack.length - needle.length; i++) {
    var match = true;
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        match = false;
        break;
      }
    }
    if (!match) continue;
    haystack.setRange(i, i + replacement.length, replacement);
    found = true;
  }
  if (!found) throw StateError('needle not found');
}

int _indexOf(Uint8List haystack, List<int> needle) {
  outer:
  for (var i = 0; i <= haystack.length - needle.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) continue outer;
    }
    return i;
  }
  throw StateError('needle not found');
}

Matcher _zipError(StoredZipError error) =>
    isA<StoredZipException>().having((e) => e.error, 'error', error);
