import 'package:transcriber/src/audio/recording.dart';

/// Joins kept recordings into one new file, on-device.
///
/// [names] are bare filenames inside [AudioRecorder.recordingsDirectory], in
/// playback order, two or more. Guarantees a caller may rely on: the inputs are
/// never modified or deleted; the output is a fresh `otr-*.m4a` in the same
/// directory, present only once complete (it is written elsewhere and moved in,
/// so a kill mid-merge leaves nothing where an orphan sweep looks); on any
/// failure the call throws [AudioComposeFailed] and no partial output exists in
/// the recordings directory; two calls never run at once. [Composition.starts]
/// are the writer's own measurements, the numbers to offset by rather than any
/// stored duration. Nothing but names and numbers cross the platform boundary.
abstract interface class AudioComposer {
  Future<Composition> concatenate(List<String> names);
}
