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
      'Each language runs its own on-device model, downloaded once and shared with the system; models don\'t count against this app\'s storage. The system limits how many languages an app can keep ready at once.';

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
      'A previous download is still pending. The system retries when conditions improve; trying again is safe.';

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
    return 'The system limits how many languages an app can keep ready at once. Remove one of these to make room for $language.';
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
    return 'A previous download for $language is still pending. The system retries it when conditions improve, and asking again is safe.';
  }

  @override
  String get modelFailGenericTitle => 'Couldn\'t download';

  @override
  String modelFailGenericBody(String language) {
    return 'The $language model couldn\'t be downloaded. Check your connection and free space, then try again.';
  }

  @override
  String get modelFailRemoveTitle => 'Couldn\'t remove';

  @override
  String modelFailRemoveBody(String language) {
    return 'The system didn\'t release $language. Trying again is safe.';
  }

  @override
  String get settingsModels => 'Transcription';

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
  String get onboardingReflectTitle => 'Reflections';

  @override
  String get onboardingReflectLine => 'Your entries read back as a short note, all on device.';

  @override
  String get onboardingSource => 'Open source';

  @override
  String get onboardingSourceLine => 'Every line of it is public. Read it on GitHub.';

  @override
  String get onboardingPermissionsTitle => 'Allow access';

  @override
  String get onboardingPermissionsBody => 'Everything here works entirely on your device.';

  @override
  String get onboardingMicName => 'Microphone';

  @override
  String get onboardingMicReason => 'To record your voice.';

  @override
  String get onboardingSpeechName => 'Speech recognition';

  @override
  String get onboardingSpeechReason => 'To turn your recordings into text, on device.';

  @override
  String get onboardingNotifyName => 'Notifications';

  @override
  String get onboardingNotifyReason => 'For a nudge when a reflection is ready.';

  @override
  String get onboardingAllow => 'Allow';

  @override
  String get onboardingOpenSettings => 'Enable in Settings';

  @override
  String get onboardingModelsTitle => 'Set up transcription';

  @override
  String get onboardingModelsBody =>
      'It runs offline once your language is on the device. You can add more anytime from the menu.';

  @override
  String get onboardingReflectionsOn =>
      'Your entries read back as a short reflection, entirely on this device.';

  @override
  String get onboardingReflectionsPreparing =>
      'Starts once Apple Intelligence finishes preparing on this device.';

  @override
  String get onboardingReflectionsOff =>
      'Turn on Apple Intelligence in Settings, under Apple Intelligence and Siri, to get them.';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingStart => 'Get started';

  @override
  String get settingsCache => 'Cache';

  @override
  String cacheRecordingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recordings',
      one: '1 recording',
    );
    return '$_temp0';
  }

  @override
  String get cacheReclaimable => 'Reclaimable';

  @override
  String get cacheReclaimableInfo => 'Transcribed, safe to clear';

  @override
  String get cacheUsageInfo =>
      'Audio of transcribed entries can be cleared; their text stays. Recordings not transcribed yet are never touched.';

  @override
  String get cacheKeepAudio => 'Keep audio';

  @override
  String get cacheKeepAudioInfo =>
      'When off, each recording is deleted once its transcription succeeds. Such entries are text only: no playback, and no re-transcription by a better engine later.';

  @override
  String get cacheClear => 'Clear transcribed audio';

  @override
  String get cacheClearTitle => 'Clear transcribed audio?';

  @override
  String cacheClearBody(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Deletes the audio of $count transcribed entries ($size). Their text stays. This cannot be undone.',
      one:
          'Deletes the audio of one transcribed entry ($size). Its text stays. This cannot be undone.',
    );
    return '$_temp0';
  }

  @override
  String get cacheClearConfirm => 'Delete recordings';

  @override
  String get reflectionsTitle => 'Reflections';

  @override
  String get reflectionPeriods => 'Periods';

  @override
  String get reflectionDaily => 'Daily';

  @override
  String get reflectionWeekly => 'Weekly';

  @override
  String get reflectionMonthly => 'Monthly';

  @override
  String get reflectionsEmptyTitle => 'No reflections yet';

  @override
  String get reflectionsEmptyBody =>
      'The first arrives once you have journaled, read back from what you recorded.';

  @override
  String get reflectionQuietDay => 'A quiet day.';

  @override
  String get reflectionQuietWeek => 'A quiet week.';

  @override
  String get reflectionQuietMonth => 'A quiet month.';

  @override
  String get reflectionWaitingTitle => 'Not written yet';

  @override
  String get reflectionWaitingBody =>
      'This will be read back the next time the journal opens with Apple Intelligence ready.';

  @override
  String get reflectionErasedTitle => 'Erased';

  @override
  String get reflectionErasedBody => 'You removed this reflection. Regenerate writes it again.';

  @override
  String get reflectionQuietBody => 'Nothing rose to a reflection.';

  @override
  String reflectionWrittenOn(String date) {
    return 'Written $date';
  }

  @override
  String reflectionOfPeriod(String range) {
    return 'Reflection of $range';
  }

  @override
  String get reflectionVoice => 'Voice';

  @override
  String get reflectionVoiceLiterary => 'Literary';

  @override
  String get reflectionVoiceObservational => 'Observational';

  @override
  String get reflectionVoiceSparse => 'Sparse';

  @override
  String get reflectionLength => 'Length';

  @override
  String get reflectionLengthOneLine => 'One line';

  @override
  String get reflectionLengthSentences => 'A few sentences';

  @override
  String get reflectionLengthParagraph => 'Short paragraph';

  @override
  String get reflectionSpecifics => 'Specifics';

  @override
  String get reflectionSpecificsNameFreely => 'Name specifics';

  @override
  String get reflectionSpecificsThemes => 'Themes only';

  @override
  String get reflectionSpecificsLetPeriod => 'Let it decide';

  @override
  String get reflectionRegenerate => 'Regenerate';

  @override
  String get reflectionDeleteDay => 'Delete day';

  @override
  String get reflectionDeleteWeek => 'Delete week';

  @override
  String get reflectionDeleteMonth => 'Delete month';

  @override
  String get reflectionRegenerateFailed => 'Could not reflect. Try again.';

  @override
  String get reflectionsDisabledTitle => 'Reflections are off';

  @override
  String get reflectionsDisabledBody => 'Nothing new will be written while reflections are off.';

  @override
  String get reflectionsDisabledEnable => 'Turn on';

  @override
  String get reflectionOffTitle => 'Apple Intelligence is off';

  @override
  String get reflectionOffBody =>
      'Turn it on in Settings, under Apple Intelligence and Siri, to get reflections.';

  @override
  String get reflectionPreparingTitle => 'Getting ready';

  @override
  String get reflectionPreparingBody =>
      'Apple Intelligence is preparing on this device. Reflections start once it finishes.';

  @override
  String get reflectionUnsupportedTitle => 'Not available here';

  @override
  String get reflectionUnsupportedBody =>
      'This device does not support Apple Intelligence, which reflections need.';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get notifyDailyReflection => 'Daily reflections';

  @override
  String get notifyWeeklyReflection => 'Weekly reflections';

  @override
  String get notifyMonthlyReflection => 'Monthly reflections';

  @override
  String get notifyReflectionsInfo =>
      'A nudge when a new reflection is ready to read. It fires on your device; nothing is sent anywhere.';

  @override
  String get notifyTime => 'Time';

  @override
  String get notifyPermissionDenied => 'Notifications are turned off in Settings.';

  @override
  String get notifyOpenSettings => 'Open Settings';

  @override
  String get notifyDailyTitle => 'Your day is ready';

  @override
  String get notifyDailyBody => 'Open to read yesterday\'s reflection.';

  @override
  String get notifyWeeklyTitle => 'Your week is ready';

  @override
  String get notifyWeeklyBody => 'Open to read last week\'s reflection.';

  @override
  String get notifyMonthlyTitle => 'Your month is ready';

  @override
  String get notifyMonthlyBody => 'Open to read last month\'s reflection.';

  @override
  String get notifyNeedsReflections =>
      'Nudges arrive when a new reflection is ready to read. Reflections are off right now.';

  @override
  String get notifyTurnOnReflections => 'Turn on reflections';

  @override
  String get notifyReflectionsUnavailable =>
      'This device can\'t generate reflections, so there\'s no nudge to send.';

  @override
  String get themeRequestInfo =>
      'Want OpenTranscribe in a theme that isn\'t here? Open an issue on GitHub and we\'ll add it in an upcoming release.';

  @override
  String get themeRequestLink => 'Request a theme on GitHub';
}
