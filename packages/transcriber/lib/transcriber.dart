/// Audio capture, playback, and on-device transcription.
///
/// The engine and device contracts live here (`AudioRecorder`, `AudioComposer`,
/// `AudioPlayer`, `TranscriptionEngine` and its extensions) together with the
/// platform-channel implementations. Fakes for tests are exported separately
/// from `package:transcriber/testing.dart`.
library;

export 'src/audio/audio_activity.dart';
export 'src/audio/audio_composer.dart';
export 'src/audio/audio_player.dart';
export 'src/audio/audio_recorder.dart';
export 'src/audio/platform_audio_activity.dart';
export 'src/audio/platform_audio_composer.dart';
export 'src/audio/platform_audio_player.dart';
export 'src/audio/platform_audio_recorder.dart';
export 'src/audio/playback.dart';
export 'src/audio/recording.dart';
export 'src/transcribe/apple_speech_engines.dart';
export 'src/transcribe/install_wait.dart';
export 'src/transcribe/transcript.dart';
export 'src/transcribe/transcript_event.dart';
export 'src/transcribe/transcription_engine.dart';
export 'src/transcribe/transcription_exception.dart';
export 'src/whisper/ffi_whisper_runtime.dart';
export 'src/whisper/model_fetcher.dart';
export 'src/whisper/model_storage.dart';
export 'src/whisper/pcm_decoder.dart';
export 'src/whisper/platform_model_storage.dart';
export 'src/whisper/platform_pcm_decoder.dart';
export 'src/whisper/whisper_catalog.dart';
export 'src/whisper/whisper_engine.dart';
export 'src/whisper/whisper_runtime.dart';
