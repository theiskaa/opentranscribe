// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'OpenTranscribe';

  @override
  String get settingsOffline =>
      'Alles bleibt auf diesem Gerät. Kein Konto, keine Cloud, kein Netzwerk.';

  @override
  String get entryUntranscribed => 'Nicht transkribiert';

  @override
  String get entryUntranscribedTitle => 'Noch nicht transkribiert';

  @override
  String get entryUntranscribedMessage =>
      'Machen Sie aus dieser Aufnahme Text zum Nachlesen. Alles läuft auf Ihrem Gerät.';

  @override
  String get entryNoSpeechTitle => 'Nichts zum Anzeigen';

  @override
  String get entryNoSpeechMessage =>
      'Diese Aufnahme wurde transkribiert, doch es wurde keine Sprache darin gefunden.';

  @override
  String get retranscribe => 'Erneut transkribieren';

  @override
  String get delete => 'Löschen';

  @override
  String get homeEmptyHeadline => 'Sprechen Sie, und es wird notiert.';

  @override
  String get homeEmptySubtitle =>
      'Alles, was Sie sagen, wird transkribiert und auf diesem Gerät behalten. Ziehen Sie nach unten, um Ihren ersten Eintrag aufzunehmen.';

  @override
  String get homePullToRecord => 'Zum Aufnehmen ziehen';

  @override
  String get menuTranscriptionLanguage => 'Transkription';

  @override
  String get menuSourceCode => 'Quellcode';

  @override
  String get recordStateRecording => 'Nimmt auf';

  @override
  String get recordStatePaused => 'Pausiert';

  @override
  String get recordErrorMessage => 'Bei der Aufnahme ist etwas schiefgelaufen.';

  @override
  String get recordLiveUnavailable =>
      'Live-Text ist gerade nicht verfügbar. Ihre Aufnahme ist sicher und wird transkribiert, sobald Sie fertig sind.';

  @override
  String get recordInterruptedSaved =>
      'Aufnahme unterbrochen. Ihre Aufnahme wurde gespeichert und kann aus Ihrem Journal transkribiert werden.';

  @override
  String get recordPermissionTitle => 'Mikrofon ist aus';

  @override
  String get recordPermissionMessage =>
      'Erlauben Sie den Mikrofonzugriff für opentranscribe in der App „Einstellungen“ und versuchen Sie es erneut.';

  @override
  String get rename => 'Umbenennen';

  @override
  String get transcribe => 'Transkribieren';

  @override
  String get transcribeIn => 'Transkribieren in…';

  @override
  String get playbackFailed => 'Wiedergabe ist gerade nicht verfügbar.';

  @override
  String get transcribeErrorModelInstall =>
      'Das Sprachmodell für diese Sprache konnte nicht geladen werden. Prüfen Sie Ihre Verbindung und den freien Speicher, oder verwalten Sie Sprachen unter Modelle.';

  @override
  String get transcribeErrorPermission =>
      'Erlauben Sie die Spracherkennung für opentranscribe in der App „Einstellungen“ und versuchen Sie es erneut.';

  @override
  String get transcribeErrorUnavailable =>
      'Die Transkription auf dem Gerät ist für diese Sprache auf diesem Gerät nicht verfügbar.';

  @override
  String get transcribeErrorGeneric => 'Etwas ist schiefgelaufen. Versuchen Sie es erneut.';

  @override
  String get transcribeErrorCapReached =>
      'Sprachlimit erreicht. Entfernen Sie eine Sprache in den Einstellungen und versuchen Sie es erneut.';

  @override
  String get transcribeErrorLabelPermission => 'Spracherkennung ist aus';

  @override
  String get transcribeErrorLabelUnavailable => 'Auf diesem Gerät nicht verfügbar';

  @override
  String get transcribeErrorLabelModelInstall => 'Sprachmodell nicht ladbar';

  @override
  String get transcribeErrorLabelCapReached => 'Sprachlimit erreicht';

  @override
  String get transcribeErrorLabelGeneric => 'Transkription fehlgeschlagen';

  @override
  String get transcribeErrorTitlePermission => 'Spracherkennung aktivieren';

  @override
  String get transcribeErrorTitleUnavailable => 'Hier nicht verfügbar';

  @override
  String get transcribeErrorTitleModelInstall => 'Modell konnte nicht geladen werden';

  @override
  String get transcribeErrorTitleCapReached => 'Sprachlimit erreicht';

  @override
  String get transcribeErrorTitleGeneric => 'Etwas ist schiefgelaufen';

  @override
  String get settingsAppearance => 'Darstellung';

  @override
  String get settingsTheme => 'Design';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Hell';

  @override
  String get themeDark => 'Dunkel';

  @override
  String get themeNameDefault => 'Standard';

  @override
  String get themeNameGruvbox => 'Gruvbox';

  @override
  String get themeNameSolarized => 'Solarized';

  @override
  String get themeNameSepia => 'Sepia';

  @override
  String get settingsAppLanguage => 'Sprache';

  @override
  String get transcriptionInfo =>
      'Jede Sprache nutzt ihr eigenes Modell auf dem Gerät, das einmal geladen und mit dem System geteilt wird; Modelle zählen nicht zum Speicher dieser App. Das System begrenzt, wie viele Sprachen eine App gleichzeitig bereithalten kann.';

  @override
  String transcriptionCap(int used, int max) {
    return '$used von $max Sprachplätzen belegt';
  }

  @override
  String get transcriptionRemoveHint => 'Wischen Sie eine Sprache nach links, um sie zu entfernen.';

  @override
  String get transcriptionErrorUnsupported =>
      'Diese Sprache kann auf diesem Gerät noch nicht geladen werden.';

  @override
  String get transcriptionErrorStuck =>
      'Ein früherer Download steht noch aus. Das System wiederholt ihn, wenn sich die Bedingungen bessern; ein erneuter Versuch ist unbedenklich.';

  @override
  String get transcriptionErrorGeneric =>
      'Download fehlgeschlagen. Prüfen Sie Ihre Verbindung und den freien Speicher und versuchen Sie es erneut.';

  @override
  String get transcriptionErrorCap =>
      'Sprachlimit erreicht. Entfernen Sie eine Sprache, um diese hinzuzufügen.';

  @override
  String get transcriptionErrorRemove =>
      'Diese Sprache konnte nicht entfernt werden. Versuchen Sie es erneut.';

  @override
  String get transcriptionDownloading => 'Wird geladen';

  @override
  String get retry => 'Erneut versuchen';

  @override
  String get modelFailCapTitle => 'Sprachlimit erreicht';

  @override
  String modelFailCapBody(String language) {
    return 'Das System begrenzt, wie viele Sprachen eine App gleichzeitig bereithalten kann. Entfernen Sie eine davon, um Platz für $language zu schaffen.';
  }

  @override
  String get modelFailUnsupportedTitle => 'Noch nicht verfügbar';

  @override
  String modelFailUnsupportedBody(String language) {
    return 'Für $language gibt es auf diesem Gerät noch kein Modell. Es kommt vielleicht mit einem Systemupdate.';
  }

  @override
  String get modelFailStuckTitle => 'Wird noch geladen';

  @override
  String modelFailStuckBody(String language) {
    return 'Ein früherer Download für $language steht noch aus. Das System wiederholt ihn, wenn sich die Bedingungen bessern, und ein erneuter Versuch ist unbedenklich.';
  }

  @override
  String get modelFailGenericTitle => 'Download nicht möglich';

  @override
  String modelFailGenericBody(String language) {
    return 'Das Modell für $language konnte nicht geladen werden. Prüfen Sie Ihre Verbindung und den freien Speicher und versuchen Sie es erneut.';
  }

  @override
  String get modelFailRemoveTitle => 'Entfernen nicht möglich';

  @override
  String modelFailRemoveBody(String language) {
    return 'Das System hat $language nicht freigegeben. Ein erneuter Versuch ist unbedenklich.';
  }

  @override
  String get settingsModels => 'Modelle';

  @override
  String get transcriptionLanguages => 'Sprachen';

  @override
  String get transcriptionDefaultTag => 'Standard';

  @override
  String get transcriptionDefaultHint =>
      'Halten Sie eine Sprache gedrückt, um sie zum Standard zu machen.';

  @override
  String transcriptionDeviceLanguageFallback(String fallback) {
    return 'Die Sprache Ihres Telefons wird für die Transkription auf dem Gerät noch nicht unterstützt, daher ist $fallback der Standard.';
  }

  @override
  String get onboardingIntroBody => 'Sie sagen, was Sie denken, und es wird notiert.';

  @override
  String get onboardingSpeakTitle => 'Einfach sprechen';

  @override
  String get onboardingSpeakLine =>
      'Tippen Sie auf Aufnehmen und sagen Sie, was Ihnen durch den Kopf geht.';

  @override
  String get onboardingWriteTitle => 'Nachlesen';

  @override
  String get onboardingWriteLine => 'Jede Aufnahme wird als Text notiert.';

  @override
  String get onboardingPrivateTitle => 'Nichts verlässt das Telefon';

  @override
  String get onboardingPrivateLine => 'Kein Konto, keine Cloud. Der Flugmodus ändert nichts.';

  @override
  String get onboardingSource => 'Open Source';

  @override
  String get onboardingSourceLine => 'Jede Zeile davon ist öffentlich. Lesen Sie sie auf GitHub.';

  @override
  String get onboardingPermissionsTitle => 'Zugriff erlauben';

  @override
  String get onboardingPermissionsBody => 'Beides läuft vollständig auf Ihrem Gerät.';

  @override
  String get onboardingMicName => 'Mikrofon';

  @override
  String get onboardingMicReason => 'Um Ihre Stimme aufzunehmen.';

  @override
  String get onboardingSpeechName => 'Spracherkennung';

  @override
  String get onboardingSpeechReason => 'Um Ihre Aufnahmen auf dem Gerät in Text umzuwandeln.';

  @override
  String get onboardingAllow => 'Erlauben';

  @override
  String get onboardingOpenSettings => 'In Einstellungen aktivieren';

  @override
  String get onboardingModelsTitle => 'Sprache herunterladen';

  @override
  String get onboardingModelsBody =>
      'Die Transkription läuft offline, sobald eine Sprache auf Ihrem Gerät ist. Weitere können Sie jederzeit über das Menü hinzufügen.';

  @override
  String get onboardingNext => 'Weiter';

  @override
  String get onboardingStart => 'Los geht’s';
}
