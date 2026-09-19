/// Fakes for every contract in this package, for tests that inject them
/// without a device.
library;

export 'src/transcribe/fake_engine.dart';
export 'src/audio/fake_audio_activity.dart';
export 'src/audio/fake_audio_composer.dart';
export 'src/whisper/fake_model_choice_engine.dart';
export 'src/whisper/fake_model_fetcher.dart';
export 'src/whisper/fake_pcm_decoder.dart';
export 'src/whisper/fake_whisper_runtime.dart';
