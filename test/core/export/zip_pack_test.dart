import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/export/stored_zip.dart';
import 'package:opentranscribe/core/export/zip_pack.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('zip_pack_test');
  });

  tearDown(() async {
    await temp.delete(recursive: true);
  });

  Future<File> source(String name, int length) async {
    final file = File('${temp.path}/$name');
    await file.writeAsBytes(List<int>.generate(length, (i) => i % 251));
    return file;
  }

  test('a pack lands bytes and files as one readable zip', () async {
    final audio = await source('a.m4a', 4096);
    final target = '${temp.path}/out.zip';
    await ZipPack(
      target: target,
      bytes: [('manifest.json', utf8.encode('{"ok":true}'))],
      files: [('audio/a.m4a', audio.path)],
    ).run();

    final reader = await StoredZipReader.open(File(target));
    try {
      expect(reader.paths, containsAll(['manifest.json', 'audio/a.m4a']));
      expect(utf8.decode(await reader.readBytes('manifest.json')), '{"ok":true}');
      expect(await reader.readBytes('audio/a.m4a'), await audio.readAsBytes());
    } finally {
      await reader.close();
    }
  });

  test('progress reports written file bytes up to their total', () async {
    final a = await source('a.m4a', 3000);
    final b = await source('b.m4a', 5000);
    final ticks = <(int, int)>[];
    await ZipPack(
      target: '${temp.path}/out.zip',
      bytes: const [],
      files: [('a', a.path), ('b', b.path)],
    ).run(onProgress: (written, total) => ticks.add((written, total)));
    expect(ticks, [(0, 8000), (3000, 8000), (8000, 8000)]);
  });

  test('an abort mid-pack throws and leaves no readable zip', () async {
    final files = [for (var i = 0; i < 8; i++) ('f$i', (await source('f$i.bin', 1 << 16)).path)];
    final target = '${temp.path}/out.zip';
    final pack = ZipPack(target: target, bytes: const [], files: files);
    await expectLater(
      pack.run(
        onProgress: (written, _) {
          if (written > 0) pack.abort();
        },
      ),
      throwsA(isA<ZipPackAborted>()),
    );
    await expectLater(StoredZipReader.open(File(target)), throwsA(isA<StoredZipException>()));
  });

  test('an abort before the run starts fails it without ever packing', () async {
    final target = '${temp.path}/out.zip';
    final pack = ZipPack(target: target, bytes: const [], files: const []);
    pack.abort();
    await expectLater(pack.run(), throwsA(isA<ZipPackAborted>()));
    expect(File(target).existsSync(), isFalse);
  });

  test('a second run on one pack is refused', () async {
    final pack = ZipPack(target: '${temp.path}/out.zip', bytes: const [], files: const []);
    await pack.run();
    await expectLater(pack.run(), throwsStateError);
  });

  test('an abort after settling is quiet', () async {
    final pack = ZipPack(target: '${temp.path}/out.zip', bytes: const [], files: const []);
    await pack.run();
    pack.abort();
  });

  test('a vanished source is skipped, not fatal', () async {
    final target = '${temp.path}/out.zip';
    await ZipPack(
      target: target,
      bytes: [('kept.txt', utf8.encode('kept'))],
      files: [('gone', '${temp.path}/never-existed.bin')],
    ).run();
    final reader = await StoredZipReader.open(File(target));
    try {
      expect(reader.paths, ['kept.txt']);
    } finally {
      await reader.close();
    }
  });

  test('a writer refusal crosses the isolate as an error, not a hang', () async {
    await expectLater(
      ZipPack(
        target: '${temp.path}/out.zip',
        bytes: [('same.txt', utf8.encode('a')), ('same.txt', utf8.encode('b'))],
        files: const [],
      ).run(),
      throwsException,
    );
  });
}
