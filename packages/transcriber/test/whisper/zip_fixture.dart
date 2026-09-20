import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

final _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = (c & 1) != 0 ? 0xedb88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(List<int> bytes) {
  var c = 0xffffffff;
  for (final b in bytes) {
    c = _crcTable[(c ^ b) & 0xff] ^ (c >> 8);
  }
  return c ^ 0xffffffff;
}

void _u16(BytesBuilder b, int v) => b.add([v & 0xff, (v >> 8) & 0xff]);

void _u32(BytesBuilder b, int v) {
  _u16(b, v & 0xffff);
  _u16(b, (v >> 16) & 0xffff);
}

Uint8List zipOf(Map<String, List<int>?> entries, {bool deflate = true}) {
  final body = BytesBuilder();
  final central = BytesBuilder();
  for (final MapEntry(key: name, value: data) in entries.entries) {
    final raw = data ?? const <int>[];
    final method = data != null && deflate ? 8 : 0;
    final packed = method == 8 ? ZLibEncoder(raw: true).convert(raw) : raw;
    final nameBytes = utf8.encode(name);
    final offset = body.length;
    for (final b in [body, central]) {
      if (identical(b, central)) {
        _u32(b, 0x02014b50);
        _u16(b, 20);
      } else {
        _u32(b, 0x04034b50);
      }
      _u16(b, 20);
      _u16(b, 0);
      _u16(b, method);
      _u32(b, 0);
      _u32(b, _crc32(raw));
      _u32(b, packed.length);
      _u32(b, raw.length);
      _u16(b, nameBytes.length);
      _u16(b, 0);
      if (identical(b, central)) {
        _u16(b, 0);
        _u16(b, 0);
        _u16(b, 0);
        _u32(b, 0);
        _u32(b, offset);
      }
      b.add(nameBytes);
    }
    body.add(packed);
  }
  final directoryOffset = body.length;
  final out = BytesBuilder()
    ..add(body.toBytes())
    ..add(central.toBytes());
  _u32(out, 0x06054b50);
  _u16(out, 0);
  _u16(out, 0);
  _u16(out, entries.length);
  _u16(out, entries.length);
  _u32(out, central.length);
  _u32(out, directoryOffset);
  _u16(out, 0);
  return out.toBytes();
}
