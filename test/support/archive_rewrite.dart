import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:opentranscribe/core/export/stored_zip.dart';

/// Copies the stored zip at [source] to [target] entry by entry. [edit] may
/// rewrite an entry's bytes, or drop it by answering null; [add] appends
/// entries after the copied ones.
Future<File> rewriteArchive(
  String source,
  String target, {
  List<int>? Function(String path, Uint8List bytes)? edit,
  Map<String, List<int>> add = const {},
}) async {
  final rebuilt = File(target);
  final reader = await StoredZipReader.open(File(source));
  try {
    final writer = await StoredZipWriter.create(rebuilt);
    try {
      for (final path in reader.paths) {
        final bytes = await reader.readBytes(path);
        final kept = edit == null ? bytes : edit(path, bytes);
        if (kept != null) await writer.addBytes(path, kept);
      }
      for (final entry in add.entries) {
        await writer.addBytes(entry.key, entry.value);
      }
    } finally {
      await writer.close();
    }
  } finally {
    await reader.close();
  }
  return rebuilt;
}

/// The raw bytes of one entry of the stored zip at [source].
Future<Uint8List> archiveEntry(String source, String path) async {
  final reader = await StoredZipReader.open(File(source));
  try {
    return await reader.readBytes(path);
  } finally {
    await reader.close();
  }
}

/// [bytes] decoded as a JSON object, changed by [change], encoded again.
List<int> editJson(Uint8List bytes, Map<String, dynamic> Function(Map<String, dynamic>) change) =>
    utf8.encode(jsonEncode(change(jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>)));

/// A zip of [files] with every entry deflated, the way Finder's Compress
/// writes one: a real zip, just not a stored one. CRCs are left zero, as
/// nothing that only lists its directory reads them.
Future<File> writeDeflatedZip(String target, Map<String, List<int>> files) async {
  final local = BytesBuilder();
  final central = BytesBuilder();
  for (final MapEntry(key: name, value: bytes) in files.entries) {
    final nameBytes = utf8.encode(name);
    final packed = ZLibCodec(raw: true).encode(bytes);
    final offset = local.length;
    final head = ByteData(30)
      ..setUint32(0, 0x04034b50, Endian.little)
      ..setUint16(4, 20, Endian.little)
      ..setUint16(8, 8, Endian.little)
      ..setUint32(18, packed.length, Endian.little)
      ..setUint32(22, bytes.length, Endian.little)
      ..setUint16(26, nameBytes.length, Endian.little);
    local
      ..add(head.buffer.asUint8List())
      ..add(nameBytes)
      ..add(packed);
    final entry = ByteData(46)
      ..setUint32(0, 0x02014b50, Endian.little)
      ..setUint16(4, 20, Endian.little)
      ..setUint16(6, 20, Endian.little)
      ..setUint16(10, 8, Endian.little)
      ..setUint32(20, packed.length, Endian.little)
      ..setUint32(24, bytes.length, Endian.little)
      ..setUint16(28, nameBytes.length, Endian.little)
      ..setUint32(42, offset, Endian.little);
    central
      ..add(entry.buffer.asUint8List())
      ..add(nameBytes);
  }
  final end = ByteData(22)
    ..setUint32(0, 0x06054b50, Endian.little)
    ..setUint16(8, files.length, Endian.little)
    ..setUint16(10, files.length, Endian.little)
    ..setUint32(12, central.length, Endian.little)
    ..setUint32(16, local.length, Endian.little);
  final out = File(target);
  await out.writeAsBytes([
    ...local.takeBytes(),
    ...central.takeBytes(),
    ...end.buffer.asUint8List(),
  ]);
  return out;
}
