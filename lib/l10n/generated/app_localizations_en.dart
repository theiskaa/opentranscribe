// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'opentranscribe';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsOffline =>
      'Everything stays on this device. No account, no cloud, no network.';

  @override
  String get entryUntranscribed => 'Untranscribed';

  @override
  String get retranscribe => 'Re-transcribe';

  @override
  String get delete => 'Delete';

  @override
  String get homeEmptyTitle => 'Nothing here yet';

  @override
  String get homeEmptyMessage => 'Speak your mind.';

  @override
  String get homePullToRecord => 'Pull to record';

  @override
  String get navSettings => 'Settings';

  @override
  String get navSearch => 'Search';

  @override
  String get recordStateRecording => 'Recording';

  @override
  String get recordStatePaused => 'Paused';

  @override
  String get recordErrorMessage => 'Something went wrong while recording.';

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
  String get playbackFailed => 'Playback isn\'t available right now.';

  @override
  String get settingsTranscription => 'Transcription';

  @override
  String get settingsModelDownload => 'Download';

  @override
  String get settingsModelInstalled => 'Installed';

  @override
  String get settingsModelFailed => 'Download failed. Tap to retry.';

  @override
  String get settingsStorage => 'Storage';

  @override
  String get settingsBackup => 'Include audio in backups';

  @override
  String get settingsApp => 'App';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get themeSystem => 'System';

  @override
  String get themeMatchSystem => 'Match system';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get settingsAppLanguage => 'App language';

  @override
  String get settingsLanguageInfo =>
      'The language your recordings are transcribed in. Each language uses its own on-device model.';

  @override
  String get settingsAppLanguageInfo =>
      'The language the app\'s own text is shown in. It does not change how recordings are transcribed.';

  @override
  String get settingsModels => 'Models';

  @override
  String get settingsModelsInfo =>
      'opentranscribe transcribes entirely on this device. The model below runs offline; nothing you say is sent anywhere.';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsOpenSource => 'Read the source code';

  @override
  String get settingsCreatedBy => 'Created by @theiskaa';
}
