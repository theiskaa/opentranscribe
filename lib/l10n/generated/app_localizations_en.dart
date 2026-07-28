// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'OpenTranscribe';

  @override
  String get settingsOffline =>
      'Everything stays on this device. No account, no cloud, no network.';

  @override
  String get entryUntranscribed => 'Untranscribed';

  @override
  String get entryUntranscribedTitle => 'Not transcribed yet';

  @override
  String get entryUntranscribedMessage =>
      'Turn this recording into text you can read back. It runs on your device.';

  @override
  String get entryNoSpeechTitle => 'No words to show';

  @override
  String get entryNoSpeechMessage =>
      'This recording was transcribed, but no speech was found in it.';

  @override
  String get retranscribe => 'Re-transcribe';

  @override
  String get delete => 'Delete';

  @override
  String get homeEmptyHeadline => 'Speak, and it\'s written down.';

  @override
  String get homeEmptySubtitle =>
      'Everything you say is transcribed and kept on this device. Pull down to record your first entry.';

  @override
  String get homePullToRecord => 'Pull to record';

  @override
  String get menuTranscriptionLanguage => 'Transcription';

  @override
  String get menuSourceCode => 'Source code';

  @override
  String get recordStateRecording => 'Recording';

  @override
  String get recordStatePaused => 'Paused';

  @override
  String get recordErrorMessage => 'Something went wrong while recording.';

  @override
  String get recordLiveUnavailable =>
      'Live text isn\'t available right now. Your recording is safe and will be transcribed when you finish.';

  @override
  String get recordInterruptedSaved =>
      'Recording interrupted. Your take was saved and can be transcribed from your journal.';

  @override
  String get recordPermissionTitle => 'Microphone is off';

  @override
  String get recordPermissionMessage =>
      'Allow microphone access for opentranscribe in the Settings app, then try again.';

  @override
  String get rename => 'Rename';

  @override
  String get transcribe => 'Transcribe';

  @override
  String get transcribeIn => 'Transcribe in…';

  @override
  String get playbackFailed => 'Playback isn\'t available right now.';

  @override
  String get transcribeErrorModelInstall =>
      'Couldn\'t get the speech model for this language. Check your connection and free space, or manage languages under Models.';

  @override
  String get transcribeErrorPermission =>
      'Allow speech recognition for opentranscribe in the Settings app, then try again.';

  @override
  String get transcribeErrorUnavailable =>
      'On-device transcription isn\'t available for this language on this device.';

  @override
  String get transcribeErrorGeneric => 'Something went wrong. Try again.';

  @override
  String get transcribeErrorCapReached =>
      'Language limit reached. Remove a language in Settings, then try again.';

  @override
  String get transcribeErrorLabelPermission => 'Speech recognition is off';

  @override
  String get transcribeErrorLabelUnavailable => 'Not available on this device';

  @override
  String get transcribeErrorLabelModelInstall => 'Couldn\'t get the language model';

  @override
  String get transcribeErrorLabelCapReached => 'Language limit reached';

  @override
  String get transcribeErrorLabelGeneric => 'Transcription failed';

  @override
  String get transcribeErrorTitlePermission => 'Turn on speech recognition';

  @override
  String get transcribeErrorTitleUnavailable => 'Not available here';

  @override
  String get transcribeErrorTitleModelInstall => 'Couldn\'t download the model';

  @override
  String get transcribeErrorTitleCapReached => 'Language limit reached';

  @override
  String get transcribeErrorTitleGeneric => 'Something went wrong';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeNameDefault => 'Default';

  @override
  String get themeNameGruvbox => 'Gruvbox';

  @override
  String get themeNameSolarized => 'Solarized';

  @override
  String get themeNameSepia => 'Sepia';

  @override
  String get settingsAppLanguage => 'Language';

  @override
  String get transcriptionInfo =>
      'Each language runs its own on-device model, downloaded once and shared with the system; models don\'t count against this app\'s storage. iOS limits how many languages an app can keep ready at once.';

  @override
  String transcriptionCap(int used, int max) {
    return '$used of $max language slots used';
  }

  @override
  String get transcriptionRemoveHint => 'Swipe left on a language to remove it.';

  @override
  String get transcriptionErrorUnsupported =>
      'This language can\'t be downloaded on this device yet.';

  @override
  String get transcriptionErrorStuck =>
      'A previous download is still pending. iOS retries when conditions improve; trying again is safe.';

  @override
  String get transcriptionErrorGeneric =>
      'Download failed. Check your connection and free space, then try again.';

  @override
  String get transcriptionErrorCap => 'Language limit reached. Remove a language to add this one.';

  @override
  String get transcriptionErrorRemove => 'Couldn\'t remove this language. Try again.';

  @override
  String get transcriptionDownloading => 'Downloading';

  @override
  String get retry => 'Try again';

  @override
  String get modelFailCapTitle => 'Language limit reached';

  @override
  String modelFailCapBody(String language) {
    return 'iOS limits how many languages an app can keep ready at once. Remove one of these to make room for $language.';
  }

  @override
  String get modelFailUnsupportedTitle => 'Not available yet';

  @override
  String modelFailUnsupportedBody(String language) {
    return 'There\'s no on-device model for $language on this device yet. It may arrive with a system update.';
  }

  @override
  String get modelFailStuckTitle => 'Still downloading';

  @override
  String modelFailStuckBody(String language) {
    return 'A previous download for $language is still pending. iOS retries it when conditions improve, and asking again is safe.';
  }

  @override
  String get modelFailGenericTitle => 'Couldn\'t download';

  @override
  String modelFailGenericBody(String language) {
    return 'The $language model couldn\'t be downloaded. Check your connection and free space. iOS may also be unable to provide this model right now; trying again is safe.';
  }

  @override
  String get modelFailRemoveTitle => 'Couldn\'t remove';

  @override
  String modelFailRemoveBody(String language) {
    return 'iOS didn\'t release $language. Trying again is safe.';
  }

  @override
  String get settingsModels => 'Models';

  @override
  String get transcriptionLanguages => 'Languages';

  @override
  String get transcriptionDefaultTag => 'Default';

  @override
  String get transcriptionDefaultHint => 'Touch and hold a language to make it the default.';

  @override
  String transcriptionDeviceLanguageFallback(String fallback) {
    return 'Your phone\'s language isn\'t supported for on-device transcription yet, so $fallback is the default.';
  }

  @override
  String get onboardingIntroBody => 'You speak your mind, and it writes it down.';

  @override
  String get onboardingSpeakTitle => 'Just talk';

  @override
  String get onboardingSpeakLine => 'Tap record and say what is on your mind.';

  @override
  String get onboardingWriteTitle => 'Read it back';

  @override
  String get onboardingWriteLine => 'Every recording is written down as text.';

  @override
  String get onboardingPrivateTitle => 'Nothing leaves the phone';

  @override
  String get onboardingPrivateLine => 'No account, no cloud. Airplane mode changes nothing.';

  @override
  String get onboardingSource => 'Open source';

  @override
  String get onboardingSourceLine => 'Every line of it is public. Read it on GitHub.';

  @override
  String get onboardingPermissionsTitle => 'Allow access';

  @override
  String get onboardingPermissionsBody => 'Both work entirely on your device.';

  @override
  String get onboardingMicName => 'Microphone';

  @override
  String get onboardingMicReason => 'To record your voice.';

  @override
  String get onboardingSpeechName => 'Speech recognition';

  @override
  String get onboardingSpeechReason => 'To turn your recordings into text, on device.';

  @override
  String get onboardingAllow => 'Allow';

  @override
  String get onboardingOpenSettings => 'Enable in Settings';

  @override
  String get onboardingModelsTitle => 'Download a language';

  @override
  String get onboardingModelsBody =>
      'Transcription runs offline once a language is on your device. You can add more anytime from the menu.';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingStart => 'Get started';
}
