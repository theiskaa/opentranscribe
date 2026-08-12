/// Audio capture, playback, and on-device transcription.
///
/// The engine and device contracts live here (`AudioRecorder`, `AudioPlayer`,
/// `TranscriptionEngine` and its extensions) together with the platform-channel
/// implementations. Fakes for tests are exported separately from
/// `package:transcriber/testing.dart`.
library;

export 'src/audio/audio_player.dart';
export 'src/audio/audio_recorder.dart';
export 'src/audio/platform_audio_player.dart';
export 'src/audio/platform_audio_recorder.dart';
export 'src/audio/playback.dart';
export 'src/audio/recording.dart';
export 'src/transcribe/apple_speech_engine.dart';
export 'src/transcribe/transcript.dart';
export 'src/transcribe/transcript_event.dart';
export 'src/transcribe/transcription_engine.dart';
export 'src/transcribe/transcription_exception.dart';
