import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

import 'package:opentranscribe/core/export/archive_codec.dart';

const _chunkSize = 1 << 20;

/// GCM emits at most a block plus the tag beyond what a chunk feeds it.
const _finalSlack = 64;

/// The archive key: scrypt over the passphrase with the header's salt and
/// costs, never the raw passphrase and never the device Keychain key, so the
/// archive opens on any phone that knows the passphrase and on nothing else.
/// Pure and synchronous; callers own putting it on a worker isolate.
///
/// Passphrase bytes are the exact UTF-8 as typed, with no Unicode
/// normalization pass: every entry point is an iOS keyboard, which emits
/// NFC consistently, and a normalizer would mean a new dependency.
Uint8List deriveArchiveKey(String passphrase, ArchiveHeader header) =>
    scryptKey(passphrase, header.salt, n: 1 << header.logN, r: header.r, p: header.p);

/// Raw scrypt, split out so tests can pin it against the RFC 7914 vectors,
/// whose salts an [ArchiveHeader] cannot carry.
Uint8List scryptKey(
  String passphrase,
  Uint8List salt, {
  required int n,
  required int r,
  required int p,
  int length = 32,
}) {
  final scrypt = Scrypt()..init(ScryptParameters(n, r, p, length, salt));
  return scrypt.process(utf8.encode(passphrase));
}

/// Seals [payload] into [target]: the 37-byte header, then AES-256-GCM over
/// the payload with the whole header as AAD, tag appended. Runs KDF and
/// cipher on a worker isolate, streaming in chunks, so a journal-sized
/// payload never blocks the UI or sits in memory. [target] must be a fresh
/// staging path: it is truncated on open, and any failure deletes it before
/// rethrowing, so a partial container never survives.
///
/// Interop caveat, deliberate: pointycastle builds the GCM length block from
/// 32-bit lanes, so a payload of 512 MiB or more gets a tag no spec-exact
/// GCM would accept. Round-trips are unaffected because this app is the only
/// reader; a future crypto migration must reuse pointycastle for containers
/// that big.
Future<void> sealArchiveFile({
  required File payload,
  required File target,
  required String passphrase,
  int logN = archiveDefaultLogN,
  int r = archiveDefaultR,
  int p = archiveDefaultP,
}) async {
  final headerBytes = ArchiveHeader.generate(logN: logN, r: r, p: p).encode();
  final payloadPath = payload.path;
  final targetPath = target.path;
  try {
    await Isolate.run(() => _sealSync(payloadPath, targetPath, passphrase, headerBytes));
  } catch (_) {
    if (await target.exists()) await target.delete();
    rethrow;
  }
}

/// Opens the sealed [container] into [target], which must be a fresh staging
/// path: it is truncated on open. The header is validated before any KDF
/// work, so a malformed file answers cheaply and honestly. Decrypted bytes
/// stream into [target] but nothing may read them until this future
/// completes: GCM only authenticates at the end, and on a tag failure
/// ([ArchiveError.cannotDecrypt]) or any other error [target] is deleted.
Future<void> openArchiveFile({
  required File container,
  required File target,
  required String passphrase,
}) async {
  final length = await container.length();
  if (length < archiveHeaderLength + archiveTagLength) {
    throw const ArchiveException(ArchiveError.malformed, 'archive truncated');
  }
  final handle = await container.open();
  final Uint8List headerBytes;
  try {
    headerBytes = await handle.read(archiveHeaderLength);
  } finally {
    await handle.close();
  }
  ArchiveHeader.decode(headerBytes);
  final containerPath = container.path;
  final targetPath = target.path;
  try {
    await Isolate.run(() => _openSync(containerPath, targetPath, passphrase, headerBytes));
  } catch (_) {
    if (await target.exists()) await target.delete();
    rethrow;
  }
}

void _sealSync(String payloadPath, String targetPath, String passphrase, Uint8List headerBytes) {
  final cipher = _cipher(forEncryption: true, passphrase: passphrase, headerBytes: headerBytes);
  final inp = File(payloadPath).openSync();
  RandomAccessFile? out;
  var ok = false;
  try {
    out = File(targetPath).openSync(mode: FileMode.write);
    out.writeFromSync(headerBytes);
    _pump(cipher, inp, out);
    ok = true;
  } finally {
    _close(inp, rethrowOn: ok);
    if (out != null) _close(out, rethrowOn: ok);
  }
}

void _openSync(String containerPath, String targetPath, String passphrase, Uint8List headerBytes) {
  final cipher = _cipher(forEncryption: false, passphrase: passphrase, headerBytes: headerBytes);
  final inp = File(containerPath).openSync();
  RandomAccessFile? out;
  var ok = false;
  try {
    out = File(targetPath).openSync(mode: FileMode.write);
    inp.setPositionSync(archiveHeaderLength);
    _pump(cipher, inp, out);
    ok = true;
  } on InvalidCipherTextException {
    throw const ArchiveException(ArchiveError.cannotDecrypt, 'wrong passphrase, or a damaged file');
  } finally {
    _close(inp, rethrowOn: ok);
    if (out != null) _close(out, rethrowOn: ok);
  }
}

/// A close failure only matters when the operation otherwise succeeded; while
/// an exception is already in flight it must not replace the real error.
void _close(RandomAccessFile file, {required bool rethrowOn}) {
  try {
    file.closeSync();
  } catch (_) {
    if (rethrowOn) rethrow;
  }
}

GCMBlockCipher _cipher({
  required bool forEncryption,
  required String passphrase,
  required Uint8List headerBytes,
}) {
  final header = ArchiveHeader.decode(headerBytes);
  final key = deriveArchiveKey(passphrase, header);
  return GCMBlockCipher(AESEngine())..init(
    forEncryption,
    AEADParameters(KeyParameter(key), archiveTagLength * 8, header.nonce, headerBytes),
  );
}

void _pump(GCMBlockCipher cipher, RandomAccessFile inp, RandomAccessFile out) {
  final buffer = Uint8List(_chunkSize + _finalSlack);
  while (true) {
    final chunk = inp.readSync(_chunkSize);
    if (chunk.isEmpty) break;
    final written = cipher.processBytes(chunk, 0, chunk.length, buffer, 0);
    out.writeFromSync(buffer, 0, written);
  }
  final finalBuffer = Uint8List(_finalSlack);
  final written = cipher.doFinal(finalBuffer, 0);
  out.writeFromSync(finalBuffer, 0, written);
}
