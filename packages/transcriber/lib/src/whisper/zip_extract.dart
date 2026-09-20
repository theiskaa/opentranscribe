import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Unpacks [zip] into [into]. Reads only what the encoder archives use,
/// stored or deflated entries sized by the central directory (zip64
/// honored), and refuses everything else with [ZipFormatException]: another
/// method, a name that leaves [into], an entry that inflates past or short
/// of its listed size. A refused archive may leave partial files; the caller
/// owns the directory. The archive's hash was verified before this runs, so
/// no CRC is checked.
Future<void> extractZip(File zip, Directory into) async {
  final raf = await zip.open();
  try {
    final entries = await _readCentralDirectory(raf);
    for (final entry in entries) {
      final target = _resolve(into, entry.name);
      if (target is Directory) {
        await target.create(recursive: true);
        continue;
      }
      final file = target as File;
      await file.parent.create(recursive: true);
      final dataOffset = await _dataOffset(raf, entry);
      final out = await file.open(mode: FileMode.write);
      try {
        await _copyEntry(raf, entry, dataOffset, out);
      } finally {
        await out.close();
      }
    }
  } finally {
    await raf.close();
  }
}

final class ZipFormatException implements Exception {
  const ZipFormatException(this.message);

  final String message;

  @override
  String toString() => 'ZipFormatException: $message';
}

final class _Entry {
  const _Entry({
    required this.name,
    required this.method,
    required this.compressedSize,
    required this.size,
    required this.localHeaderOffset,
  });

  final String name;
  final int method;
  final int compressedSize;
  final int size;
  final int localHeaderOffset;
}

const _eocdSignature = 0x06054b50;
const _eocd64LocatorSignature = 0x07064b50;
const _eocd64Signature = 0x06064b50;
const _centralSignature = 0x02014b50;
const _localSignature = 0x04034b50;
const _stored = 0;
const _deflated = 8;
const _chunk = 1 << 16;

Future<List<_Entry>> _readCentralDirectory(RandomAccessFile raf) async {
  final length = await raf.length();
  // The end record ends with a comment of up to 64 KiB; scan back for a
  // signature whose comment length lands exactly on the end.
  final tailStart = length > 65557 ? length - 65557 : 0;
  await raf.setPosition(tailStart);
  final tail = await raf.read(length - tailStart);
  var eocd = -1;
  for (var i = tail.length - 22; i >= 0; i--) {
    if (_u32(tail, i) == _eocdSignature && i + 22 + _u16(tail, i + 20) == tail.length) {
      eocd = i;
      break;
    }
  }
  if (eocd < 0) throw const ZipFormatException('no end record');
  var count = _u16(tail, eocd + 10);
  var directorySize = _u32(tail, eocd + 12);
  var directoryOffset = _u32(tail, eocd + 16);
  // A zip64 archive keeps the real numbers in its own end record.
  if (count == 0xffff || directorySize == 0xffffffff || directoryOffset == 0xffffffff) {
    final locator = eocd - 20;
    if (locator < 0 || _u32(tail, locator) != _eocd64LocatorSignature) {
      throw const ZipFormatException('zip64 without a locator');
    }
    final eocd64Offset = _u64(tail, locator + 8);
    await raf.setPosition(eocd64Offset);
    final record = await raf.read(56);
    if (record.length < 56 || _u32(record, 0) != _eocd64Signature) {
      throw const ZipFormatException('bad zip64 end record');
    }
    count = _u64(record, 32);
    directorySize = _u64(record, 40);
    directoryOffset = _u64(record, 48);
  }
  await raf.setPosition(directoryOffset);
  final directory = await raf.read(directorySize);
  if (directory.length != directorySize) throw const ZipFormatException('short directory');
  final entries = <_Entry>[];
  var at = 0;
  for (var i = 0; i < count; i++) {
    if (at + 46 > directory.length || _u32(directory, at) != _centralSignature) {
      throw const ZipFormatException('bad central header');
    }
    final method = _u16(directory, at + 10);
    var compressedSize = _u32(directory, at + 20);
    var size = _u32(directory, at + 24);
    final nameLength = _u16(directory, at + 28);
    final extraLength = _u16(directory, at + 30);
    final commentLength = _u16(directory, at + 32);
    var localOffset = _u32(directory, at + 42);
    final name = utf8.decode(directory.sublist(at + 46, at + 46 + nameLength));
    final extra = directory.sublist(at + 46 + nameLength, at + 46 + nameLength + extraLength);
    // The zip64 extra field lists only the values the header could not hold,
    // in this order.
    var e = 0;
    while (e + 4 <= extra.length) {
      final id = _u16(extra, e);
      final fieldLength = _u16(extra, e + 2);
      if (id == 0x0001) {
        var f = e + 4;
        if (size == 0xffffffff) {
          size = _u64(extra, f);
          f += 8;
        }
        if (compressedSize == 0xffffffff) {
          compressedSize = _u64(extra, f);
          f += 8;
        }
        if (localOffset == 0xffffffff) localOffset = _u64(extra, f);
      }
      e += 4 + fieldLength;
    }
    if (method != _stored && method != _deflated) {
      throw ZipFormatException('unsupported method $method for $name');
    }
    entries.add(
      _Entry(
        name: name,
        method: method,
        compressedSize: compressedSize,
        size: size,
        localHeaderOffset: localOffset,
      ),
    );
    at += 46 + nameLength + extraLength + commentLength;
  }
  return entries;
}

Future<int> _dataOffset(RandomAccessFile raf, _Entry entry) async {
  await raf.setPosition(entry.localHeaderOffset);
  final header = await raf.read(30);
  if (header.length < 30 || _u32(header, 0) != _localSignature) {
    throw ZipFormatException('bad local header for ${entry.name}');
  }
  return entry.localHeaderOffset + 30 + _u16(header, 26) + _u16(header, 28);
}

Future<void> _copyEntry(
  RandomAccessFile raf,
  _Entry entry,
  int dataOffset,
  RandomAccessFile out,
) async {
  await raf.setPosition(dataOffset);
  var left = entry.compressedSize;
  var produced = 0;
  Future<void> write(List<int> bytes) async {
    produced += bytes.length;
    if (produced > entry.size) throw ZipFormatException('${entry.name} inflates past its size');
    await out.writeFrom(bytes);
  }

  if (entry.method == _stored) {
    while (left > 0) {
      final bytes = await raf.read(left < _chunk ? left : _chunk);
      if (bytes.isEmpty) throw ZipFormatException('${entry.name} ends early');
      left -= bytes.length;
      await write(bytes);
    }
  } else {
    // Inflated chunks are collected per input chunk and written in order, so
    // the file never holds more than one chunk's output in memory.
    final buffer = _Collector();
    final sink = ZLibDecoder(raw: true).startChunkedConversion(buffer);
    var closed = false;
    try {
      while (left > 0) {
        final bytes = await raf.read(left < _chunk ? left : _chunk);
        if (bytes.isEmpty) throw ZipFormatException('${entry.name} ends early');
        left -= bytes.length;
        sink.add(bytes);
        for (final out in buffer.take()) {
          await write(out);
        }
      }
      closed = true;
      sink.close();
      for (final out in buffer.take()) {
        await write(out);
      }
    } finally {
      if (!closed) sink.close();
    }
  }
  if (produced != entry.size) throw ZipFormatException('${entry.name} is not its listed size');
}

/// Gathers a converter's output between reads, so inflation stays pull-driven.
final class _Collector implements Sink<List<int>> {
  final List<List<int>> _chunks = [];

  @override
  void add(List<int> data) => _chunks.add(data);

  @override
  void close() {}

  List<List<int>> take() {
    final out = List<List<int>>.of(_chunks);
    _chunks.clear();
    return out;
  }
}

/// [name] inside [into], refusing a path that would land outside it.
FileSystemEntity _resolve(Directory into, String name) {
  final parts = name.split('/').where((p) => p.isNotEmpty).toList();
  if (name.startsWith('/') || parts.any((p) => p == '..' || p == '.')) {
    throw ZipFormatException('unsafe entry name $name');
  }
  final path = '${into.path}/${parts.join('/')}';
  return name.endsWith('/') ? Directory(path) : File(path);
}

int _u16(Uint8List b, int at) => b[at] | (b[at + 1] << 8);

int _u32(Uint8List b, int at) => _u16(b, at) | (_u16(b, at + 2) << 16);

int _u64(Uint8List b, int at) => _u32(b, at) | (_u32(b, at + 4) << 32);
