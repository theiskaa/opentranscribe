import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Why a zip could not be read or written. [malformed] means the bytes are not
/// a zip this codec wrote or they were damaged; [unsupported] means a
/// capability we deliberately do not have was asked for (compression, zip64
/// on read, the entry-count cap on write), so the message can say "re-zipped
/// elsewhere" instead of "corrupt"; [tooLarge] means a write overflowed the
/// 4 GB this format can address, so the failure sheet can name the cap.
enum StoredZipError { malformed, unsupported, tooLarge }

final class StoredZipException implements Exception {
  const StoredZipException(this.error, this.message);

  final StoredZipError error;
  final String message;

  @override
  String toString() => 'StoredZipException(${error.name}): $message';
}

const _localHeaderSignature = 0x04034b50;
const _centralHeaderSignature = 0x02014b50;
const _endSignature = 0x06054b50;
const _localHeaderLength = 30;
const _centralHeaderLength = 46;
const _endRecordLength = 22;
const _localCrcOffset = 14;
const _utf8NameFlag = 0x0800;
const _zipVersion = 10;
const _chunkSize = 1 << 20;
const _maxUint32 = 0xffffffff;

/// One below the zip64 sentinel 0xffff, so an archive we write can never be
/// ambiguous to a reader probing for zip64.
const _maxEntries = 0xfffe;

/// Far above any archive this app writes (65534 entries at ~100 bytes each),
/// while keeping a crafted file from making [StoredZipReader.open] allocate
/// gigabytes before validation.
const _maxDirectoryLength = 32 << 20;

/// Writes a store-only (method 0) zip: no compression, names UTF-8, one local
/// header per file and a central directory on [close]. Audio is already
/// compressed and records are small, so storing loses nothing while keeping
/// the format simple enough to own. [addFile] streams in chunks; the whole
/// payload is never in memory. Paths must be relative, '/'-separated, unique,
/// free of '.', '..', '\' and ':' segments. The writer refuses to grow past
/// what a plain zip can address (4 GB, 65534 entries) rather than write a
/// broken archive. Entries are stamped with the DOS epoch, so identical input
/// produces identical bytes.
///
/// Only [close] produces a valid zip. A failed write poisons the writer:
/// further adds and [close] throw, and the caller's exit is [abort] plus
/// deleting the file, so a half-written archive can never be mistaken for a
/// whole one.
final class StoredZipWriter {
  StoredZipWriter._(this._out);

  /// Creates [target], truncating any previous content.
  static Future<StoredZipWriter> create(File target) async {
    final out = await target.open(mode: FileMode.write);
    return StoredZipWriter._(out);
  }

  final RandomAccessFile _out;
  final List<_Entry> _entries = [];
  final Set<String> _paths = {};
  int _offset = 0;
  bool _closed = false;
  bool _broken = false;

  Future<void> addBytes(String path, List<int> bytes) async {
    _checkPath(path);
    if (bytes.length > _maxUint32) {
      throw const StoredZipException(StoredZipError.tooLarge, 'file exceeds 4 GB');
    }
    final crc = (_Crc32()..add(bytes)).value;
    await _guard(() async {
      final headerLength = await _writeLocalHeader(path, crc: crc, size: bytes.length);
      await _out.writeFrom(bytes);
      _finishEntry(path, crc: crc, size: bytes.length, headerLength: headerLength);
    });
  }

  /// Streams [source] into the archive without loading it. The local header
  /// is written first with zeroed CRC and sizes, then patched in place once
  /// the stream has been measured; readers never see the placeholder because
  /// nothing reads a zip mid-write.
  Future<void> addFile(String path, File source) async {
    _checkPath(path);
    await _guard(() async {
      final headerOffset = _offset;
      final headerLength = await _writeLocalHeader(path, crc: 0, size: 0);
      final crc = _Crc32();
      var size = 0;
      final reader = await source.open();
      try {
        while (true) {
          final chunk = await reader.read(_chunkSize);
          if (chunk.isEmpty) break;
          crc.add(chunk);
          size += chunk.length;
          await _out.writeFrom(chunk);
        }
      } finally {
        await reader.close();
      }
      if (size > _maxUint32) {
        throw const StoredZipException(StoredZipError.tooLarge, 'file exceeds 4 GB');
      }
      final patch = ByteData(12)
        ..setUint32(0, crc.value, Endian.little)
        ..setUint32(4, size, Endian.little)
        ..setUint32(8, size, Endian.little);
      await _out.setPosition(headerOffset + _localCrcOffset);
      await _out.writeFrom(patch.buffer.asUint8List());
      await _out.setPosition(headerOffset + headerLength + size);
      _finishEntry(path, crc: crc.value, size: size, headerLength: headerLength);
    });
  }

  /// Writes the central directory and end record, then closes the file. The
  /// zip is not valid until this completes. Idempotent once succeeded.
  Future<void> close() async {
    if (_closed) return;
    if (_broken) {
      await abort();
      throw StateError('a failed write left this archive unusable');
    }
    _closed = true;
    try {
      final directoryOffset = _offset;
      final builder = BytesBuilder(copy: false);
      for (final entry in _entries) {
        builder.add(_centralHeader(entry));
      }
      final directory = builder.takeBytes();
      if (directoryOffset + directory.length > _maxUint32) {
        throw const StoredZipException(StoredZipError.tooLarge, 'archive exceeds 4 GB');
      }
      final end = ByteData(_endRecordLength)
        ..setUint32(0, _endSignature, Endian.little)
        ..setUint16(8, _entries.length, Endian.little)
        ..setUint16(10, _entries.length, Endian.little)
        ..setUint32(12, directory.length, Endian.little)
        ..setUint32(16, directoryOffset, Endian.little);
      await _out.writeFrom(directory);
      await _out.writeFrom(end.buffer.asUint8List());
    } catch (_) {
      // A directory that did not land leaves a headerless file: a retried
      // close() must not answer as though this one had succeeded.
      _broken = true;
      _closed = false;
      rethrow;
    } finally {
      await _out.close();
    }
  }

  /// The failure exit: closes the underlying file without writing a
  /// directory. The file on disk is not a valid zip; the caller deletes it.
  /// Never throws: it runs inside failure paths, and an escape here (a
  /// double close after a failed [close]) would replace the cause being
  /// rethrown with its own noise.
  Future<void> abort() async {
    if (_closed) return;
    _closed = true;
    try {
      await _out.close();
    } catch (_) {}
  }

  Future<T> _guard<T>(Future<T> Function() op) async {
    try {
      return await op();
    } catch (_) {
      _broken = true;
      rethrow;
    }
  }

  void _checkPath(String path) {
    if (_closed) throw StateError('writer is closed');
    if (_broken) throw StateError('a failed write left this archive unusable');
    if (!_isSafePath(path)) {
      throw ArgumentError.value(path, 'path', 'must be relative with clean segments');
    }
    if (_paths.contains(path)) {
      throw ArgumentError.value(path, 'path', 'already added');
    }
    if (_entries.length >= _maxEntries) {
      throw const StoredZipException(StoredZipError.unsupported, 'too many entries');
    }
  }

  Future<int> _writeLocalHeader(String name, {required int crc, required int size}) async {
    if (_offset > _maxUint32) {
      throw const StoredZipException(StoredZipError.tooLarge, 'archive exceeds 4 GB');
    }
    final nameBytes = utf8.encode(name);
    final header = ByteData(_localHeaderLength)
      ..setUint32(0, _localHeaderSignature, Endian.little)
      ..setUint16(4, _zipVersion, Endian.little)
      ..setUint16(6, _utf8NameFlag, Endian.little)
      ..setUint16(8, 0, Endian.little)
      ..setUint16(10, _dosEpochTime, Endian.little)
      ..setUint16(12, _dosEpochDate, Endian.little)
      ..setUint32(_localCrcOffset, crc, Endian.little)
      ..setUint32(18, size, Endian.little)
      ..setUint32(22, size, Endian.little)
      ..setUint16(26, nameBytes.length, Endian.little)
      ..setUint16(28, 0, Endian.little);
    await _out.writeFrom(header.buffer.asUint8List());
    await _out.writeFrom(nameBytes);
    return _localHeaderLength + nameBytes.length;
  }

  void _finishEntry(String name, {required int crc, required int size, required int headerLength}) {
    _entries.add(_Entry(name: name, crc: crc, size: size, offset: _offset));
    _paths.add(name);
    _offset += headerLength + size;
  }

  Uint8List _centralHeader(_Entry entry) {
    final nameBytes = utf8.encode(entry.name);
    final header = ByteData(_centralHeaderLength)
      ..setUint32(0, _centralHeaderSignature, Endian.little)
      ..setUint16(4, _zipVersion, Endian.little)
      ..setUint16(6, _zipVersion, Endian.little)
      ..setUint16(8, _utf8NameFlag, Endian.little)
      ..setUint16(10, 0, Endian.little)
      ..setUint16(12, _dosEpochTime, Endian.little)
      ..setUint16(14, _dosEpochDate, Endian.little)
      ..setUint32(16, entry.crc, Endian.little)
      ..setUint32(20, entry.size, Endian.little)
      ..setUint32(24, entry.size, Endian.little)
      ..setUint16(28, nameBytes.length, Endian.little)
      ..setUint32(42, entry.offset, Endian.little);
    final builder = BytesBuilder(copy: false)
      ..add(header.buffer.asUint8List())
      ..add(nameBytes);
    return builder.takeBytes();
  }

  static const _dosEpochTime = 0;
  static const _dosEpochDate = (1 << 5) | 1;
}

/// Reads zips this app wrote: store-only, strict. The end record must sit at
/// the exact end of the file with no comment, every entry must be method 0
/// with matching sizes, sane relative names, and non-overlapping data, and
/// every read verifies the CRC, so damage surfaces as
/// [StoredZipError.malformed] instead of silently wrong bytes. A deflate or
/// zip64 archive answers [StoredZipError.unsupported]: a real zip, just not
/// one of ours.
///
/// Reads seek one shared file handle; callers must not read concurrently.
final class StoredZipReader {
  StoredZipReader._(this._file, this._entries, this._directoryOffset);

  static Future<StoredZipReader> open(File source) async {
    final file = await source.open();
    try {
      final length = await file.length();
      if (length < _endRecordLength) {
        throw const StoredZipException(StoredZipError.malformed, 'too short for a zip');
      }
      await file.setPosition(length - _endRecordLength);
      final end = ByteData.sublistView(await _readExact(file, _endRecordLength));
      if (end.getUint32(0, Endian.little) != _endSignature ||
          end.getUint16(20, Endian.little) != 0) {
        throw const StoredZipException(StoredZipError.malformed, 'zip end record not found');
      }
      final count = end.getUint16(10, Endian.little);
      final directorySize = end.getUint32(12, Endian.little);
      final directoryOffset = end.getUint32(16, Endian.little);
      if (count == 0xffff || directorySize == _maxUint32 || directoryOffset == _maxUint32) {
        throw const StoredZipException(StoredZipError.unsupported, 'zip64 archive');
      }
      if (directorySize > _maxDirectoryLength || count * _centralHeaderLength > directorySize) {
        throw const StoredZipException(StoredZipError.malformed, 'central directory implausible');
      }
      if (directoryOffset + directorySize + _endRecordLength != length) {
        throw const StoredZipException(StoredZipError.malformed, 'zip directory out of place');
      }
      await file.setPosition(directoryOffset);
      final directory = ByteData.sublistView(await _readExact(file, directorySize));
      final entries = _parseDirectory(directory, count, directoryOffset);
      return StoredZipReader._(file, entries, directoryOffset);
    } catch (_) {
      await file.close();
      rethrow;
    }
  }

  final RandomAccessFile _file;
  final Map<String, _Entry> _entries;
  final int _directoryOffset;

  List<String> get paths => List.unmodifiable(_entries.keys);

  int sizeOf(String path) => _entry(path).size;

  Future<Uint8List> readBytes(String path) async {
    final entry = _entry(path);
    final out = BytesBuilder(copy: false);
    await _readEntry(entry, (chunk) async => out.add(chunk));
    return out.takeBytes();
  }

  /// Streams one entry into [target], never holding it whole. The write goes
  /// through a temporary sibling moved into place only after the CRC checks
  /// out, so a damaged archive cannot leave a half-written file behind.
  Future<void> extractToFile(String path, File target) async {
    final entry = _entry(path);
    final partial = File('${target.path}.partial');
    final sink = await partial.open(mode: FileMode.write);
    try {
      await _readEntry(entry, (chunk) async => sink.writeFrom(chunk));
    } catch (_) {
      try {
        await sink.close();
      } finally {
        if (await partial.exists()) await partial.delete();
      }
      rethrow;
    }
    await sink.close();
    await partial.rename(target.path);
  }

  Future<void> close() => _file.close();

  _Entry _entry(String path) {
    final entry = _entries[path];
    if (entry == null) throw ArgumentError.value(path, 'path', 'not in this archive');
    return entry;
  }

  Future<void> _readEntry(_Entry entry, Future<void> Function(Uint8List) emit) async {
    await _file.setPosition(entry.offset);
    final local = ByteData.sublistView(await _readExact(_file, _localHeaderLength));
    if (local.getUint32(0, Endian.little) != _localHeaderSignature) {
      throw const StoredZipException(StoredZipError.malformed, 'local header missing');
    }
    final nameLength = local.getUint16(26, Endian.little);
    final extraLength = local.getUint16(28, Endian.little);
    // Our writer emits no extra field, and _checkOverlap's spans assume none:
    // an extra field shifts data past where the overlap test looked, so an
    // entry could hide inside another's bytes.
    if (extraLength != 0) {
      throw const StoredZipException(
        StoredZipError.unsupported,
        'local extra fields are not supported',
      );
    }
    final dataStart = entry.offset + _localHeaderLength + nameLength;
    if (dataStart + entry.size > _directoryOffset) {
      throw const StoredZipException(StoredZipError.malformed, 'entry data out of bounds');
    }
    await _file.setPosition(dataStart);
    final crc = _Crc32();
    var remaining = entry.size;
    while (remaining > 0) {
      final chunk = await _file.read(remaining < _chunkSize ? remaining : _chunkSize);
      if (chunk.isEmpty) {
        throw const StoredZipException(StoredZipError.malformed, 'entry data truncated');
      }
      crc.add(chunk);
      remaining -= chunk.length;
      await emit(chunk);
    }
    if (crc.value != entry.crc) {
      throw const StoredZipException(StoredZipError.malformed, 'crc mismatch');
    }
  }

  static Future<Uint8List> _readExact(RandomAccessFile file, int length) async {
    final out = Uint8List(length);
    var filled = 0;
    while (filled < length) {
      final chunk = await file.read(length - filled);
      if (chunk.isEmpty) {
        throw const StoredZipException(StoredZipError.malformed, 'zip truncated');
      }
      out.setRange(filled, filled + chunk.length, chunk);
      filled += chunk.length;
    }
    return out;
  }

  static Map<String, _Entry> _parseDirectory(ByteData directory, int count, int directoryOffset) {
    final entries = <String, _Entry>{};
    var cursor = 0;
    for (var n = 0; n < count; n++) {
      if (cursor + _centralHeaderLength > directory.lengthInBytes ||
          directory.getUint32(cursor, Endian.little) != _centralHeaderSignature) {
        throw const StoredZipException(StoredZipError.malformed, 'central directory damaged');
      }
      final method = directory.getUint16(cursor + 10, Endian.little);
      if (method != 0) {
        throw const StoredZipException(StoredZipError.unsupported, 'compressed entry');
      }
      final crc = directory.getUint32(cursor + 16, Endian.little);
      final compressedSize = directory.getUint32(cursor + 20, Endian.little);
      final size = directory.getUint32(cursor + 24, Endian.little);
      final nameLength = directory.getUint16(cursor + 28, Endian.little);
      final extraLength = directory.getUint16(cursor + 30, Endian.little);
      final commentLength = directory.getUint16(cursor + 32, Endian.little);
      final offset = directory.getUint32(cursor + 42, Endian.little);
      if (compressedSize != size || offset + _localHeaderLength > directoryOffset) {
        throw const StoredZipException(StoredZipError.malformed, 'entry record inconsistent');
      }
      if (cursor + _centralHeaderLength + nameLength > directory.lengthInBytes) {
        throw const StoredZipException(StoredZipError.malformed, 'central directory damaged');
      }
      final String name;
      try {
        name = utf8.decode(
          directory.buffer.asUint8List(
            directory.offsetInBytes + cursor + _centralHeaderLength,
            nameLength,
          ),
        );
      } on FormatException {
        throw const StoredZipException(StoredZipError.malformed, 'entry name not utf-8');
      }
      // The writer's own path rules, re-applied on read: an archive naming
      // '../x' or '/etc/x' must die here, not when a restore joins the name
      // onto a destination directory.
      if (!_isSafePath(name)) {
        throw const StoredZipException(StoredZipError.malformed, 'unsafe entry name');
      }
      if (entries.containsKey(name)) {
        throw const StoredZipException(StoredZipError.malformed, 'duplicate entry name');
      }
      entries[name] = _Entry(name: name, crc: crc, size: size, offset: offset);
      cursor += _centralHeaderLength + nameLength + extraLength + commentLength;
    }
    if (cursor != directory.lengthInBytes) {
      throw const StoredZipException(StoredZipError.malformed, 'central directory damaged');
    }
    _checkOverlap(entries, directoryOffset);
    return entries;
  }

  /// Entries claiming the same bytes are how a stored zip becomes a bomb: a
  /// small file whose 65534 entries each "contain" gigabytes. Distinct data
  /// regions cap total extractable size at roughly the file's own.
  static void _checkOverlap(Map<String, _Entry> entries, int directoryOffset) {
    final spans = entries.values.toList()..sort((a, b) => a.offset.compareTo(b.offset));
    var previousEnd = 0;
    for (final entry in spans) {
      if (entry.offset < previousEnd) {
        throw const StoredZipException(StoredZipError.malformed, 'overlapping entries');
      }
      previousEnd = entry.offset + _localHeaderLength + utf8.encode(entry.name).length + entry.size;
    }
    if (previousEnd > directoryOffset) {
      throw const StoredZipException(StoredZipError.malformed, 'entry data out of bounds');
    }
  }
}

bool _isSafePath(String path) =>
    path.isNotEmpty &&
    !path.startsWith('/') &&
    !path.contains('\\') &&
    !path.contains(':') &&
    path.split('/').every((s) => s.isNotEmpty && s != '.' && s != '..');

final class _Entry {
  const _Entry({required this.name, required this.crc, required this.size, required this.offset});

  final String name;
  final int crc;
  final int size;
  final int offset;
}

final class _Crc32 {
  static final Uint32List _table = _buildTable();

  int _state = 0xffffffff;

  void add(List<int> bytes) {
    var state = _state;
    for (final byte in bytes) {
      state = _table[(state ^ byte) & 0xff] ^ (state >>> 8);
    }
    _state = state;
  }

  int get value => _state ^ 0xffffffff;

  static Uint32List _buildTable() {
    final table = Uint32List(256);
    for (var n = 0; n < 256; n++) {
      var c = n;
      for (var k = 0; k < 8; k++) {
        c = (c & 1) != 0 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
      }
      table[n] = c;
    }
    return table;
  }
}
