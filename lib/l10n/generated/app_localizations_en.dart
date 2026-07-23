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
  String get recordStart => 'Record';

  @override
  String get recordStop => 'Done';

  @override
  String get entriesTitle => 'Entries';

  @override
  String get entriesEmpty => 'Nothing here yet. Speak your mind.';

  @override
  String get reflectionTitle => 'This week';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsOffline =>
      'Everything stays on this device. No account, no cloud, no network.';

  @override
  String get recordHint => 'Tap to record';

  @override
  String get entryTitle => 'Entry';

  @override
  String get entryUntranscribed => 'Untranscribed';

  @override
  String get retranscribe => 'Re-transcribe';

  @override
  String get delete => 'Delete';

  @override
  String get deleteConfirmTitle => 'Delete entry?';

  @override
  String get deleteConfirmMessage =>
      'This removes the recording and its transcript from this device.';

  @override
  String get cancel => 'Cancel';

  @override
  String get recordErrorTitle => 'Couldn\'t record';

  @override
  String get ok => 'OK';
}
