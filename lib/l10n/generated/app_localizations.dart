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
  /// **'OpenTranscribe'**
  String get appTitle;

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

  /// Accessibility label for the search button on the home bar
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get navSearch;

  /// Home menu row that opens the picker for the language recordings are transcribed in
  ///
  /// In en, this message translates to:
  /// **'Transcription'**
  String get menuTranscriptionLanguage;

  /// Home menu row linking to the public source repository, followed by the app version
  ///
  /// In en, this message translates to:
  /// **'Source code'**
  String get menuSourceCode;

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

  /// Menu action and picker title for transcribing an entry in a chosen language
  ///
  /// In en, this message translates to:
  /// **'Transcribe in…'**
  String get transcribeIn;

  /// Quiet notice when audio playback fails
  ///
  /// In en, this message translates to:
  /// **'Playback isn\'t available right now.'**
  String get playbackFailed;

  /// Notice when the on-device model download fails during transcription
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get the speech model for this language. Check your connection and free space, or manage languages under Models.'**
  String get transcribeErrorModelInstall;

  /// Notice when speech recognition permission is denied
  ///
  /// In en, this message translates to:
  /// **'Allow speech recognition for opentranscribe in the Settings app, then try again.'**
  String get transcribeErrorPermission;

  /// Notice when the device cannot transcribe the chosen language on-device
  ///
  /// In en, this message translates to:
  /// **'On-device transcription isn\'t available for this language on this device.'**
  String get transcribeErrorUnavailable;

  /// Generic notice for a failed entry action (transcribe, rename)
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get transcribeErrorGeneric;

  /// Notice when transcribing needs a language slot and the per-app cap is full
  ///
  /// In en, this message translates to:
  /// **'Language limit reached. Remove a language in Settings, then try again.'**
  String get transcribeErrorCapReached;

  /// Short label on the inline error indicator when permission is denied
  ///
  /// In en, this message translates to:
  /// **'Speech recognition is off'**
  String get transcribeErrorLabelPermission;

  /// Short label on the inline error indicator when the language is unavailable on-device
  ///
  /// In en, this message translates to:
  /// **'Not available on this device'**
  String get transcribeErrorLabelUnavailable;

  /// Short label on the inline error indicator when the model download failed
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get the language model'**
  String get transcribeErrorLabelModelInstall;

  /// Short label on the inline error indicator when the language cap is full
  ///
  /// In en, this message translates to:
  /// **'Language limit reached'**
  String get transcribeErrorLabelCapReached;

  /// Short label on the inline error indicator for a generic failure
  ///
  /// In en, this message translates to:
  /// **'Transcription failed'**
  String get transcribeErrorLabelGeneric;

  /// Details-sheet title when permission is denied
  ///
  /// In en, this message translates to:
  /// **'Turn on speech recognition'**
  String get transcribeErrorTitlePermission;

  /// Details-sheet title when the language is unavailable on-device
  ///
  /// In en, this message translates to:
  /// **'Not available here'**
  String get transcribeErrorTitleUnavailable;

  /// Details-sheet title when the model download failed
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t download the model'**
  String get transcribeErrorTitleModelInstall;

  /// Details-sheet title when the language cap is full
  ///
  /// In en, this message translates to:
  /// **'Language limit reached'**
  String get transcribeErrorTitleCapReached;

  /// Details-sheet title for a generic failure
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get transcribeErrorTitleGeneric;

  /// Section label of the transcription settings group
  ///
  /// In en, this message translates to:
  /// **'Transcription'**
  String get settingsTranscription;

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

  /// Section label of the theme-family picker in appearance settings
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

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

  /// Name of the default theme family in the appearance picker
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get themeNameDefault;

  /// Name of the Gruvbox theme family (a proper noun; not translated)
  ///
  /// In en, this message translates to:
  /// **'Gruvbox'**
  String get themeNameGruvbox;

  /// Name of the Solarized theme family (a proper noun; not translated)
  ///
  /// In en, this message translates to:
  /// **'Solarized'**
  String get themeNameSolarized;

  /// Name of the Sepia theme family (a warm reading mode)
  ///
  /// In en, this message translates to:
  /// **'Sepia'**
  String get themeNameSepia;

  /// Home menu row that picks the interface (UI) language
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsAppLanguage;

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

  /// Header of the transcription screen: the on-device and shared-asset promise
  ///
  /// In en, this message translates to:
  /// **'Each language runs its own on-device model, downloaded once and shared with the system; models don\'t count against this app\'s storage. iOS limits how many languages an app can keep ready at once.'**
  String get transcriptionInfo;

  /// Engine-card line showing used vs available reservation slots (the per-device cap, unrelated to list length)
  ///
  /// In en, this message translates to:
  /// **'{used} of {max} language slots used'**
  String transcriptionCap(int used, int max);

  /// Footer hint for the swipe-to-remove gesture
  ///
  /// In en, this message translates to:
  /// **'Swipe left on a language to remove it.'**
  String get transcriptionRemoveHint;

  /// Row failure line when the platform has no asset to serve
  ///
  /// In en, this message translates to:
  /// **'This language can\'t be downloaded on this device yet.'**
  String get transcriptionErrorUnsupported;

  /// Row failure line when the asset was already stuck downloading
  ///
  /// In en, this message translates to:
  /// **'A previous download is still pending. iOS retries when conditions improve; trying again is safe.'**
  String get transcriptionErrorStuck;

  /// Row failure line for an ordinary download failure
  ///
  /// In en, this message translates to:
  /// **'Download failed. Check your connection and free space, then try again.'**
  String get transcriptionErrorGeneric;

  /// Row failure line when the per-app language cap is full
  ///
  /// In en, this message translates to:
  /// **'Language limit reached. Remove a language to add this one.'**
  String get transcriptionErrorCap;

  /// Row failure line when the platform refused to release a language
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t remove this language. Try again.'**
  String get transcriptionErrorRemove;

  /// Row sub-line prefix while a language model downloads, followed by the percent
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get transcriptionDownloading;

  /// Button that retries a failed model download or removal
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// Failure sheet title when the per-app language cap blocks an install
  ///
  /// In en, this message translates to:
  /// **'Language limit reached'**
  String get modelFailCapTitle;

  /// Failure sheet body for the cap case, above the removable language list
  ///
  /// In en, this message translates to:
  /// **'iOS limits how many languages an app can keep ready at once. Remove one of these to make room for {language}.'**
  String modelFailCapBody(String language);

  /// Failure sheet title when the platform has no on-device model for the language
  ///
  /// In en, this message translates to:
  /// **'Not available yet'**
  String get modelFailUnsupportedTitle;

  /// Failure sheet body for the unsupported case
  ///
  /// In en, this message translates to:
  /// **'iOS doesn\'t offer an on-device model for {language} on this device yet. It may arrive with a future iOS update.'**
  String modelFailUnsupportedBody(String language);

  /// Failure sheet title when an earlier system download is still pending
  ///
  /// In en, this message translates to:
  /// **'Still downloading'**
  String get modelFailStuckTitle;

  /// Failure sheet body for the stuck-download case
  ///
  /// In en, this message translates to:
  /// **'A previous download for {language} is still pending. iOS retries it when conditions improve, and asking again is safe.'**
  String modelFailStuckBody(String language);

  /// Failure sheet title for an ordinary model download failure
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t download'**
  String get modelFailGenericTitle;

  /// Failure sheet body for an ordinary download failure
  ///
  /// In en, this message translates to:
  /// **'The {language} model couldn\'t be downloaded. Check your connection and free space. iOS may also be unable to provide this model right now; trying again is safe.'**
  String modelFailGenericBody(String language);

  /// Failure sheet title when the platform refused to release a language
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t remove'**
  String get modelFailRemoveTitle;

  /// Failure sheet body for a refused removal
  ///
  /// In en, this message translates to:
  /// **'iOS didn\'t release {language}. Trying again is safe.'**
  String modelFailRemoveBody(String language);

  /// Settings row leading to the models screen (per-language on-device models)
  ///
  /// In en, this message translates to:
  /// **'Models'**
  String get settingsModels;

  /// Section label over the per-language model list on the models screen
  ///
  /// In en, this message translates to:
  /// **'Languages'**
  String get transcriptionLanguages;

  /// Small tag on the language row currently set as the transcription default
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get transcriptionDefaultTag;

  /// Footer hint for the hold-to-set-default gesture on the models screen
  ///
  /// In en, this message translates to:
  /// **'Touch and hold a language to make it the default.'**
  String get transcriptionDefaultHint;

  /// Explanatory body on the first onboarding step
  ///
  /// In en, this message translates to:
  /// **'You speak your mind, and it writes it down.'**
  String get onboardingIntroBody;

  /// Link on the intro step that opens the open-source repository
  ///
  /// In en, this message translates to:
  /// **'View source'**
  String get onboardingSource;

  /// Headline on the permissions onboarding step
  ///
  /// In en, this message translates to:
  /// **'Allow access'**
  String get onboardingPermissionsTitle;

  /// Subtitle reassuring that the requested permissions stay on-device
  ///
  /// In en, this message translates to:
  /// **'Both work entirely on your device.'**
  String get onboardingPermissionsBody;

  /// Name of the microphone permission row
  ///
  /// In en, this message translates to:
  /// **'Microphone'**
  String get onboardingMicName;

  /// One-line reason the app needs the microphone
  ///
  /// In en, this message translates to:
  /// **'To record your voice.'**
  String get onboardingMicReason;

  /// Name of the speech-recognition permission row
  ///
  /// In en, this message translates to:
  /// **'Speech recognition'**
  String get onboardingSpeechName;

  /// One-line reason the app needs speech recognition
  ///
  /// In en, this message translates to:
  /// **'To turn your recordings into text, on device.'**
  String get onboardingSpeechReason;

  /// Button that requests a permission
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get onboardingAllow;

  /// Shown when a permission was denied; opens the system Settings
  ///
  /// In en, this message translates to:
  /// **'Enable in Settings'**
  String get onboardingOpenSettings;

  /// Headline on the model-download onboarding step
  ///
  /// In en, this message translates to:
  /// **'Download a language'**
  String get onboardingModelsTitle;

  /// Body on the model-download onboarding step
  ///
  /// In en, this message translates to:
  /// **'Transcription runs offline once a language is on your device. You can add more later in Settings.'**
  String get onboardingModelsBody;

  /// Button advancing to the next onboarding step
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// Button finishing onboarding and entering the app
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get onboardingStart;
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
