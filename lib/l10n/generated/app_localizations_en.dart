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
  String get launchFailedTitle => 'Could not start';

  @override
  String get launchFailedBody =>
      'Something the app needs at launch did not load. Close the app from the app switcher and open it again; if that does not help, restart the phone.';

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
  String get retranscribeAllTitle => 'Re-transcribe all';

  @override
  String get retranscribeRowQueued => 'To re-transcribe';

  @override
  String get retranscribeRowCurrent => 'Already current';

  @override
  String get retranscribeRowLanded => 'Re-transcribed';

  @override
  String get retranscribeRowFailed => 'Failed';

  @override
  String get retranscribeHistoryNote => 'Replaced words stay in each entry\'s history.';

  @override
  String get retranscribeFailedNote => 'Failed entries stay queued for the next run.';

  @override
  String retranscribeAllCurrentBody(String engine) {
    return 'Every kept recording is already transcribed by $engine.';
  }

  @override
  String get retranscribeStart => 'Start';

  @override
  String retranscribeProgressOf(int done, int total) {
    return '$done of $total';
  }

  @override
  String get retranscribeWaitingRecording => 'Paused while a recording finishes';

  @override
  String get retranscribeWaitingThermal => 'Paused while the device cools down';

  @override
  String get retranscribeCancel => 'Cancel';

  @override
  String get retranscribeCancelledNote =>
      'Stopped early. Running again picks up where it left off.';

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
  String get editTranscript => 'Edit';

  @override
  String get editedMarker => 'Edited';

  @override
  String get revisionHistory => 'History';

  @override
  String get revisionHistoryBody =>
      'Everything this entry\'s text has been through. Tapping a version restores it as the newest.';

  @override
  String get revisionCurrent => 'Current';

  @override
  String get revisionTranscribed => 'Transcribed';

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
  String get transcribeErrorRecordingMissing =>
      'This entry\'s recording isn\'t on the device anymore, so it can\'t be transcribed again. What it already reads as is all there is.';

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
  String get transcribeErrorLabelRecordingMissing => 'Recording gone';

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
  String get transcribeErrorTitleRecordingMissing => 'The recording is gone';

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
  String get themeNameSepia => 'Sepia';

  @override
  String get themeNameMidnight => 'Midnight';

  @override
  String get themeNameDracula => 'Dracula';

  @override
  String get themeNameNord => 'Nord';

  @override
  String get themeNameCatppuccin => 'Catppuccin';

  @override
  String get themeNameTokyoNight => 'Tokyo Night';

  @override
  String get appearanceIconSection => 'App icon';

  @override
  String get appIconNameSignal => 'Signal';

  @override
  String get appIconNameLines => 'Lines';

  @override
  String get appIconNameDots => 'Dots';

  @override
  String get appIconFailedTitle => 'The icon did not change';

  @override
  String get appIconFailedBody => 'iOS refused the change. Try again.';

  @override
  String get settingsAppLanguage => 'Language';

  @override
  String transcriptionCap(int used, int max) {
    return '$used of $max language slots used';
  }

  @override
  String get transcriptionErrorUnsupported =>
      'This language can\'t be downloaded on this device yet.';

  @override
  String get languageNeedsDictation =>
      'Turn on dictation for this language in iOS keyboard settings.';

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
  String get modelFailDictationTitle => 'Dictation isn\'t set up';

  @override
  String modelFailDictationBody(String language) {
    return '$language transcribes with the system\'s dictation model, which isn\'t on this iPhone yet. Add its keyboard and turn on dictation in iOS Settings.';
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
  String get transcriptionYourLanguages => 'Your languages';

  @override
  String get transcriptionAllLanguages => 'All languages';

  @override
  String get transcriptionSpeaking => 'Speaking';

  @override
  String get transcriptionAlsoReady => 'Also ready';

  @override
  String get transcriptionAddLanguage => 'Add';

  @override
  String transcriptionHeroReady(String engine) {
    return 'Ready · $engine';
  }

  @override
  String get transcriptionFootnote => 'Models download once and are shared with the system.';

  @override
  String get transcriptionEngines => 'Engines';

  @override
  String get engineBlurbSpeechAnalyzer => 'Apple\'s newest engine, a downloaded model per language';

  @override
  String get engineBlurbDictation => 'The recognizer behind iOS keyboard dictation';

  @override
  String get engineUnavailableNote => 'Not available on this iPhone';

  @override
  String get engineUnavailableTitle => 'Not available on this iPhone';

  @override
  String engineUnavailableBody(String engine) {
    return '$engine needs iOS 26 and a newer iPhone. Recording keeps using the engine that works here.';
  }

  @override
  String get engineBusyTitle => 'Recording in progress';

  @override
  String get engineBusyBody => 'Stop the current recording, then switch engines.';

  @override
  String get engineRetranscribingTitle => 'Re-transcribing';

  @override
  String get engineRetranscribingBody =>
      'Wait for the run to finish, or cancel it, then switch engines.';

  @override
  String get engineNotSavedTitle => 'Couldn\'t save the choice';

  @override
  String get engineNotSavedBody =>
      'The engine choice couldn\'t be saved and won\'t survive a relaunch.';

  @override
  String get transcriptionDefaultTag => 'Default';

  @override
  String transcriptionDeviceLanguageFallback(String fallback) {
    return 'Your phone\'s language isn\'t supported for on-device transcription yet, so $fallback is the default.';
  }

  @override
  String get onboardingOpenSettings => 'Enable in Settings';

  @override
  String get onboardingReflectTitle => 'Your week, read back';

  @override
  String get onboardingReflectBody =>
      'Entries read back as a short reflection, by day, week, or month. Written on this device by Apple Intelligence, never sent anywhere.';

  @override
  String get onboardingReflectDay1 => 'Slept badly, but the morning run fixed most of it.';

  @override
  String get onboardingReflectDay2 => 'Dana, coffee, two hours about nothing and everything.';

  @override
  String get onboardingReflectDay3 => 'Said no to the extra project. Felt lighter all day.';

  @override
  String get onboardingReflectDay4 => 'Walked home the long way. The city was quiet for once.';

  @override
  String get onboardingReflectNote =>
      'A week of saying no to more, and the long walks that came back once you did.';

  @override
  String get onboardingShapeTitle => 'Yours, in any shape';

  @override
  String get onboardingShapeBody =>
      'Take the whole journal as Markdown, an Obsidian vault, or a website. Back it up sealed with a passphrase only you know. Nothing syncs unless you carry it.';

  @override
  String get onboardingBackupLine => 'Sealed with a passphrase, restores anywhere.';

  @override
  String get onboardingRecordTitle => 'You speak your mind, and it writes it down.';

  @override
  String get onboardingRecordBody =>
      'Every word stays on this phone. No account, no cloud. Airplane mode changes nothing.';

  @override
  String get onboardingRecordText1 =>
      'Met Lia for coffee and we ended up talking about the move for two hours.';

  @override
  String get onboardingRecordText2 =>
      'I keep saying I want a smaller life and then filling every evening.';

  @override
  String get onboardingRecordText3 => 'Walked home the long way. The city was quiet for once.';

  @override
  String get onboardingRecordText4 =>
      'Then I sat on the steps for a while and did nothing, which felt like the point.';

  @override
  String get onboardingRecordText5 => 'Work was fine. Nobody asked for anything I could not give.';

  @override
  String get onboardingRecordText6 => 'Tomorrow I want to call Mum before it gets late.';

  @override
  String get onboardingLanguageDownloads => 'Downloads once, then works offline.';

  @override
  String get onboardingLanguageBuiltIn => 'Built in. Nothing to download.';

  @override
  String get onboardingLanguageReady => 'Ready, on this device.';

  @override
  String get onboardingLanguageLoading => 'Reading your language';

  @override
  String get onboardingPermissionsTitle => 'Allow access';

  @override
  String get onboardingPermissionsBody =>
      'Everything here works entirely on your device. Get started asks for the microphone and speech recognition; either can be changed later in Settings.';

  @override
  String get onboardingMicName => 'Microphone';

  @override
  String get onboardingMicReason => 'To record your voice.';

  @override
  String get onboardingSpeechName => 'Speech recognition';

  @override
  String get onboardingSpeechReason => 'To turn your recordings into text, on device.';

  @override
  String onboardingReflectWeek(int number) {
    return 'Week $number';
  }

  @override
  String get onboardingShapeObsidianName => 'Obsidian';

  @override
  String get onboardingShapeMarkdownNote => 'One file each';

  @override
  String get onboardingShapeObsidianNote => 'Linked vault';

  @override
  String get onboardingShapeWebNote => 'Any browser';

  @override
  String get onboardingReflectionsOn => 'Apple Intelligence is on.';

  @override
  String get onboardingReflectionsPreparing =>
      'Apple Intelligence is still preparing on this device.';

  @override
  String get onboardingReflectionsOff => 'Turn on Apple Intelligence in Settings to get them.';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingStart => 'Get started';

  @override
  String get onboardingDone => 'Done';

  @override
  String get hintEntryMenu =>
      'Everything this entry can do is in the menu up here: edit the text, export it, record more onto it.';

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
  String get reflectionGenerateAll => 'Generate reflections';

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
  String get notifyReflectionReminders => 'Reflection reminders';

  @override
  String get notifyPeriodDay => 'Day';

  @override
  String get notifyPeriodWeek => 'Week';

  @override
  String get notifyPeriodMonth => 'Month';

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
      'Want OpenTranscribe in a theme that isn\'t here? Open an issue on GitHub and we\'ll add it in an upcoming release. Added themes are for OpenTranscribe Club members.';

  @override
  String get themeRequestLink => 'Request a theme on GitHub';

  @override
  String get exportEntry => 'Export';

  @override
  String get exportEntryTitle => 'Export entry';

  @override
  String get exportIncludeAudio => 'Include audio';

  @override
  String get exportFormatMarkdown => 'Markdown';

  @override
  String get exportFormatMarkdownNote => 'A note per entry, plus JSON for machines.';

  @override
  String get exportFormatObsidian => 'Obsidian Vault';

  @override
  String get exportFormatObsidianNote => 'Notes with properties, recordings embedded.';

  @override
  String get exportFormatWeb => 'Website';

  @override
  String get exportFormatWebNote => 'Search and a player, in any browser.';

  @override
  String get exportFailedTitle => 'Export failed';

  @override
  String get exportFailedBody => 'Could not prepare the files. Nothing was shared.';

  @override
  String get exportTooLargeBody =>
      'The export exceeds the 4 GB a single file can hold. Nothing was shared.';

  @override
  String get exportNoSpaceBody => 'Not enough free space to prepare the files. Nothing was shared.';

  @override
  String get exportCancel => 'Cancel';

  @override
  String get exportUntitled => 'Untitled';

  @override
  String get exportTranscriptHeading => 'Transcript';

  @override
  String get exportQuiet => 'A quiet stretch.';

  @override
  String get exportHtmlSearch => 'Search';

  @override
  String get exportHtmlSchemeLabel => 'Color scheme';

  @override
  String get exportHtmlSchemeAuto => 'Auto';

  @override
  String get exportHtmlSchemeLight => 'Light';

  @override
  String get exportHtmlSchemeDark => 'Dark';

  @override
  String get exportHtmlEmptyTitle => 'Nothing here yet';

  @override
  String get exportHtmlEmptyBody => 'This journal has no entries.';

  @override
  String get exportHtmlNoMatchesTitle => 'Nothing found';

  @override
  String exportHtmlNoMatches(String term) {
    return 'No entry matches “$term”';
  }

  @override
  String get exportHtmlPlay => 'Play';

  @override
  String get exportHtmlPause => 'Pause';

  @override
  String get exportHtmlBack => 'Back 15 seconds';

  @override
  String get exportHtmlSpeed => 'Playback speed';

  @override
  String get exportHtmlSeek => 'Seek';

  @override
  String get settingsBackup => 'Backup';

  @override
  String get backupInfo =>
      'A backup holds every entry with its audio and reflections. Encrypt it and your passphrase is the only key.';

  @override
  String get backupInfoEmpty =>
      'Nothing to back up yet. A backup holds every entry with its audio and reflections.';

  @override
  String backupInfoMeasured(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'A backup holds all $count entries with their audio and reflections, about $size.',
      one: 'A backup holds your 1 entry with its audio and reflections, about $size.',
    );
    return '$_temp0 Encrypt it and your passphrase is the only key.';
  }

  @override
  String get backupExportSection => 'Export';

  @override
  String backupExportAs(String format) {
    return 'Export as $format';
  }

  @override
  String get backupExportInfo =>
      'Writes every entry in a format you choose at export time, zipped for the share sheet. A copy for other apps; restoring needs a backup.';

  @override
  String get backupSeal => 'Encrypt with passphrase';

  @override
  String get backupSave => 'Export backup';

  @override
  String backupLastBackup(String date) {
    return 'Last backup $date';
  }

  @override
  String get passphraseCreateTitle => 'Encrypt the backup';

  @override
  String get passphraseCreateBody =>
      'The passphrase is the only key. It is not stored anywhere; without it the backup is noise.';

  @override
  String get passphrasePlaceholder => 'Passphrase';

  @override
  String get passphraseRepeatPlaceholder => 'Repeat passphrase';

  @override
  String get passphraseTooShort => 'At least 8 characters';

  @override
  String get passphraseMismatch => 'Passphrases do not match';

  @override
  String get passphraseShow => 'Show';

  @override
  String get passphraseHide => 'Hide';

  @override
  String get importUnlockTitle => 'Encrypted backup';

  @override
  String get importUnlockBody => 'Enter the passphrase this backup was encrypted with.';

  @override
  String get importUnlock => 'Unlock';

  @override
  String get importWrongPassphrase => 'Could not unlock. Wrong passphrase, or a damaged file.';

  @override
  String get importConfirmTitle => 'Restore this backup?';

  @override
  String get importConfirmBody =>
      'Adds its entries to your journal. An entry that already exists takes the backup\'s version, undoing edits made since that backup. Restoring the same backup twice never duplicates.';

  @override
  String get importConfirm => 'Restore';

  @override
  String get importSummaryTitle => 'Restore complete';

  @override
  String importSummaryAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Added $count entries.',
      one: 'Added 1 entry.',
      zero: 'Nothing new to add.',
    );
    return '$_temp0';
  }

  @override
  String importSummaryReplaced(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries were replaced with the backup\'s version.',
      one: '1 entry was replaced with the backup\'s version.',
    );
    return '$_temp0';
  }

  @override
  String importSummarySkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries were already in the journal.',
      one: '1 entry was already in the journal.',
    );
    return '$_temp0';
  }

  @override
  String importSummaryAudio(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recordings restored.',
      one: '1 recording restored.',
    );
    return '$_temp0';
  }

  @override
  String importConfirmCounts(int count, int audio) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries',
      one: '1 entry',
    );
    String _temp1 = intl.Intl.pluralLogic(
      audio,
      locale: localeName,
      other: '$audio recordings',
      one: '1 recording',
      zero: 'no recordings',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get importFailedTitle => 'Restore failed';

  @override
  String get importFailedBody =>
      'The backup could not be read. Nothing in the journal was changed.';

  @override
  String get importNotArchive =>
      'Not an OpenTranscribe backup. Nothing in the journal was changed.';

  @override
  String get importNewerVersion => 'Made by a newer version of the app. Update to import it.';

  @override
  String get importRezipped =>
      'This backup was re-zipped by another tool. Save a fresh one and restore that.';

  @override
  String get backButton => 'Back';

  @override
  String get menuButton => 'More';

  @override
  String get languageMenuButton => 'Language';

  @override
  String get recordButton => 'New entry';

  @override
  String get recordCloseButton => 'Cancel';

  @override
  String get recordRestartButton => 'Start over';

  @override
  String get recordPauseButton => 'Pause';

  @override
  String get recordResumeButton => 'Resume';

  @override
  String get recordCompleteButton => 'Save';

  @override
  String get restoreBackupButton => 'Restore backup';

  @override
  String get done => 'Done';

  @override
  String get importFailedMidway =>
      'The restore stopped partway. Everything restored so far is kept; restore again to finish.';

  @override
  String get settingsSupport => 'Support';

  @override
  String get supportPitch =>
      'The club is how OpenTranscribe is supported: one payment, in for good, and a few looks as thanks.';

  @override
  String get supportPitchFree =>
      'Everything that makes OpenTranscribe useful is free for everyone, and stays that way.';

  @override
  String get supportPerkThemes => 'Club themes';

  @override
  String get supportPerkThemesNote => 'Gruvbox, Dracula, Nord, and every family beyond Default.';

  @override
  String get supportPerkIcons => 'App icons';

  @override
  String get supportPerkIconsNote => 'Signal, Lines, Dots, and every icon beyond Default.';

  @override
  String get supportThanks => 'You\'re in the club for good. Thank you.';

  @override
  String supportJoin(String price) {
    return 'Join the club for $price';
  }

  @override
  String get supportRestore => 'Restore purchases';

  @override
  String get supportUnreachable =>
      'The App Store could not be reached. Close this and open it again to try again.';

  @override
  String get supportPending => 'Waiting for approval. The purchase finishes once it is approved.';

  @override
  String get supportRestoreNoneTitle => 'Nothing to restore';

  @override
  String get supportRestoreNoneBody => 'No club purchase is attached to this Apple ID.';

  @override
  String get supportFailedTitle => 'That did not go through';

  @override
  String get supportFailedBody => 'The App Store could not finish. Try again.';

  @override
  String get supportPrivacy => 'privacy policy';

  @override
  String get supportTerms => 'terms of use';

  @override
  String get supportUnlocksSection => 'What you get';

  @override
  String get supporterTag => 'Club';

  @override
  String supportFooter(String privacy, String terms) {
    return 'Supporting changes nothing about privacy. The journal never leaves the phone, as the $privacy says, and the purchase runs on Apple\'s standard $terms.';
  }

  @override
  String get continueRecording => 'Record more';

  @override
  String continuingEntry(String title) {
    return 'Continuing $title';
  }

  @override
  String get continueUntranscribedLabel => 'New part not transcribed';

  @override
  String get continueUntranscribedTitle => 'The new part wasn\'t transcribed';

  @override
  String get continueUntranscribedBody =>
      'The recording grew, but the words you just added didn\'t land. Re-transcribe to hear all of it.';

  @override
  String get continueSavedSeparatelyLabel => 'Saved as a new entry';

  @override
  String get continueSavedSeparatelyBody =>
      'The new take couldn\'t be joined onto this entry, so it was saved on its own.';

  @override
  String get continueEntryBusy => 'This entry is still being transcribed.';
}
