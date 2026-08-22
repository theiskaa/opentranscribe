import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_zh.dart';

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
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('fr'),
    Locale('it'),
    Locale('ja'),
    Locale('ko'),
    Locale('pt'),
    Locale('zh'),
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'OpenTranscribe'**
  String get appTitle;

  /// Title of the screen shown when startup failed before the app was ready to open
  ///
  /// In en, this message translates to:
  /// **'Could not start'**
  String get launchFailedTitle;

  /// What the user can do about a failed startup. 'App switcher' is the iOS App Switcher; use Apple's official term for it in this locale
  ///
  /// In en, this message translates to:
  /// **'Something the app needs at launch did not load. Close the app from the app switcher and open it again; if that does not help, restart the phone.'**
  String get launchFailedBody;

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

  /// Calm notice under the live transcript when live transcription fails mid-recording; the batch pass still transcribes the entry
  ///
  /// In en, this message translates to:
  /// **'Live text isn\'t available right now. Your recording is safe and will be transcribed when you finish.'**
  String get recordLiveUnavailable;

  /// Notice on the recorder screen after a call or route change ended the recording; the take was auto-saved as an untranscribed entry
  ///
  /// In en, this message translates to:
  /// **'Recording interrupted. Your take was saved and can be transcribed from your journal.'**
  String get recordInterruptedSaved;

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

  /// Action that opens the transcript for hand editing
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editTranscript;

  /// Metadata line marker on an entry not reading as its transcript, and the origin label of a hand revision
  ///
  /// In en, this message translates to:
  /// **'Edited'**
  String get editedMarker;

  /// Action that opens the entry's revision history
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get revisionHistory;

  /// Body of the revision history sheet
  ///
  /// In en, this message translates to:
  /// **'Everything this entry\'s text has been through. Tapping a version restores it as the newest.'**
  String get revisionHistoryBody;

  /// Tag on the revision the entry currently reads as
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get revisionCurrent;

  /// Origin label of a revision an engine produced
  ///
  /// In en, this message translates to:
  /// **'Transcribed'**
  String get revisionTranscribed;

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

  /// Header of the transcription screen: the on-device and shared-asset promise
  ///
  /// In en, this message translates to:
  /// **'Each language runs its own on-device model, downloaded once and shared with the system; models don\'t count against this app\'s storage. The system limits how many languages an app can keep ready at once.'**
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
  /// **'A previous download is still pending. The system retries when conditions improve; trying again is safe.'**
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
  /// **'The system limits how many languages an app can keep ready at once. Remove one of these to make room for {language}.'**
  String modelFailCapBody(String language);

  /// Failure sheet title when the platform has no on-device model for the language
  ///
  /// In en, this message translates to:
  /// **'Not available yet'**
  String get modelFailUnsupportedTitle;

  /// Failure sheet body for the unsupported case
  ///
  /// In en, this message translates to:
  /// **'There\'s no on-device model for {language} on this device yet. It may arrive with a system update.'**
  String modelFailUnsupportedBody(String language);

  /// Failure sheet title when an earlier system download is still pending
  ///
  /// In en, this message translates to:
  /// **'Still downloading'**
  String get modelFailStuckTitle;

  /// Failure sheet body for the stuck-download case
  ///
  /// In en, this message translates to:
  /// **'A previous download for {language} is still pending. The system retries it when conditions improve, and asking again is safe.'**
  String modelFailStuckBody(String language);

  /// Failure sheet title for an ordinary model download failure
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t download'**
  String get modelFailGenericTitle;

  /// Failure sheet body for an ordinary download failure
  ///
  /// In en, this message translates to:
  /// **'The {language} model couldn\'t be downloaded. Check your connection and free space, then try again.'**
  String modelFailGenericBody(String language);

  /// Failure sheet title when the platform refused to release a language
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t remove'**
  String get modelFailRemoveTitle;

  /// Failure sheet body for a refused removal
  ///
  /// In en, this message translates to:
  /// **'The system didn\'t release {language}. Trying again is safe.'**
  String modelFailRemoveBody(String language);

  /// Settings row leading to the models screen (per-language on-device models)
  ///
  /// In en, this message translates to:
  /// **'Transcription'**
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

  /// Footer notice when the phone's language has no on-device model in any variant
  ///
  /// In en, this message translates to:
  /// **'Your phone\'s language isn\'t supported for on-device transcription yet, so {fallback} is the default.'**
  String transcriptionDeviceLanguageFallback(String fallback);

  /// Explanatory body on the first onboarding step
  ///
  /// In en, this message translates to:
  /// **'You speak your mind, and it writes it down.'**
  String get onboardingIntroBody;

  /// Title of the intro row about recording
  ///
  /// In en, this message translates to:
  /// **'Just talk'**
  String get onboardingSpeakTitle;

  /// One-line explanation under the recording intro row
  ///
  /// In en, this message translates to:
  /// **'Tap record and say what is on your mind.'**
  String get onboardingSpeakLine;

  /// Title of the intro row about transcription
  ///
  /// In en, this message translates to:
  /// **'Read it back'**
  String get onboardingWriteTitle;

  /// One-line explanation under the transcription intro row
  ///
  /// In en, this message translates to:
  /// **'Every recording is written down as text.'**
  String get onboardingWriteLine;

  /// Title of the intro row about privacy
  ///
  /// In en, this message translates to:
  /// **'Nothing leaves the phone'**
  String get onboardingPrivateTitle;

  /// One-line explanation under the privacy intro row
  ///
  /// In en, this message translates to:
  /// **'No account, no cloud. Airplane mode changes nothing.'**
  String get onboardingPrivateLine;

  /// Title of the intro row about reflections, eligible hardware only
  ///
  /// In en, this message translates to:
  /// **'Reflections'**
  String get onboardingReflectTitle;

  /// One-line explanation under the reflections intro row
  ///
  /// In en, this message translates to:
  /// **'Your entries read back as a short note, all on device.'**
  String get onboardingReflectLine;

  /// Title of the intro row that opens the open-source repository
  ///
  /// In en, this message translates to:
  /// **'Open source'**
  String get onboardingSource;

  /// One-line explanation under the open-source intro row
  ///
  /// In en, this message translates to:
  /// **'Every line of it is public. Read it on GitHub.'**
  String get onboardingSourceLine;

  /// Headline on the permissions onboarding step
  ///
  /// In en, this message translates to:
  /// **'Allow access'**
  String get onboardingPermissionsTitle;

  /// Subtitle reassuring that the requested permissions stay on-device
  ///
  /// In en, this message translates to:
  /// **'Everything here works entirely on your device.'**
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

  /// Shown when a permission was denied; opens the system Settings
  ///
  /// In en, this message translates to:
  /// **'Enable in Settings'**
  String get onboardingOpenSettings;

  /// Headline on the transcription-setup onboarding step
  ///
  /// In en, this message translates to:
  /// **'Set up transcription'**
  String get onboardingModelsTitle;

  /// Body on the transcription-setup onboarding step
  ///
  /// In en, this message translates to:
  /// **'It runs offline once your language is on the device. You can add more anytime from the menu.'**
  String get onboardingModelsBody;

  /// Onboarding model step, Apple Intelligence available: what reflections do
  ///
  /// In en, this message translates to:
  /// **'Your entries read back as a short reflection, entirely on this device.'**
  String get onboardingReflectionsOn;

  /// Onboarding model step: Apple Intelligence enabled but the model still downloading
  ///
  /// In en, this message translates to:
  /// **'Starts once Apple Intelligence finishes preparing on this device.'**
  String get onboardingReflectionsPreparing;

  /// Onboarding model step: eligible hardware with Apple Intelligence off; instructions only
  ///
  /// In en, this message translates to:
  /// **'Turn on Apple Intelligence in Settings, under Apple Intelligence and Siri, to get them.'**
  String get onboardingReflectionsOff;

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

  /// Menu row and section label of the cache screen (audio storage usage and cleanup)
  ///
  /// In en, this message translates to:
  /// **'Cache'**
  String get settingsCache;

  /// Storage card subline: how many entries keep audio
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {1 recording} other {{count} recordings}}'**
  String cacheRecordingsCount(int count);

  /// Storage card row: audio held by already-transcribed entries, freeable via the clear action
  ///
  /// In en, this message translates to:
  /// **'Reclaimable'**
  String get cacheReclaimable;

  /// Subline under the reclaimable row saying why this share is safe to delete
  ///
  /// In en, this message translates to:
  /// **'Transcribed, safe to clear'**
  String get cacheReclaimableInfo;

  /// Help paragraph under the usage card
  ///
  /// In en, this message translates to:
  /// **'Audio of transcribed entries can be cleared; their text stays. Recordings not transcribed yet are never touched.'**
  String get cacheUsageInfo;

  /// Toggle row label: whether recordings survive a successful transcription
  ///
  /// In en, this message translates to:
  /// **'Keep audio'**
  String get cacheKeepAudio;

  /// Help paragraph under the keep-audio toggle stating the consequence
  ///
  /// In en, this message translates to:
  /// **'When off, each recording is deleted once its transcription succeeds. Such entries are text only: no playback, and no re-transcription by a better engine later.'**
  String get cacheKeepAudioInfo;

  /// Destructive action row that opens the clear confirmation sheet
  ///
  /// In en, this message translates to:
  /// **'Clear transcribed audio'**
  String get cacheClear;

  /// Title of the clear confirmation sheet
  ///
  /// In en, this message translates to:
  /// **'Clear transcribed audio?'**
  String get cacheClearTitle;

  /// Body of the clear confirmation sheet naming exactly what goes
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {Deletes the audio of one transcribed entry ({size}). Its text stays. This cannot be undone.} other {Deletes the audio of {count} transcribed entries ({size}). Their text stays. This cannot be undone.}}'**
  String cacheClearBody(int count, String size);

  /// Destructive confirm button on the clear sheet
  ///
  /// In en, this message translates to:
  /// **'Delete recordings'**
  String get cacheClearConfirm;

  /// Title of the reflections screen and its home-menu row
  ///
  /// In en, this message translates to:
  /// **'Reflections'**
  String get reflectionsTitle;

  /// Menu submenu holding the per-period on/off toggles
  ///
  /// In en, this message translates to:
  /// **'Periods'**
  String get reflectionPeriods;

  /// Menu toggle label for daily reflections
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get reflectionDaily;

  /// Menu toggle label for weekly reflections
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get reflectionWeekly;

  /// Menu toggle label for monthly reflections
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get reflectionMonthly;

  /// Empty-state headline on the reflections screen before any period has been reflected
  ///
  /// In en, this message translates to:
  /// **'No reflections yet'**
  String get reflectionsEmptyTitle;

  /// Empty-state supporting line under the headline on the reflections screen
  ///
  /// In en, this message translates to:
  /// **'The first arrives once you have journaled, read back from what you recorded.'**
  String get reflectionsEmptyBody;

  /// Shown for a day the observer had nothing to say about (a stored silence)
  ///
  /// In en, this message translates to:
  /// **'A quiet day.'**
  String get reflectionQuietDay;

  /// Shown for a week the observer had nothing to say about (a stored silence)
  ///
  /// In en, this message translates to:
  /// **'A quiet week.'**
  String get reflectionQuietWeek;

  /// Shown for a month the observer had nothing to say about (a stored silence)
  ///
  /// In en, this message translates to:
  /// **'A quiet month.'**
  String get reflectionQuietMonth;

  /// Pager state title: a closed, journaled period not yet written; the next catch-up may fill it
  ///
  /// In en, this message translates to:
  /// **'Not written yet'**
  String get reflectionWaitingTitle;

  /// Pager state body under the not-written-yet title
  ///
  /// In en, this message translates to:
  /// **'This will be read back the next time the journal opens with Apple Intelligence ready.'**
  String get reflectionWaitingBody;

  /// Pager state title: the user deleted this reflection
  ///
  /// In en, this message translates to:
  /// **'Erased'**
  String get reflectionErasedTitle;

  /// Pager state body under the erased title; Regenerate re-writes the reflection
  ///
  /// In en, this message translates to:
  /// **'You removed this reflection. Regenerate writes it again.'**
  String get reflectionErasedBody;

  /// Pager subline under the quiet marker
  ///
  /// In en, this message translates to:
  /// **'Nothing rose to a reflection.'**
  String get reflectionQuietBody;

  /// Detail meta: the day the reflection was generated; date is preformatted
  ///
  /// In en, this message translates to:
  /// **'Written {date}'**
  String reflectionWrittenOn(String date);

  /// Home card header naming the period a reflection covers; range is a preformatted date span
  ///
  /// In en, this message translates to:
  /// **'Reflection of {range}'**
  String reflectionOfPeriod(String range);

  /// Settings submenu: the reflection voice
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get reflectionVoice;

  /// Voice option: reads the period back as a short reflective note
  ///
  /// In en, this message translates to:
  /// **'Literary'**
  String get reflectionVoiceLiterary;

  /// Voice option: reports the shape of the period plainly
  ///
  /// In en, this message translates to:
  /// **'Observational'**
  String get reflectionVoiceObservational;

  /// Voice option: nearly a log, minimal interpretation
  ///
  /// In en, this message translates to:
  /// **'Sparse'**
  String get reflectionVoiceSparse;

  /// Settings submenu: how long a reflection may run
  ///
  /// In en, this message translates to:
  /// **'Length'**
  String get reflectionLength;

  /// Length option: a single sentence
  ///
  /// In en, this message translates to:
  /// **'One line'**
  String get reflectionLengthOneLine;

  /// Length option: up to three sentences
  ///
  /// In en, this message translates to:
  /// **'A few sentences'**
  String get reflectionLengthSentences;

  /// Length option: up to a short paragraph
  ///
  /// In en, this message translates to:
  /// **'Short paragraph'**
  String get reflectionLengthParagraph;

  /// Settings submenu: whether reflections name people, projects, places
  ///
  /// In en, this message translates to:
  /// **'Specifics'**
  String get reflectionSpecifics;

  /// Specifics option: may name the people, projects, and places heard
  ///
  /// In en, this message translates to:
  /// **'Name specifics'**
  String get reflectionSpecificsNameFreely;

  /// Specifics option: themes only, no proper nouns
  ///
  /// In en, this message translates to:
  /// **'Themes only'**
  String get reflectionSpecificsThemes;

  /// Specifics option: name a specific only when clearly central
  ///
  /// In en, this message translates to:
  /// **'Let it decide'**
  String get reflectionSpecificsLetPeriod;

  /// Menu action: reflect on the whole journal's backlog of past periods that have recordings but no reflection yet
  ///
  /// In en, this message translates to:
  /// **'Generate reflections'**
  String get reflectionGenerateAll;

  /// Per-period action: re-run this reflection in the current style
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get reflectionRegenerate;

  /// Menu action on a daily page: remove this day's reflection
  ///
  /// In en, this message translates to:
  /// **'Delete day'**
  String get reflectionDeleteDay;

  /// Menu action on a weekly page: remove this week's reflection
  ///
  /// In en, this message translates to:
  /// **'Delete week'**
  String get reflectionDeleteWeek;

  /// Menu action on a monthly page: remove this month's reflection
  ///
  /// In en, this message translates to:
  /// **'Delete month'**
  String get reflectionDeleteMonth;

  /// Notice when a regenerate could not run because the model was unavailable
  ///
  /// In en, this message translates to:
  /// **'Could not reflect. Try again.'**
  String get reflectionRegenerateFailed;

  /// Notice card on the pager when the user has disabled reflections
  ///
  /// In en, this message translates to:
  /// **'Reflections are off'**
  String get reflectionsDisabledTitle;

  /// Body of the disabled notice; the card's button reenables
  ///
  /// In en, this message translates to:
  /// **'Nothing new will be written while reflections are off.'**
  String get reflectionsDisabledBody;

  /// The disabled notice card's button: reenables reflections in place
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get reflectionsDisabledEnable;

  /// Reflections screen state: Apple Intelligence is available but not enabled
  ///
  /// In en, this message translates to:
  /// **'Apple Intelligence is off'**
  String get reflectionOffTitle;

  /// Guidance when Apple Intelligence is off; there is no deep-link to the exact pane
  ///
  /// In en, this message translates to:
  /// **'Turn it on in Settings, under Apple Intelligence and Siri, to get reflections.'**
  String get reflectionOffBody;

  /// Reflections screen state: Apple Intelligence is enabled but the model is still downloading
  ///
  /// In en, this message translates to:
  /// **'Getting ready'**
  String get reflectionPreparingTitle;

  /// Body for the preparing/model-not-ready state
  ///
  /// In en, this message translates to:
  /// **'Apple Intelligence is preparing on this device. Reflections start once it finishes.'**
  String get reflectionPreparingBody;

  /// Reflections screen state: this device cannot run Apple Intelligence at all
  ///
  /// In en, this message translates to:
  /// **'Not available here'**
  String get reflectionUnsupportedTitle;

  /// Body for the unsupported-device / older-iOS state
  ///
  /// In en, this message translates to:
  /// **'This device does not support Apple Intelligence, which reflections need.'**
  String get reflectionUnsupportedBody;

  /// Home menu row and heading for the notifications settings screen
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// Master toggle label: all reflection notifications on or off
  ///
  /// In en, this message translates to:
  /// **'Reflection reminders'**
  String get notifyReflectionReminders;

  /// Capsule label: nudge for daily reflections
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get notifyPeriodDay;

  /// Capsule label: nudge for weekly reflections
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get notifyPeriodWeek;

  /// Capsule label: nudge for monthly reflections
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get notifyPeriodMonth;

  /// Footnote under the reflection reminders card
  ///
  /// In en, this message translates to:
  /// **'A nudge when a new reflection is ready to read. It fires on your device; nothing is sent anywhere.'**
  String get notifyReflectionsInfo;

  /// Row label for the shared time every enabled nudge fires at
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get notifyTime;

  /// Shown when notification permission was denied; the row deep-links to iOS Settings
  ///
  /// In en, this message translates to:
  /// **'Notifications are turned off in Settings.'**
  String get notifyPermissionDenied;

  /// Action to open this app's page in iOS Settings to grant notification permission
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get notifyOpenSettings;

  /// Title of the daily local notification; generic, never reflection text
  ///
  /// In en, this message translates to:
  /// **'Your day is ready'**
  String get notifyDailyTitle;

  /// Body of the daily local notification; at fire time the reflection covers yesterday. Generic, never reflection text
  ///
  /// In en, this message translates to:
  /// **'Open to read yesterday\'s reflection.'**
  String get notifyDailyBody;

  /// Title of the weekly local notification; generic, never reflection text
  ///
  /// In en, this message translates to:
  /// **'Your week is ready'**
  String get notifyWeeklyTitle;

  /// Body of the weekly local notification; generic, never reflection text
  ///
  /// In en, this message translates to:
  /// **'Open to read last week\'s reflection.'**
  String get notifyWeeklyBody;

  /// Title of the monthly local notification; generic, never reflection text
  ///
  /// In en, this message translates to:
  /// **'Your month is ready'**
  String get notifyMonthlyTitle;

  /// Body of the monthly local notification; fires on the 1st, about the closed month. Generic, never reflection text
  ///
  /// In en, this message translates to:
  /// **'Open to read last month\'s reflection.'**
  String get notifyMonthlyBody;

  /// Footer on the notifications screen when reflections are switched off; precedes the turn-on link
  ///
  /// In en, this message translates to:
  /// **'Nudges arrive when a new reflection is ready to read. Reflections are off right now.'**
  String get notifyNeedsReflections;

  /// Bold inline link after notifyNeedsReflections; opens the reflections screen where reflections are enabled
  ///
  /// In en, this message translates to:
  /// **'Turn on reflections'**
  String get notifyTurnOnReflections;

  /// Footer on the notifications screen when the on-device model cannot produce reflections; informational, no action
  ///
  /// In en, this message translates to:
  /// **'This device can\'t generate reflections, so there\'s no nudge to send.'**
  String get notifyReflectionsUnavailable;

  /// Footer under the theme grid on the appearance screen; precedes the request-a-theme link
  ///
  /// In en, this message translates to:
  /// **'Want OpenTranscribe in a theme that isn\'t here? Open an issue on GitHub and we\'ll add it in an upcoming release.'**
  String get themeRequestInfo;

  /// Bold inline link after themeRequestInfo; opens a new GitHub issue in the browser
  ///
  /// In en, this message translates to:
  /// **'Request a theme on GitHub'**
  String get themeRequestLink;

  /// Menu row and button label for exporting one entry
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get exportEntry;

  /// Entry export sheet title
  ///
  /// In en, this message translates to:
  /// **'Export entry'**
  String get exportEntryTitle;

  /// Toggle for bundling the recording with an export
  ///
  /// In en, this message translates to:
  /// **'Include audio'**
  String get exportIncludeAudio;

  /// Name of the Markdown export format. A format is named by its makers: keep it verbatim
  ///
  /// In en, this message translates to:
  /// **'Markdown'**
  String get exportFormatMarkdown;

  /// One line under the Markdown format row saying what it writes
  ///
  /// In en, this message translates to:
  /// **'One text file per entry, plus a .json.'**
  String get exportFormatMarkdownNote;

  /// Name of the Obsidian export format. A product name: keep it verbatim
  ///
  /// In en, this message translates to:
  /// **'Obsidian'**
  String get exportFormatObsidian;

  /// One line under the Obsidian format row saying what it writes
  ///
  /// In en, this message translates to:
  /// **'Notes with properties, audio embedded.'**
  String get exportFormatObsidianNote;

  /// The app's own name for the HTML export format; a plain noun, so it translates
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get exportFormatWeb;

  /// One line under the web page format row saying what it writes
  ///
  /// In en, this message translates to:
  /// **'Opens in any browser, with a player.'**
  String get exportFormatWebNote;

  /// Export failure sheet title
  ///
  /// In en, this message translates to:
  /// **'Export failed'**
  String get exportFailedTitle;

  /// Export failure explanation; nothing left the phone
  ///
  /// In en, this message translates to:
  /// **'Could not prepare the files. Nothing was shared.'**
  String get exportFailedBody;

  /// File and heading fallback for an entry with no title
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get exportUntitled;

  /// Markdown heading over the exported transcript
  ///
  /// In en, this message translates to:
  /// **'Transcript'**
  String get exportTranscriptHeading;

  /// How a silent reflection reads in an export
  ///
  /// In en, this message translates to:
  /// **'A quiet stretch.'**
  String get exportQuiet;

  /// Home menu row opening the Backup screen
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get settingsBackup;

  /// Backup screen intro: what a backup holds and what encryption does
  ///
  /// In en, this message translates to:
  /// **'A backup holds every entry with its audio and reflections. Encrypt it and your passphrase is the only key.'**
  String get backupInfo;

  /// The Backup screen intro once the entry count is measured
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0 {Nothing to back up yet. A backup holds every entry with its audio and reflections.} one {A backup holds your 1 entry with its audio and reflections. Encrypt it and your passphrase is the only key.} other {A backup holds all {count} entries with their audio and reflections. Encrypt it and your passphrase is the only key.}}'**
  String backupInfoCount(int count);

  /// Section label over the format picker and export row
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get backupExportSection;

  /// Action row exporting the whole journal in the chosen format
  ///
  /// In en, this message translates to:
  /// **'Export journal'**
  String get backupExportJournal;

  /// Help paragraph under the export card
  ///
  /// In en, this message translates to:
  /// **'Writes every entry in the chosen format, audio included, zipped for the share sheet. A copy for other apps; restoring needs a backup.'**
  String get backupExportInfo;

  /// Toggle for sealing archives with a passphrase
  ///
  /// In en, this message translates to:
  /// **'Encrypt with passphrase'**
  String get backupSeal;

  /// The Backup section row that saves a backup file
  ///
  /// In en, this message translates to:
  /// **'Save backup'**
  String get backupSave;

  /// Detail under Save backup showing when the last backup was handed off
  ///
  /// In en, this message translates to:
  /// **'Last backup {date}'**
  String backupLastBackup(String date);

  /// Sealing passphrase sheet title
  ///
  /// In en, this message translates to:
  /// **'Encrypt the backup'**
  String get passphraseCreateTitle;

  /// Sealing passphrase sheet body: the passphrase is the only key
  ///
  /// In en, this message translates to:
  /// **'The passphrase is the only key. It is not stored anywhere; without it the backup is noise.'**
  String get passphraseCreateBody;

  /// Passphrase field placeholder
  ///
  /// In en, this message translates to:
  /// **'Passphrase'**
  String get passphrasePlaceholder;

  /// Confirmation field placeholder
  ///
  /// In en, this message translates to:
  /// **'Repeat passphrase'**
  String get passphraseRepeatPlaceholder;

  /// Footnote while the passphrase is under the minimum length
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters'**
  String get passphraseTooShort;

  /// Footnote while the two passphrase fields differ
  ///
  /// In en, this message translates to:
  /// **'Passphrases do not match'**
  String get passphraseMismatch;

  /// Unlock sheet title for a sealed archive
  ///
  /// In en, this message translates to:
  /// **'Encrypted backup'**
  String get importUnlockTitle;

  /// Unlock sheet body asking for the sealing passphrase
  ///
  /// In en, this message translates to:
  /// **'Enter the passphrase this backup was encrypted with.'**
  String get importUnlockBody;

  /// Unlock sheet action button
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get importUnlock;

  /// Unlock retry error; GCM cannot tell wrong passphrase from damage
  ///
  /// In en, this message translates to:
  /// **'Could not unlock. Wrong passphrase, or a damaged file.'**
  String get importWrongPassphrase;

  /// Import confirmation sheet title
  ///
  /// In en, this message translates to:
  /// **'Restore this backup?'**
  String get importConfirmTitle;

  /// Import confirmation body: additive, nothing touched
  ///
  /// In en, this message translates to:
  /// **'Adds its entries to your journal. Restoring the same backup twice never duplicates.'**
  String get importConfirmBody;

  /// Import confirmation action button
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get importConfirm;

  /// Import summary sheet title
  ///
  /// In en, this message translates to:
  /// **'Restore complete'**
  String get importSummaryTitle;

  /// Summary line for how many entries were imported
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0 {Nothing new to restore.} one {Restored 1 entry.} other {Restored {count} entries.}}'**
  String importSummaryImported(int count);

  /// Summary line for entries already present, shown only when some were
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one {1 entry was already in the journal.} other {{count} entries were already in the journal.}}'**
  String importSummarySkipped(int count);

  /// Import failure sheet title
  ///
  /// In en, this message translates to:
  /// **'Restore failed'**
  String get importFailedTitle;

  /// Generic import failure body; journal unchanged
  ///
  /// In en, this message translates to:
  /// **'The backup could not be read. Nothing in the journal was changed.'**
  String get importFailedBody;

  /// Failure body for a file that is not an archive
  ///
  /// In en, this message translates to:
  /// **'Not an OpenTranscribe backup. Nothing in the journal was changed.'**
  String get importNotArchive;

  /// Failure body for an archive from a newer app version
  ///
  /// In en, this message translates to:
  /// **'Made by a newer version of the app. Update to import it.'**
  String get importNewerVersion;

  /// Failure body for an archive re-compressed by another tool
  ///
  /// In en, this message translates to:
  /// **'This backup was re-zipped by another tool. Save a fresh one and restore that.'**
  String get importRezipped;

  /// Generic dismiss button
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// Failure body when adoption already wrote; restored entries are kept
  ///
  /// In en, this message translates to:
  /// **'The restore stopped partway. Everything restored so far is kept; restore again to finish.'**
  String get importFailedMidway;

  /// Body of the gate sheet: what supporting unlocks, and that the backup stays free
  ///
  /// In en, this message translates to:
  /// **'Formatted exports are for club members. The backup stays free for everyone.'**
  String get supportGateBody;

  /// Home menu row opening the support screen
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get settingsSupport;

  /// Gate sheet action that opens the support screen
  ///
  /// In en, this message translates to:
  /// **'Become a club member'**
  String get supportGateAction;

  /// Support screen intro for a non-supporter
  ///
  /// In en, this message translates to:
  /// **'OpenTranscribe is free and private, and supporting it keeps it that way. Joining the club is one payment, in for good.'**
  String get supportPitch;

  /// Perk row label: the formatted exports
  ///
  /// In en, this message translates to:
  /// **'Formatted exports'**
  String get supportPerkExports;

  /// Perk row note naming the formats; one line
  ///
  /// In en, this message translates to:
  /// **'Markdown, Obsidian, or a website.'**
  String get supportPerkExportsNote;

  /// Perk row label: later club-only features are included
  ///
  /// In en, this message translates to:
  /// **'Future club features'**
  String get supportPerkFuture;

  /// Perk row note for future club features; one line
  ///
  /// In en, this message translates to:
  /// **'Whatever joins the club later, included.'**
  String get supportPerkFutureNote;

  /// Support screen intro for a club member
  ///
  /// In en, this message translates to:
  /// **'You\'re in the club for good. Thank you.'**
  String get supportThanks;

  /// Label of the pinned join button; price is the store's localized price string
  ///
  /// In en, this message translates to:
  /// **'Join the club for {price}'**
  String supportJoin(String price);

  /// Link that restores purchases via the store sync
  ///
  /// In en, this message translates to:
  /// **'Restore purchases'**
  String get supportRestore;

  /// Line shown when the price fetch failed
  ///
  /// In en, this message translates to:
  /// **'The App Store could not be reached. Reopen this screen to try again.'**
  String get supportUnreachable;

  /// Line shown after an Ask to Buy purchase answered pending
  ///
  /// In en, this message translates to:
  /// **'Waiting for approval. The purchase finishes once it is approved.'**
  String get supportPending;

  /// Sheet title when restore finds no purchase
  ///
  /// In en, this message translates to:
  /// **'Nothing to restore'**
  String get supportRestoreNoneTitle;

  /// Sheet body when restore finds no purchase
  ///
  /// In en, this message translates to:
  /// **'No club purchase is attached to this Apple ID.'**
  String get supportRestoreNoneBody;

  /// Sheet title when a purchase or restore failed
  ///
  /// In en, this message translates to:
  /// **'That did not go through'**
  String get supportFailedTitle;

  /// Sheet body when a purchase or restore failed
  ///
  /// In en, this message translates to:
  /// **'The App Store could not finish. Try again.'**
  String get supportFailedBody;

  /// Privacy policy link label
  ///
  /// In en, this message translates to:
  /// **'privacy policy'**
  String get supportPrivacy;

  /// Terms of use link label
  ///
  /// In en, this message translates to:
  /// **'terms of use'**
  String get supportTerms;

  /// Section label above the list of features supporting unlocks
  ///
  /// In en, this message translates to:
  /// **'Club members get'**
  String get supportUnlocksSection;

  /// Eyebrow under the app name on the support screen header
  ///
  /// In en, this message translates to:
  /// **'Club'**
  String get supporterTag;

  /// Footer paragraph; privacy and terms are the inline tappable link labels
  ///
  /// In en, this message translates to:
  /// **'Supporting changes nothing about privacy. The journal never leaves the phone, as the {privacy} says, and the purchase runs on Apple\'s standard {terms}.'**
  String supportFooter(String privacy, String terms);
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'fr', 'it', 'ja', 'ko', 'pt', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
    case 'it':
      return AppLocalizationsIt();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'pt':
      return AppLocalizationsPt();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
