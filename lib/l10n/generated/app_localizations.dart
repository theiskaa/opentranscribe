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
  /// **'Transcription runs offline once a language is on your device. You can add more anytime from the menu.'**
  String get onboardingModelsBody;

  /// Onboarding model step, Apple Intelligence available: what reflections do
  ///
  /// In en, this message translates to:
  /// **'Once a week, your entries read back as a short reflection, entirely on this device.'**
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

  /// Empty-state headline on the reflections screen before any week has been reflected
  ///
  /// In en, this message translates to:
  /// **'No reflections yet'**
  String get reflectionsEmptyTitle;

  /// Empty-state supporting line under the headline on the reflections screen
  ///
  /// In en, this message translates to:
  /// **'The first arrives when your week closes, read back from what you recorded.'**
  String get reflectionsEmptyBody;

  /// Shown for a week the observer had nothing to say about (a stored silence)
  ///
  /// In en, this message translates to:
  /// **'A quiet week.'**
  String get reflectionQuietWeek;

  /// Pager state title: a closed, journaled week not yet written; the next catch-up may fill it
  ///
  /// In en, this message translates to:
  /// **'Not written yet'**
  String get reflectionWaitingTitle;

  /// Pager state body under the not-written-yet title
  ///
  /// In en, this message translates to:
  /// **'This week will be read back the next time the journal opens with Apple Intelligence ready.'**
  String get reflectionWaitingBody;

  /// Pager state title: the user deleted this week's reflection
  ///
  /// In en, this message translates to:
  /// **'Erased'**
  String get reflectionErasedTitle;

  /// Pager state body under the erased title; Regenerate re-writes the week
  ///
  /// In en, this message translates to:
  /// **'You removed this week\'s reflection. Regenerate writes it again.'**
  String get reflectionErasedBody;

  /// Pager subline under the quiet-week marker
  ///
  /// In en, this message translates to:
  /// **'Nothing rose to a reflection.'**
  String get reflectionQuietBody;

  /// Detail meta: the day the reflection was generated; date is preformatted
  ///
  /// In en, this message translates to:
  /// **'Written {date}'**
  String reflectionWrittenOn(String date);

  /// Home card header naming the week a reflection covers; range is a preformatted date span
  ///
  /// In en, this message translates to:
  /// **'Reflection of {range}'**
  String reflectionOfWeek(String range);

  /// Settings submenu: the reflection voice
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get reflectionVoice;

  /// Voice option: reads the week back as a short reflective note
  ///
  /// In en, this message translates to:
  /// **'Literary'**
  String get reflectionVoiceLiterary;

  /// Voice option: reports the shape of the week plainly
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
  /// **'Let the week decide'**
  String get reflectionSpecificsLetWeek;

  /// Per-week action: re-run this week's reflection in the current style
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get reflectionRegenerate;

  /// Per-week action and its confirm button: remove this week's reflection
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get reflectionDelete;

  /// Title of the delete-reflection confirmation sheet
  ///
  /// In en, this message translates to:
  /// **'Delete this reflection?'**
  String get reflectionDeleteTitle;

  /// Body of the delete-reflection confirmation sheet
  ///
  /// In en, this message translates to:
  /// **'Removes the reflection for this week. This cannot be undone.'**
  String get reflectionDeleteBody;

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
  /// **'The open week will not be written when it closes.'**
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
  /// **'Turn it on in Settings, under Apple Intelligence and Siri, to get weekly reflections.'**
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
  /// **'This device does not support Apple Intelligence, which weekly reflections needs.'**
  String get reflectionUnsupportedBody;

  /// Home menu row and heading for the notifications settings screen
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// Toggle label: the weekly reflection notification
  ///
  /// In en, this message translates to:
  /// **'Weekly reflections'**
  String get notifyWeeklyReflection;

  /// Footnote under the weekly reflection notification toggle
  ///
  /// In en, this message translates to:
  /// **'A nudge when a new week is ready to read. It fires on your device; nothing is sent anywhere.'**
  String get notifyWeeklyReflectionInfo;

  /// Row label for the time the weekly notification fires
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

  /// Title of the weekly local notification; generic, never reflection text
  ///
  /// In en, this message translates to:
  /// **'Your week is ready'**
  String get notifyWeeklyTitle;

  /// Body of the weekly local notification; generic, never reflection text
  ///
  /// In en, this message translates to:
  /// **'Open to read this week\'s reflection.'**
  String get notifyWeeklyBody;

  /// Footer on the notifications screen when reflections are switched off; precedes the turn-on link
  ///
  /// In en, this message translates to:
  /// **'The weekly nudge arrives when a new week is ready to read. Reflections are off right now.'**
  String get notifyNeedsReflections;

  /// Bold inline link after notifyNeedsReflections; opens the reflections screen where reflections are enabled
  ///
  /// In en, this message translates to:
  /// **'Turn on reflections'**
  String get notifyTurnOnReflections;

  /// Footer on the notifications screen when the on-device model cannot produce reflections; informational, no action
  ///
  /// In en, this message translates to:
  /// **'This device can\'t generate reflections, so there\'s no weekly nudge to send.'**
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
