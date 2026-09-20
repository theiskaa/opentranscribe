import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/src/whisper/zip_extract.dart';

import 'zip_fixture.dart';

int _indexOf(List<int> bytes, List<int> pattern) {
  for (var i = 0; i + pattern.length <= bytes.length; i++) {
    var hit = true;
    for (var k = 0; k < pattern.length && hit; k++) {
      hit = bytes[i + k] == pattern[k];
    }
    if (hit) return i;
  }
  return -1;
}

void main() {
  late Directory root;

  setUp(() async => root = await Directory.systemTemp.createTemp('otr-zip-'));
  tearDown(() => root.delete(recursive: true));

  Future<File> archive(Map<String, List<int>?> entries, {bool deflate = true}) async {
    final file = File('${root.path}/a.zip');
    await file.writeAsBytes(zipOf(entries, deflate: deflate));
    return file;
  }

  final weights = List<int>.generate(300000, (i) => (i * 31 + 7) & 0xff);

  test('a deflated tree lands with its directories and bytes', () async {
    final zip = await archive({
      'model.mlmodelc/': null,
      'model.mlmodelc/weights/': null,
      'model.mlmodelc/weights/weight.bin': weights,
      'model.mlmodelc/metadata.json': utf8.encode('{"a":1}'),
    });
    final into = Directory('${root.path}/out');

    await extractZip(zip, into);

    expect(await File('${into.path}/model.mlmodelc/weights/weight.bin').readAsBytes(), weights);
    expect(await File('${into.path}/model.mlmodelc/metadata.json').readAsString(), '{"a":1}');
  });

  test('a stored entry copies through unchanged', () async {
    final zip = await archive({'plain.bin': weights}, deflate: false);
    final into = Directory('${root.path}/out');

    await extractZip(zip, into);

    expect(await File('${into.path}/plain.bin').readAsBytes(), weights);
  });

  test('an entry that would climb out of the target is refused', () async {
    final zip = await archive({
      '../escape.bin': [1, 2, 3],
    });

    await expectLater(
      extractZip(zip, Directory('${root.path}/out')),
      throwsA(isA<ZipFormatException>()),
    );
    expect(File('${root.path}/escape.bin').existsSync(), isFalse);
  });

  test('a file that is not a zip is refused', () async {
    final file = File('${root.path}/not.zip');
    await file.writeAsBytes(List.filled(100, 7));

    await expectLater(
      extractZip(file, Directory('${root.path}/out')),
      throwsA(isA<ZipFormatException>()),
    );
  });

  test('an entry whose bytes stop short of its listed size is refused', () async {
    final zip = await archive({'short.bin': weights});
    final bytes = await zip.readAsBytes();
    final central = _indexOf(bytes, [0x50, 0x4b, 0x01, 0x02]);
    bytes[central + 24] += 1;
    await zip.writeAsBytes(bytes);

    await expectLater(
      extractZip(zip, Directory('${root.path}/out')),
      throwsA(isA<ZipFormatException>()),
    );
  });

  test('a comment that spells the end signature does not fool the scan', () async {
    final zip = await archive({
      'plain.bin': [1, 2, 3],
    }, deflate: false);
    final bytes = await zip.readAsBytes();
    final comment = [0x50, 0x4b, 0x05, 0x06, 0, 0, 0, 0];
    bytes[bytes.length - 2] = comment.length;
    await zip.writeAsBytes([...bytes, ...comment]);

    await extractZip(zip, Directory('${root.path}/out'));

    expect(await File('${root.path}/out/plain.bin').readAsBytes(), [1, 2, 3]);
  });
}
