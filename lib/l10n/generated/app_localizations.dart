import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'opentranscribe'**
  String get appTitle;

  /// Label for the language setting
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// Settings note describing the offline promise
  ///
  /// In en, this message translates to:
  /// **'Everything stays on this device. No account, no cloud, no network.'**
  String get settingsOffline;

  /// One-word placeholder for an untranscribed entry's excerpt in the home list
  ///
  /// In en, this message translates to:
  /// **'Untranscribed'**
  String get entryUntranscribed;

  /// Heading on the entry screen when a recording has never been transcribed
  ///
  /// In en, this message translates to:
  /// **'Not transcribed yet'**
  String get entryUntranscribedTitle;

  /// Explanation under the untranscribed heading; the Transcribe action is the screen's bottom CTA
  ///
  /// In en, this message translates to:
  /// **'Turn this recording into text you can read back. It runs on your device.'**
  String get entryUntranscribedMessage;

  /// Heading on the entry screen when transcription finished but found no speech
  ///
  /// In en, this message translates to:
  /// **'No words to show'**
  String get entryNoSpeechTitle;

  /// Explanation when a transcript came back empty
  ///
  /// In en, this message translates to:
  /// **'This recording was transcribed, but no speech was found in it.'**
  String get entryNoSpeechMessage;

  /// Button to transcribe a kept recording again
  ///
  /// In en, this message translates to:
  /// **'Re-transcribe'**
  String get retranscribe;

  /// Button to delete an entry
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Bold empty-state title on home when the journal has no entries
  ///
  /// In en, this message translates to:
  /// **'Speak, and it\'s written down.'**
  String get homeEmptyHeadline;

  /// Soft subtitle under the empty-state title, explaining the app and how to start
  ///
  /// In en, this message translates to:
  /// **'Everything you say is transcribed and kept on this device. Pull down to record your first entry.'**
  String get homeEmptySubtitle;

  /// Label beside the waveform hint while pulling the home list down to open the recorder
  ///
  /// In en, this message translates to:
  /// **'Pull to record'**
  String get homePullToRecord;

  /// Accessibility label for the settings button on the home bar
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// Accessibility label for the search button on the home bar
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get navSearch;

  /// State line under the recorder's timer while the microphone is open
  ///
  /// In en, this message translates to:
  /// **'Recording'**
  String get recordStateRecording;

  /// State line under the recorder's timer while the take is suspended
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get recordStatePaused;

  /// Generic body of the recording error dialog
  ///
  /// In en, this message translates to:
  /// **'Something went wrong while recording.'**
  String get recordErrorMessage;

  /// Title of the in-screen state when mic permission is denied
  ///
  /// In en, this message translates to:
  /// **'Microphone is off'**
  String get recordPermissionTitle;

  /// Body of the mic permission state
  ///
  /// In en, this message translates to:
  /// **'Allow microphone access for opentranscribe in the Settings app, then try again.'**
  String get recordPermissionMessage;

  /// Action that renames an entry
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// Button that transcribes an untranscribed entry
  ///
  /// In en, this message translates to:
  /// **'Transcribe'**
  String get transcribe;

  /// Quiet notice when audio playback fails
  ///
  /// In en, this message translates to:
  /// **'Playback isn\'t available right now.'**
  String get playbackFailed;

  /// Section label of the transcription settings group
  ///
  /// In en, this message translates to:
  /// **'Transcription'**
  String get settingsTranscription;

  /// Action that downloads the transcription model
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get settingsModelDownload;

  /// Value shown when the model is downloaded
  ///
  /// In en, this message translates to:
  /// **'Installed'**
  String get settingsModelInstalled;

  /// Value shown when a model download failed
  ///
  /// In en, this message translates to:
  /// **'Download failed. Tap to retry.'**
  String get settingsModelFailed;

  /// Section label of the storage settings group
  ///
  /// In en, this message translates to:
  /// **'Storage'**
  String get settingsStorage;

  /// Toggle that includes kept audio in device backups
  ///
  /// In en, this message translates to:
  /// **'Include audio in backups'**
  String get settingsBackup;

  /// Section grouping app-level settings (appearance, language)
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get settingsApp;

  /// Section label of the appearance settings group
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// Theme mode following the device appearance
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// Toggle that makes the theme follow the device appearance
  ///
  /// In en, this message translates to:
  /// **'Match system'**
  String get themeMatchSystem;

  /// Light theme mode
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// Dark theme mode
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// Row that picks the interface language
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get settingsAppLanguage;

  /// Explanation on the transcription language picker
  ///
  /// In en, this message translates to:
  /// **'The language your recordings are transcribed in. Each language uses its own on-device model.'**
  String get settingsLanguageInfo;

  /// Explanation on the app language picker
  ///
  /// In en, this message translates to:
  /// **'The language the app\'s own text is shown in. It does not change how recordings are transcribed.'**
  String get settingsAppLanguageInfo;

  /// Row and screen title for the transcription engines
  ///
  /// In en, this message translates to:
  /// **'Models'**
  String get settingsModels;

  /// Explanation on the models screen
  ///
  /// In en, this message translates to:
  /// **'opentranscribe transcribes entirely on this device. The model below runs offline; nothing you say is sent anywhere.'**
  String get settingsModelsInfo;

  /// Section label of the about group
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// Row pointing source code; tap opens link
  ///
  /// In en, this message translates to:
  /// **'Read the source code'**
  String get settingsOpenSource;

  /// Row crediting the author; tap opens link
  ///
  /// In en, this message translates to:
  /// **'Created by @theiskaa'**
  String get settingsCreatedBy;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
