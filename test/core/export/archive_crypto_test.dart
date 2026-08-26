import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/core/export/archive_codec.dart';
import 'package:opentranscribe/core/export/archive_crypto.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('archive_crypto_test');
  });

  tearDown(() async {
    await temp.delete(recursive: true);
  });

  File target(String name) => File('${temp.path}/$name');

  Future<File> payloadWith(List<int> bytes) async => target('payload.zip')..writeAsBytesSync(bytes);

  Future<File> sealed(List<int> payload, String passphrase) async {
    final container = target('sealed.otarchive');
    await sealArchiveFile(
      payload: await payloadWith(payload),
      target: container,
      passphrase: passphrase,
      logN: 10,
    );
    return container;
  }

  group('deriveArchiveKey', () {
    test('matches the rfc 7914 empty-input scrypt vector', () {
      final key = scryptKey('', Uint8List(0), n: 16, r: 1, p: 1, length: 64);
      expect(
        _hex(key),
        '77d6576238657b203b19ca42c18a0497f16b4844e3074ae8dfdffa3fede21442'
        'fcd0069ded0948f8326a753a0fc81f17e8d3e0fb2e0d3628cf35e20c38d18906',
      );
    });

    test('matches the rfc 7914 password scrypt vector', () {
      final key = scryptKey('password', utf8.encode('NaCl'), n: 1024, r: 8, p: 16, length: 64);
      expect(
        _hex(key),
        'fdbabe1c9d3472007856e7190d01e9fe7c6ad7cbc8237830e77376634b373162'
        '2eaf30d92e22a3886ff109279d9830dac727afb94a83ee6d8360cbdfa2cc0640',
      );
    });

    test('wires the header salt and costs into raw scrypt', () {
      final header = ArchiveHeader.generate(logN: 10);
      expect(
        deriveArchiveKey('secret', header),
        scryptKey('secret', header.salt, n: 1 << 10, r: header.r, p: header.p),
      );
    });

    test('is deterministic for the same passphrase and header', () {
      final header = ArchiveHeader.generate(logN: 10);
      expect(deriveArchiveKey('secret', header), deriveArchiveKey('secret', header));
    });

    test('changes entirely with passphrase or salt', () {
      final header = ArchiveHeader.generate(logN: 10);
      final other = ArchiveHeader.generate(logN: 10);
      expect(deriveArchiveKey('secret', header), isNot(deriveArchiveKey('Secret', header)));
      expect(deriveArchiveKey('secret', header), isNot(deriveArchiveKey('secret', other)));
    });
  });

  group('seal and open', () {
    test('round-trips a payload', () async {
      final payload = List<int>.generate(300000, (i) => (i * 17) % 256);
      final container = await sealed(payload, 'correct horse');
      final restored = target('restored.zip');
      await openArchiveFile(container: container, target: restored, passphrase: 'correct horse');
      expect(await restored.readAsBytes(), payload);
    });

    test('round-trips payloads across the streaming chunk boundary', () async {
      const chunk = 1 << 20;
      for (final size in [chunk - 1, chunk, chunk + 1, 2 * chunk + 7]) {
        final payload = List<int>.generate(size, (i) => (i * 31) % 256);
        final container = target('chunked-$size.otarchive');
        await sealArchiveFile(
          payload: await payloadWith(payload),
          target: container,
          passphrase: 'p',
          logN: 10,
        );
        final restored = target('chunked-$size.zip');
        await openArchiveFile(container: container, target: restored, passphrase: 'p');
        expect(await restored.readAsBytes(), payload);
      }
    });

    test('a failed seal leaves no partial container behind', () async {
      final container = target('never.otarchive');
      await expectLater(
        sealArchiveFile(
          payload: target('does-not-exist.zip'),
          target: container,
          passphrase: 'p',
          logN: 10,
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(container.existsSync(), isFalse);
    });

    test('round-trips an empty payload', () async {
      final container = await sealed([], 'p');
      final restored = target('empty.zip');
      await openArchiveFile(container: container, target: restored, passphrase: 'p');
      expect(await restored.readAsBytes(), isEmpty);
    });

    test('two seals of one payload share no bytes past the magic', () async {
      final payload = utf8.encode('same payload');
      final a = await (await sealed(payload, 'p')).readAsBytes();
      final container = target('sealed2.otarchive');
      await sealArchiveFile(
        payload: await payloadWith(payload),
        target: container,
        passphrase: 'p',
        logN: 10,
      );
      final b = await container.readAsBytes();
      expect(a.sublist(0, 6), b.sublist(0, 6));
      expect(a.sublist(6), isNot(b.sublist(6)));
    });

    test('a wrong passphrase fails as cannot decrypt and leaves nothing behind', () async {
      final container = await sealed(utf8.encode('journal'), 'right');
      final restored = target('restored.zip');
      await expectLater(
        openArchiveFile(container: container, target: restored, passphrase: 'wrong'),
        throwsA(_archiveError(ArchiveError.cannotDecrypt)),
      );
      expect(restored.existsSync(), isFalse);
    });

    test('a flipped ciphertext byte fails as cannot decrypt', () async {
      final container = await sealed(utf8.encode('journal entries here'), 'p');
      final bytes = await container.readAsBytes();
      bytes[archiveHeaderLength + 3] ^= 0xff;
      await container.writeAsBytes(bytes);
      await expectLater(
        openArchiveFile(container: container, target: target('r.zip'), passphrase: 'p'),
        throwsA(_archiveError(ArchiveError.cannotDecrypt)),
      );
    });

    test('a flipped salt byte fails as cannot decrypt because the header is bound', () async {
      final container = await sealed(utf8.encode('journal'), 'p');
      final bytes = await container.readAsBytes();
      bytes[10] ^= 0x01;
      await container.writeAsBytes(bytes);
      await expectLater(
        openArchiveFile(container: container, target: target('r.zip'), passphrase: 'p'),
        throwsA(_archiveError(ArchiveError.cannotDecrypt)),
      );
    });

    test('a flipped version byte refuses as unsupported before any key derivation', () async {
      final container = await sealed(utf8.encode('journal'), 'p');
      final bytes = await container.readAsBytes();
      bytes[4] = archiveContainerVersion + 1;
      await container.writeAsBytes(bytes);
      await expectLater(
        openArchiveFile(container: container, target: target('r.zip'), passphrase: 'p'),
        throwsA(_archiveError(ArchiveError.unsupportedVersion)),
      );
    });

    test('an in-range cost byte flip still fails the tag', () async {
      final container = await sealed(utf8.encode('journal'), 'p');
      final bytes = await container.readAsBytes();
      bytes[6] = 11;
      await container.writeAsBytes(bytes);
      await expectLater(
        openArchiveFile(container: container, target: target('r.zip'), passphrase: 'p'),
        throwsA(_archiveError(ArchiveError.cannotDecrypt)),
      );
    });

    test('a container one byte short of a tag reads as malformed', () async {
      final container = target('short-tag.otarchive');
      final header = ArchiveHeader.generate().encode();
      await container.writeAsBytes([...header, ...List.filled(archiveTagLength - 1, 0)]);
      await expectLater(
        openArchiveFile(container: container, target: target('r.zip'), passphrase: 'p'),
        throwsA(_archiveError(ArchiveError.malformed)),
      );
    });

    test('a truncated container reads as malformed before any key derivation', () async {
      final container = target('short.otarchive');
      await container.writeAsBytes(ArchiveHeader.generate().encode());
      await expectLater(
        openArchiveFile(container: container, target: target('r.zip'), passphrase: 'p'),
        throwsA(_archiveError(ArchiveError.malformed)),
      );
    });

    test('a non-archive file reads as malformed', () async {
      final container = target('noise.bin');
      await container.writeAsBytes(List<int>.generate(100, (i) => i));
      await expectLater(
        openArchiveFile(container: container, target: target('r.zip'), passphrase: 'p'),
        throwsA(_archiveError(ArchiveError.malformed)),
      );
    });

    test('the header rides in the clear and decodes from the container', () async {
      final container = await sealed(utf8.encode('x'), 'p');
      final header = ArchiveHeader.decode(await container.readAsBytes());
      expect(header.logN, 10);
      expect(header.r, archiveDefaultR);
      expect(header.p, archiveDefaultP);
    });
  });
}

String _hex(Uint8List bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

Matcher _archiveError(ArchiveError error) =>
    isA<ArchiveException>().having((e) => e.error, 'error', error);
