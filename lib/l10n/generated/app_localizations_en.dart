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
}
