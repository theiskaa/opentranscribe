import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/core/export/archive_codec.dart';

void main() {
  group('ArchiveHeader', () {
    test('encode and decode are exact inverses', () {
      final header = ArchiveHeader.generate();
      expect(ArchiveHeader.decode(header.encode()), header);
    });

    test('generate never repeats salt or nonce', () {
      final a = ArchiveHeader.generate();
      final b = ArchiveHeader.generate();
      expect(a.salt, isNot(b.salt));
      expect(a.nonce, isNot(b.nonce));
    });

    test('a wrong magic reads as malformed', () {
      final bytes = ArchiveHeader.generate().encode();
      bytes[0] = 0x50;
      expect(() => ArchiveHeader.decode(bytes), throwsA(_archiveError(ArchiveError.malformed)));
    });

    test('a newer container version reads as unsupported', () {
      final bytes = ArchiveHeader.generate().encode();
      bytes[4] = archiveContainerVersion + 1;
      expect(
        () => ArchiveHeader.decode(bytes),
        throwsA(_archiveError(ArchiveError.unsupportedVersion)),
      );
    });

    test('an unknown kdf id reads as malformed', () {
      final bytes = ArchiveHeader.generate().encode();
      bytes[5] = 2;
      expect(() => ArchiveHeader.decode(bytes), throwsA(_archiveError(ArchiveError.malformed)));
    });

    test('implausible kdf costs read as malformed', () {
      for (final (index, value) in [(6, 23), (6, 0), (7, 0), (8, 5), (8, 0)]) {
        final bytes = ArchiveHeader.generate().encode();
        bytes[index] = value;
        expect(() => ArchiveHeader.decode(bytes), throwsA(_archiveError(ArchiveError.malformed)));
      }
    });

    test('a kdf memory bomb reads as malformed even with each factor in range', () {
      final bytes = ArchiveHeader.generate().encode();
      bytes[6] = 21;
      expect(() => ArchiveHeader.decode(bytes), throwsA(_archiveError(ArchiveError.malformed)));
    });

    test('a truncated header reads as malformed', () {
      final bytes = ArchiveHeader.generate().encode();
      expect(
        () => ArchiveHeader.decode(Uint8List.sublistView(bytes, 0, 20)),
        throwsA(_archiveError(ArchiveError.malformed)),
      );
    });
  });

  group('sniffArchive', () {
    late Directory temp;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('archive_codec_test');
    });

    tearDown(() async {
      await temp.delete(recursive: true);
    });

    Future<File> fileWith(List<int> bytes) async =>
        File('${temp.path}/probe.bin')..writeAsBytesSync(bytes);

    test('recognizes a zip', () async {
      expect(
        await sniffArchive(await fileWith([0x50, 0x4b, 0x03, 0x04, 1, 2])),
        ArchiveKind.plainZip,
      );
    });

    test('recognizes a sealed container', () async {
      expect(
        await sniffArchive(await fileWith(ArchiveHeader.generate().encode())),
        ArchiveKind.sealed,
      );
    });

    test('answers unknown for garbage and short files', () async {
      expect(await sniffArchive(await fileWith([1, 2, 3, 4])), ArchiveKind.unknown);
      expect(await sniffArchive(await fileWith([0x50, 0x4b])), ArchiveKind.unknown);
      expect(await sniffArchive(await fileWith([])), ArchiveKind.unknown);
    });
  });
}

Matcher _archiveError(ArchiveError error) =>
    isA<ArchiveException>().having((e) => e.error, 'error', error);
