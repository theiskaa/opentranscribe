import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

/// Why an archive could not be opened, honest about what is distinguishable.
/// [malformed] is structural: the bytes are provably not an archive, so the
/// passphrase is definitely not the problem. [unsupportedVersion] means a
/// newer app wrote it. [cannotDecrypt] is a GCM tag failure, which cannot
/// tell a wrong passphrase from a damaged file; copy leads with the
/// passphrase since that is the overwhelmingly likely cause. [unsupportedZip]
/// is a real zip using compression: someone unzipped and re-zipped an
/// archive elsewhere, which deserves an honest message, not "corrupt".
enum ArchiveError { malformed, unsupportedVersion, cannotDecrypt, unsupportedZip }

final class ArchiveException implements Exception {
  const ArchiveException(this.error, this.message);

  final ArchiveError error;
  final String message;

  @override
  String toString() => 'ArchiveException(${error.name}): $message';
}

/// 'OTAR', the sealed container's magic.
const _magic = [0x4f, 0x54, 0x41, 0x52];

const archiveContainerVersion = 1;
const archiveHeaderLength = 37;
const archiveNonceLength = 12;
const archiveSaltLength = 16;
const archiveTagLength = 16;

/// scrypt costs for new archives: 32 MB working set, under a second on the
/// phones this app targets. Import honors whatever the header carries (within
/// caps), so raising these later costs old archives nothing.
const archiveDefaultLogN = 15;
const archiveDefaultR = 8;
const archiveDefaultP = 1;

const _kdfScrypt = 1;

/// Caps on header-carried KDF costs. The memory product is the real gate: a
/// crafted header must not turn one decrypt attempt into a gigabyte scrypt
/// allocation, and 128 MiB keeps every plausible legitimate cost (defaults
/// use 32 MiB) while staying survivable on a phone.
const _maxLogN = 22;
const _maxP = 4;
const _maxKdfBytes = 128 << 20;

/// The sealed container's fixed-size prefix: magic, container version, KDF id
/// and costs, salt, nonce. The magic, version and KDF id are enforced by
/// parsing; every other byte is bound into the GCM tag as AAD, so a
/// downgraded cost or swapped salt fails authentication, not just parsing.
/// [encode] and [decode] are exact inverses over the 37 bytes.
@immutable
final class ArchiveHeader {
  ArchiveHeader({
    required this.logN,
    required this.r,
    required this.p,
    required Uint8List salt,
    required Uint8List nonce,
  }) : salt = Uint8List.fromList(salt).asUnmodifiableView(),
       nonce = Uint8List.fromList(nonce).asUnmodifiableView() {
    if (salt.length != archiveSaltLength || nonce.length != archiveNonceLength) {
      throw ArgumentError('salt must be $archiveSaltLength bytes, nonce $archiveNonceLength');
    }
  }

  /// A header for a new archive: fresh random salt and nonce, never reused,
  /// so two seals of the same payload share nothing.
  factory ArchiveHeader.generate({
    int logN = archiveDefaultLogN,
    int r = archiveDefaultR,
    int p = archiveDefaultP,
  }) {
    final random = Random.secure();
    Uint8List randomBytes(int length) =>
        Uint8List.fromList([for (var i = 0; i < length; i++) random.nextInt(256)]);
    return ArchiveHeader(
      logN: logN,
      r: r,
      p: p,
      salt: randomBytes(archiveSaltLength),
      nonce: randomBytes(archiveNonceLength),
    );
  }

  final int logN;
  final int r;
  final int p;
  final Uint8List salt;
  final Uint8List nonce;

  Uint8List encode() {
    final bytes = Uint8List(archiveHeaderLength);
    bytes.setRange(0, 4, _magic);
    bytes[4] = archiveContainerVersion;
    bytes[5] = _kdfScrypt;
    bytes[6] = logN;
    bytes[7] = r;
    bytes[8] = p;
    bytes.setRange(9, 9 + archiveSaltLength, salt);
    bytes.setRange(9 + archiveSaltLength, archiveHeaderLength, nonce);
    return bytes;
  }

  static ArchiveHeader decode(Uint8List bytes) {
    if (bytes.length < archiveHeaderLength) {
      throw const ArchiveException(ArchiveError.malformed, 'archive truncated');
    }
    if (!_startsWithMagic(bytes)) {
      throw const ArchiveException(ArchiveError.malformed, 'not a sealed archive');
    }
    if (bytes[4] != archiveContainerVersion) {
      throw const ArchiveException(
        ArchiveError.unsupportedVersion,
        'written by a newer version of the app',
      );
    }
    if (bytes[5] != _kdfScrypt) {
      throw const ArchiveException(ArchiveError.malformed, 'unknown key derivation');
    }
    final logN = bytes[6];
    final r = bytes[7];
    final p = bytes[8];
    if (logN < 1 ||
        logN > _maxLogN ||
        r < 1 ||
        p < 1 ||
        p > _maxP ||
        128 * (1 << logN) * r > _maxKdfBytes) {
      throw const ArchiveException(ArchiveError.malformed, 'implausible key derivation cost');
    }
    return ArchiveHeader(
      logN: logN,
      r: r,
      p: p,
      salt: Uint8List.sublistView(bytes, 9, 9 + archiveSaltLength),
      nonce: Uint8List.sublistView(bytes, 9 + archiveSaltLength, archiveHeaderLength),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ArchiveHeader &&
      other.logN == logN &&
      other.r == r &&
      other.p == p &&
      listEquals(other.salt, salt) &&
      listEquals(other.nonce, nonce);

  @override
  int get hashCode => Object.hash(logN, r, p, Object.hashAll(salt), Object.hashAll(nonce));
}

/// What the first bytes of a picked file say it is. [plainZip] and [sealed]
/// route to the two import paths; [unknown] is anything else, including an
/// empty file.
enum ArchiveKind { plainZip, sealed, unknown }

Future<ArchiveKind> sniffArchive(File file) async {
  final handle = await file.open();
  try {
    final head = await handle.read(4);
    if (head.length < 4) return ArchiveKind.unknown;
    if (head[0] == 0x50 && head[1] == 0x4b && head[2] == 0x03 && head[3] == 0x04) {
      return ArchiveKind.plainZip;
    }
    if (_startsWithMagic(head)) return ArchiveKind.sealed;
    return ArchiveKind.unknown;
  } finally {
    await handle.close();
  }
}

bool _startsWithMagic(List<int> bytes) {
  for (var i = 0; i < _magic.length; i++) {
    if (bytes[i] != _magic[i]) return false;
  }
  return true;
}
