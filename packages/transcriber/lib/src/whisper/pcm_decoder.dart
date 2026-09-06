import 'dart:io';

import 'package:flutter/foundation.dart';

/// A decoded slice: raw 16 kHz mono 32-bit float samples with no header, in a
/// file the caller owns and deletes.
@immutable
final class DecodedPcm {
  const DecodedPcm({required this.file, required this.frames});

  static const int sampleRate = 16000;

  final File file;
  final int frames;

  Duration get duration => Duration(microseconds: frames * 1000000 ~/ sampleRate);

  @override
  bool operator ==(Object other) =>
      other is DecodedPcm && other.file.path == file.path && other.frames == frames;

  @override
  int get hashCode => Object.hash(file.path, frames);
}

/// Decodes a slice of a kept recording, on-device, into the sample stream an
/// on-device model reads.
///
/// Guarantees a caller may rely on: the input is never modified; the output is
/// a fresh file under the platform's scratch directory, present only once
/// complete, and the caller deletes it; [start] and [end] are positions in the
/// input (null = its own edge), and a slice that would hold no frames (start at
/// or past end, or past the file) throws [PcmDecodeFailed] with code
/// `decode_empty` rather than answering silence; any failure throws
/// [PcmDecodeFailed] and leaves nothing behind. Nothing but paths and numbers
/// cross the platform boundary.
abstract interface class PcmDecoder {
  Future<DecodedPcm> decode(File audio, {Duration? start, Duration? end});
}
