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
  String get launchFailedTitle => 'Start fehlgeschlagen';

  @override
  String get launchFailedBody =>
      'Etwas, das die App zum Start braucht, wurde nicht geladen. Schließen Sie die App im App-Umschalter und öffnen Sie sie erneut; hilft das nicht, starten Sie das Telefon neu.';

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
  String get retranscribeAllTitle => 'Alle erneut transkribieren';

  @override
  String get retranscribeRowQueued => 'Erneut zu transkribieren';

  @override
  String get retranscribeRowCurrent => 'Bereits aktuell';

  @override
  String get retranscribeRowLanded => 'Erneut transkribiert';

  @override
  String get retranscribeRowFailed => 'Fehlgeschlagen';

  @override
  String get retranscribeHistoryNote => 'Ersetzte Wörter bleiben im Verlauf jedes Eintrags.';

  @override
  String get retranscribeFailedNote =>
      'Fehlgeschlagene Einträge bleiben für den nächsten Durchlauf in der Warteschlange.';

  @override
  String retranscribeAllCurrentBody(String engine) {
    return 'Jede behaltene Aufnahme ist bereits mit $engine transkribiert.';
  }

  @override
  String get retranscribeStart => 'Starten';

  @override
  String retranscribeProgressOf(int done, int total) {
    return '$done von $total';
  }

  @override
  String get retranscribeWaitingRecording => 'Pausiert, bis die Aufnahme beendet ist';

  @override
  String get retranscribeWaitingThermal => 'Pausiert, während das Gerät abkühlt';

  @override
  String get retranscribeCancel => 'Abbrechen';

  @override
  String get retranscribeCancelledNote =>
      'Vorzeitig beendet. Ein neuer Durchlauf macht dort weiter.';

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
  String get editTranscript => 'Bearbeiten';

  @override
  String get editedMarker => 'Bearbeitet';

  @override
  String get revisionHistory => 'Verlauf';

  @override
  String get revisionHistoryBody =>
      'Alles, was der Text dieses Eintrags durchlaufen hat. Tippen stellt eine Version als neueste wieder her.';

  @override
  String get revisionCurrent => 'Aktuell';

  @override
  String get revisionTranscribed => 'Transkribiert';

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
  String get transcribeErrorRecordingMissing =>
      'Die Aufnahme dieses Eintrags liegt nicht mehr auf dem Gerät und kann nicht erneut transkribiert werden. Der vorhandene Text ist alles, was bleibt.';

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
  String get transcribeErrorLabelRecordingMissing => 'Aufnahme weg';

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
  String get transcribeErrorTitleRecordingMissing => 'Die Aufnahme ist weg';

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
  String get appearanceIconSection => 'App-Symbol';

  @override
  String get appIconNameSignal => 'Signal';

  @override
  String get appIconNameLines => 'Lines';

  @override
  String get appIconNameDots => 'Dots';

  @override
  String get appIconFailedTitle => 'Das Symbol wurde nicht geändert';

  @override
  String get appIconFailedBody => 'iOS hat die Änderung abgelehnt. Versuchen Sie es erneut.';

  @override
  String get settingsAppLanguage => 'Sprache';

  @override
  String transcriptionCap(int used, int max) {
    return '$used von $max Sprachplätzen belegt';
  }

  @override
  String get transcriptionErrorUnsupported =>
      'Diese Sprache kann auf diesem Gerät noch nicht geladen werden.';

  @override
  String get languageNeedsDictation =>
      'Aktivieren Sie das Diktieren für diese Sprache in den iOS-Tastatureinstellungen.';

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
  String get modelFailDictationTitle => 'Diktieren ist nicht eingerichtet';

  @override
  String modelFailDictationBody(String language) {
    return '$language wird mit dem Diktiermodell des Systems transkribiert, das auf diesem iPhone noch fehlt. Fügen Sie die Tastatur hinzu und aktivieren Sie das Diktieren in den iOS-Einstellungen.';
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
  String get settingsModels => 'Transkription';

  @override
  String get transcriptionYourLanguages => 'Ihre Sprachen';

  @override
  String get transcriptionAllLanguages => 'Alle Sprachen';

  @override
  String get transcriptionSpeaking => 'Gesprochene Sprache';

  @override
  String get transcriptionAlsoReady => 'Ebenfalls bereit';

  @override
  String get transcriptionAddLanguage => 'Hinzufügen';

  @override
  String transcriptionHeroReady(String engine) {
    return 'Bereit · $engine';
  }

  @override
  String get transcriptionFootnote => 'Modelle werden einmal geladen und mit dem System geteilt.';

  @override
  String get transcriptionEngines => 'Engines';

  @override
  String get engineBlurbSpeechAnalyzer => 'Apples neueste Engine, ein geladenes Modell pro Sprache';

  @override
  String get engineBlurbDictation => 'Die Erkennung hinter dem Diktieren der iOS-Tastatur';

  @override
  String get engineUnavailableNote => 'Auf diesem iPhone nicht verfügbar';

  @override
  String get engineUnavailableTitle => 'Auf diesem iPhone nicht verfügbar';

  @override
  String engineUnavailableBody(String engine) {
    return '$engine benötigt iOS 26 und ein neueres iPhone. Aufnahmen nutzen weiter die Engine, die hier funktioniert.';
  }

  @override
  String get engineBusyTitle => 'Aufnahme läuft';

  @override
  String get engineBusyBody =>
      'Beenden Sie die aktuelle Aufnahme und wechseln Sie dann die Engine.';

  @override
  String get engineRetranscribingTitle => 'Erneute Transkription läuft';

  @override
  String get engineRetranscribingBody =>
      'Lassen Sie den Durchlauf enden oder brechen Sie ihn ab, und wechseln Sie dann die Engine.';

  @override
  String get engineNotSavedTitle => 'Auswahl nicht gespeichert';

  @override
  String get engineNotSavedBody =>
      'Die Engine-Auswahl konnte nicht gespeichert werden und übersteht keinen Neustart.';

  @override
  String get transcriptionDefaultTag => 'Standard';

  @override
  String transcriptionDeviceLanguageFallback(String fallback) {
    return 'Die Sprache Ihres Telefons wird für die Transkription auf dem Gerät noch nicht unterstützt, daher ist $fallback der Standard.';
  }

  @override
  String get onboardingOpenSettings => 'In Einstellungen aktivieren';

  @override
  String get onboardingReflectTitle => 'Ihre Woche im Rückblick';

  @override
  String get onboardingReflectBody =>
      'Einträge lesen sich als kurzer Rückblick, nach Tag, Woche oder Monat. Geschrieben auf diesem Gerät von Apple Intelligence, nie irgendwohin gesendet.';

  @override
  String get onboardingReflectDay1 =>
      'Schlecht geschlafen, aber der Morgenlauf hat das meiste wieder in Ordnung gebracht.';

  @override
  String get onboardingReflectDay2 => 'Dana, Kaffee, zwei Stunden über nichts und alles.';

  @override
  String get onboardingReflectDay3 =>
      'Nein zum Extraprojekt gesagt. Den ganzen Tag leichter gefühlt.';

  @override
  String get onboardingReflectDay4 =>
      'Den langen Weg nach Hause gegangen. Die Stadt war ausnahmsweise still.';

  @override
  String get onboardingReflectNote =>
      'Eine Woche, in der Sie öfter Nein gesagt haben, und die langen Spaziergänge, die damit zurückkamen.';

  @override
  String get onboardingShapeTitle => 'Ihres, in jeder Form';

  @override
  String get onboardingShapeBody =>
      'Nehmen Sie das ganze Journal mit, als Markdown, als Obsidian Vault oder als Webseite. Sichern Sie es versiegelt mit einer Passphrase, die nur Sie kennen. Nichts wird synchronisiert, außer Sie tragen es selbst.';

  @override
  String get onboardingBackupLine => 'Mit Passphrase versiegelt, überall wiederherstellbar.';

  @override
  String get onboardingRecordTitle => 'Sie sprechen aus, was Sie denken, und es schreibt mit.';

  @override
  String get onboardingRecordBody =>
      'Jedes Wort bleibt auf diesem Telefon. Kein Konto, keine Cloud. Der Flugmodus ändert nichts.';

  @override
  String get onboardingRecordText1 =>
      'Mit Lia Kaffee getrunken, und am Ende haben wir zwei Stunden über den Umzug geredet.';

  @override
  String get onboardingRecordText2 =>
      'Ich sage immer, ich will ein kleineres Leben, und fülle dann jeden Abend.';

  @override
  String get onboardingRecordText3 =>
      'Den langen Weg nach Hause gegangen. Die Stadt war ausnahmsweise still.';

  @override
  String get onboardingRecordText4 =>
      'Dann habe ich eine Weile auf den Stufen gesessen und nichts getan, und genau darum ging es wohl.';

  @override
  String get onboardingRecordText5 =>
      'Die Arbeit war in Ordnung. Niemand wollte etwas, das ich nicht geben konnte.';

  @override
  String get onboardingRecordText6 => 'Morgen will ich Mama anrufen, bevor es spät wird.';

  @override
  String get onboardingPermissionsTitle => 'Zugriff erlauben';

  @override
  String get onboardingPermissionsBody =>
      'Alles hier läuft vollständig auf Ihrem Gerät. „Los geht\'s“ fragt nach Mikrofon, Spracherkennung und Erinnerungen; alles lässt sich später in den Einstellungen ändern.';

  @override
  String get onboardingMicName => 'Mikrofon';

  @override
  String get onboardingMicReason => 'Um Ihre Stimme aufzunehmen.';

  @override
  String get onboardingSpeechName => 'Spracherkennung';

  @override
  String get onboardingSpeechReason => 'Um Ihre Aufnahmen auf dem Gerät in Text umzuwandeln.';

  @override
  String onboardingReflectWeek(int number) {
    return 'Woche $number';
  }

  @override
  String get onboardingShapeObsidianName => 'Obsidian';

  @override
  String get onboardingShapeMarkdownNote => 'Je eine Datei';

  @override
  String get onboardingShapeObsidianNote => 'Verlinkt';

  @override
  String get onboardingShapeWebNote => 'Im Browser';

  @override
  String get onboardingRemindersName => 'Erinnerungen';

  @override
  String get onboardingRemindersReason => 'Ein Hinweis, wenn ein Rückblick bereit ist.';

  @override
  String get onboardingReflectionsOn => 'Apple Intelligence ist an.';

  @override
  String get onboardingReflectionsPreparing =>
      'Apple Intelligence wird auf diesem Gerät noch vorbereitet.';

  @override
  String get onboardingReflectionsOff =>
      'Schalten Sie Apple Intelligence in den Einstellungen ein, um sie zu erhalten.';

  @override
  String get onboardingNext => 'Weiter';

  @override
  String get onboardingStart => 'Los geht’s';

  @override
  String get onboardingDone => 'Fertig';

  @override
  String get hintEntryMenu =>
      'Alles, was dieser Eintrag kann, steckt im Menü hier oben: Text bearbeiten, exportieren, mehr aufnehmen.';

  @override
  String get settingsCache => 'Cache';

  @override
  String cacheRecordingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufnahmen',
      one: '1 Aufnahme',
    );
    return '$_temp0';
  }

  @override
  String get cacheReclaimable => 'Freigebbar';

  @override
  String get cacheReclaimableInfo => 'Transkribiert, kann gelöscht werden';

  @override
  String get cacheUsageInfo =>
      'Audio transkribierter Einträge kann gelöscht werden; der Text bleibt. Noch nicht transkribierte Aufnahmen werden nie angetastet.';

  @override
  String get cacheKeepAudio => 'Audio behalten';

  @override
  String get cacheKeepAudioInfo =>
      'Wenn aus, wird jede Aufnahme gelöscht, sobald ihre Transkription gelingt. Solche Einträge sind nur Text: keine Wiedergabe, keine erneute Transkription durch eine bessere Engine.';

  @override
  String get cacheClear => 'Transkribiertes Audio löschen';

  @override
  String get cacheClearTitle => 'Transkribiertes Audio löschen?';

  @override
  String cacheClearBody(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Löscht das Audio von $count transkribierten Einträgen ($size). Der Text bleibt. Das lässt sich nicht rückgängig machen.',
      one:
          'Löscht das Audio eines transkribierten Eintrags ($size). Der Text bleibt. Das lässt sich nicht rückgängig machen.',
    );
    return '$_temp0';
  }

  @override
  String get cacheClearConfirm => 'Aufnahmen löschen';

  @override
  String get reflectionsTitle => 'Rückblicke';

  @override
  String get reflectionPeriods => 'Zeiträume';

  @override
  String get reflectionDaily => 'Täglich';

  @override
  String get reflectionWeekly => 'Wöchentlich';

  @override
  String get reflectionMonthly => 'Monatlich';

  @override
  String get reflectionsEmptyTitle => 'Noch keine Rückblicke';

  @override
  String get reflectionsEmptyBody =>
      'Der erste kommt, sobald Sie etwas festgehalten haben, gelesen aus dem, was Sie aufgenommen haben.';

  @override
  String get reflectionQuietDay => 'Ein ruhiger Tag.';

  @override
  String get reflectionQuietWeek => 'Eine ruhige Woche.';

  @override
  String get reflectionQuietMonth => 'Ein ruhiger Monat.';

  @override
  String get reflectionWaitingTitle => 'Noch nicht geschrieben';

  @override
  String get reflectionWaitingBody =>
      'Dies wird beim nächsten Öffnen des Journals gelesen, sobald Apple Intelligence bereit ist.';

  @override
  String get reflectionErasedTitle => 'Gelöscht';

  @override
  String get reflectionErasedBody =>
      'Sie haben diesen Rückblick entfernt. Neu erstellen schreibt ihn erneut.';

  @override
  String get reflectionQuietBody => 'Nichts wurde zu einem Rückblick.';

  @override
  String reflectionWrittenOn(String date) {
    return 'Geschrieben am $date';
  }

  @override
  String reflectionOfPeriod(String range) {
    return 'Rückblick auf $range';
  }

  @override
  String get reflectionVoice => 'Stimme';

  @override
  String get reflectionVoiceLiterary => 'Literarisch';

  @override
  String get reflectionVoiceObservational => 'Beobachtend';

  @override
  String get reflectionVoiceSparse => 'Knapp';

  @override
  String get reflectionLength => 'Länge';

  @override
  String get reflectionLengthOneLine => 'Eine Zeile';

  @override
  String get reflectionLengthSentences => 'Ein paar Sätze';

  @override
  String get reflectionLengthParagraph => 'Kurzer Absatz';

  @override
  String get reflectionSpecifics => 'Details';

  @override
  String get reflectionSpecificsNameFreely => 'Details benennen';

  @override
  String get reflectionSpecificsThemes => 'Nur Themen';

  @override
  String get reflectionSpecificsLetPeriod => 'Es entscheiden lassen';

  @override
  String get reflectionGenerateAll => 'Rückblicke erstellen';

  @override
  String get reflectionRegenerate => 'Neu erstellen';

  @override
  String get reflectionDeleteDay => 'Tag löschen';

  @override
  String get reflectionDeleteWeek => 'Woche löschen';

  @override
  String get reflectionDeleteMonth => 'Monat löschen';

  @override
  String get reflectionRegenerateFailed => 'Rückblick nicht möglich. Versuchen Sie es erneut.';

  @override
  String get reflectionsDisabledTitle => 'Rückblicke sind aus';

  @override
  String get reflectionsDisabledBody =>
      'Solange Rückblicke aus sind, wird nichts Neues geschrieben.';

  @override
  String get reflectionsDisabledEnable => 'Einschalten';

  @override
  String get reflectionOffTitle => 'Apple Intelligence ist aus';

  @override
  String get reflectionOffBody =>
      'Schalten Sie es in den Einstellungen unter Apple Intelligence und Siri ein, um Rückblicke zu erhalten.';

  @override
  String get reflectionPreparingTitle => 'Wird vorbereitet';

  @override
  String get reflectionPreparingBody =>
      'Apple Intelligence wird auf diesem Gerät vorbereitet. Rückblicke starten, sobald es fertig ist.';

  @override
  String get reflectionUnsupportedTitle => 'Hier nicht verfügbar';

  @override
  String get reflectionUnsupportedBody =>
      'Dieses Gerät unterstützt Apple Intelligence nicht, das für Rückblicke nötig ist.';

  @override
  String get settingsNotifications => 'Mitteilungen';

  @override
  String get notifyReflectionReminders => 'Rückblick-Erinnerungen';

  @override
  String get notifyPeriodDay => 'Tag';

  @override
  String get notifyPeriodWeek => 'Woche';

  @override
  String get notifyPeriodMonth => 'Monat';

  @override
  String get notifyReflectionsInfo =>
      'Ein Hinweis, sobald ein neuer Rückblick zum Lesen bereit ist. Er erscheint auf deinem Gerät; nichts wird irgendwohin gesendet.';

  @override
  String get notifyTime => 'Uhrzeit';

  @override
  String get notifyPermissionDenied => 'Mitteilungen sind in den Einstellungen deaktiviert.';

  @override
  String get notifyOpenSettings => 'Einstellungen öffnen';

  @override
  String get notifyDailyTitle => 'Dein Tag ist bereit';

  @override
  String get notifyDailyBody => 'Öffnen, um den Rückblick von gestern zu lesen.';

  @override
  String get notifyWeeklyTitle => 'Deine Woche ist bereit';

  @override
  String get notifyWeeklyBody => 'Öffnen, um den Rückblick der letzten Woche zu lesen.';

  @override
  String get notifyMonthlyTitle => 'Dein Monat ist bereit';

  @override
  String get notifyMonthlyBody => 'Öffnen, um den Rückblick des letzten Monats zu lesen.';

  @override
  String get notifyNeedsReflections =>
      'Hinweise kommen, sobald ein neuer Rückblick zum Lesen bereit ist. Rückblicke sind gerade aus.';

  @override
  String get notifyTurnOnReflections => 'Rückblicke einschalten';

  @override
  String get notifyReflectionsUnavailable =>
      'Dieses Gerät kann keine Rückblicke erstellen, daher gibt es keinen Hinweis.';

  @override
  String get themeRequestInfo =>
      'Möchtest du OpenTranscribe in einem Theme, das hier fehlt? Öffne ein Issue auf GitHub, und wir fügen es in einer kommenden Version hinzu. Hinzugefügte Themes sind für Mitglieder des OpenTranscribe Club.';

  @override
  String get themeRequestLink => 'Theme auf GitHub anfragen';

  @override
  String get exportEntry => 'Exportieren';

  @override
  String get exportEntryTitle => 'Eintrag exportieren';

  @override
  String get exportIncludeAudio => 'Audio einschließen';

  @override
  String get exportFormatMarkdown => 'Markdown';

  @override
  String get exportFormatMarkdownNote => 'Eine Notiz je Eintrag, plus JSON.';

  @override
  String get exportFormatObsidian => 'Obsidian Vault';

  @override
  String get exportFormatObsidianNote => 'Notizen mit Eigenschaften und Audio.';

  @override
  String get exportFormatWeb => 'Webseite';

  @override
  String get exportFormatWebNote => 'Suche und Player, in jedem Browser.';

  @override
  String get exportFailedTitle => 'Export fehlgeschlagen';

  @override
  String get exportFailedBody =>
      'Die Dateien konnten nicht vorbereitet werden. Nichts wurde geteilt.';

  @override
  String get exportTooLargeBody =>
      'Der Export übersteigt die 4 GB, die eine einzelne Datei fassen kann. Nichts wurde geteilt.';

  @override
  String get exportNoSpaceBody =>
      'Nicht genug freier Speicher, um die Dateien vorzubereiten. Nichts wurde geteilt.';

  @override
  String get exportCancel => 'Abbrechen';

  @override
  String get exportUntitled => 'Ohne Titel';

  @override
  String get exportTranscriptHeading => 'Transkript';

  @override
  String get exportQuiet => 'Eine stille Zeit.';

  @override
  String get exportHtmlSearch => 'Suchen';

  @override
  String get exportHtmlSchemeLabel => 'Farbschema';

  @override
  String get exportHtmlSchemeAuto => 'Auto';

  @override
  String get exportHtmlSchemeLight => 'Hell';

  @override
  String get exportHtmlSchemeDark => 'Dunkel';

  @override
  String get exportHtmlEmptyTitle => 'Noch nichts hier';

  @override
  String get exportHtmlEmptyBody => 'Dieses Journal hat keine Einträge.';

  @override
  String get exportHtmlNoMatchesTitle => 'Nichts gefunden';

  @override
  String exportHtmlNoMatches(String term) {
    return 'Kein Eintrag passt zu „$term“';
  }

  @override
  String get exportHtmlPlay => 'Wiedergabe';

  @override
  String get exportHtmlPause => 'Pause';

  @override
  String get exportHtmlBack => '15 Sekunden zurück';

  @override
  String get exportHtmlSpeed => 'Wiedergabegeschwindigkeit';

  @override
  String get exportHtmlSeek => 'Position';

  @override
  String get settingsBackup => 'Backup';

  @override
  String get backupInfo =>
      'Ein Backup enthält jeden Eintrag mit Audio und Rückblicken. Verschlüsselst du es, ist die Passphrase der einzige Schlüssel.';

  @override
  String get backupInfoEmpty =>
      'Noch nichts zu sichern. Ein Backup enthält jeden Eintrag mit Audio und Rückblicken.';

  @override
  String backupInfoMeasured(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ein Backup enthält alle $count Einträge mit Audio und Rückblicken, etwa $size.',
      one: 'Ein Backup enthält deinen einen Eintrag mit Audio und Rückblicken, etwa $size.',
    );
    return '$_temp0 Verschlüsselst du es, ist die Passphrase der einzige Schlüssel.';
  }

  @override
  String get backupExportSection => 'Export';

  @override
  String backupExportAs(String format) {
    return 'Als $format exportieren';
  }

  @override
  String get backupExportInfo =>
      'Schreibt jeden Eintrag in einem beim Export gewählten Format als Zip für das Teilen-Menü. Eine Kopie für andere Apps; Wiederherstellen braucht ein Backup.';

  @override
  String get backupSeal => 'Mit Passphrase verschlüsseln';

  @override
  String get backupSave => 'Backup exportieren';

  @override
  String backupLastBackup(String date) {
    return 'Letztes Backup $date';
  }

  @override
  String get passphraseCreateTitle => 'Backup verschlüsseln';

  @override
  String get passphraseCreateBody =>
      'Die Passphrase ist der einzige Schlüssel. Sie wird nirgends gespeichert; ohne sie ist das Backup Rauschen.';

  @override
  String get passphrasePlaceholder => 'Passphrase';

  @override
  String get passphraseRepeatPlaceholder => 'Passphrase wiederholen';

  @override
  String get passphraseTooShort => 'Mindestens 8 Zeichen';

  @override
  String get passphraseMismatch => 'Passphrasen stimmen nicht überein';

  @override
  String get passphraseShow => 'Einblenden';

  @override
  String get passphraseHide => 'Ausblenden';

  @override
  String get importUnlockTitle => 'Verschlüsseltes Backup';

  @override
  String get importUnlockBody =>
      'Gib die Passphrase ein, mit der dieses Backup verschlüsselt wurde.';

  @override
  String get importUnlock => 'Entsiegeln';

  @override
  String get importWrongPassphrase =>
      'Konnte nicht entsiegeln. Falsche Passphrase oder beschädigte Datei.';

  @override
  String get importConfirmTitle => 'Dieses Backup wiederherstellen?';

  @override
  String get importConfirmBody =>
      'Fügt seine Einträge deinem Journal hinzu. Ein bereits vorhandener Eintrag übernimmt die Version aus dem Backup; spätere Bearbeitungen gehen verloren. Dasselbe Backup zweimal wiederherzustellen dupliziert nie.';

  @override
  String get importConfirm => 'Wiederherstellen';

  @override
  String get importSummaryTitle => 'Wiederherstellung abgeschlossen';

  @override
  String importSummaryAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einträge hinzugefügt.',
      one: '1 Eintrag hinzugefügt.',
      zero: 'Nichts Neues hinzuzufügen.',
    );
    return '$_temp0';
  }

  @override
  String importSummaryReplaced(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einträge wurden durch die Backup-Version ersetzt.',
      one: '1 Eintrag wurde durch die Backup-Version ersetzt.',
    );
    return '$_temp0';
  }

  @override
  String importSummarySkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einträge waren bereits im Journal.',
      one: '1 Eintrag war bereits im Journal.',
    );
    return '$_temp0';
  }

  @override
  String importSummaryAudio(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufnahmen wiederhergestellt.',
      one: '1 Aufnahme wiederhergestellt.',
    );
    return '$_temp0';
  }

  @override
  String importConfirmCounts(int count, int audio) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einträge',
      one: '1 Eintrag',
    );
    String _temp1 = intl.Intl.pluralLogic(
      audio,
      locale: localeName,
      other: '$audio Aufnahmen',
      one: '1 Aufnahme',
      zero: 'keine Aufnahmen',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get importFailedTitle => 'Wiederherstellung fehlgeschlagen';

  @override
  String get importFailedBody =>
      'Das Backup konnte nicht gelesen werden. Nichts im Journal wurde verändert.';

  @override
  String get importNotArchive => 'Kein OpenTranscribe-Backup. Nichts im Journal wurde verändert.';

  @override
  String get importNewerVersion =>
      'Von einer neueren Version der App erstellt. Aktualisiere, um es zu importieren.';

  @override
  String get importRezipped =>
      'Dieses Backup wurde von einem anderen Tool neu gezippt. Sichere ein frisches und stelle das wieder her.';

  @override
  String get backButton => 'Zurück';

  @override
  String get menuButton => 'Mehr';

  @override
  String get languageMenuButton => 'Sprache';

  @override
  String get recordButton => 'Neuer Eintrag';

  @override
  String get recordCloseButton => 'Abbrechen';

  @override
  String get recordRestartButton => 'Neu beginnen';

  @override
  String get recordPauseButton => 'Pause';

  @override
  String get recordResumeButton => 'Fortsetzen';

  @override
  String get recordCompleteButton => 'Speichern';

  @override
  String get restoreBackupButton => 'Backup wiederherstellen';

  @override
  String get done => 'Fertig';

  @override
  String get importFailedMidway =>
      'Die Wiederherstellung brach mittendrin ab. Alles bisher Wiederhergestellte bleibt; stelle erneut wieder her, um abzuschließen.';

  @override
  String get settingsSupport => 'Unterstützen';

  @override
  String get supportPitch =>
      'Der Club ist die Art, OpenTranscribe zu unterstützen: eine Zahlung, für immer, und ein paar Looks als Dank.';

  @override
  String get supportPitchFree =>
      'Alles, was OpenTranscribe nützlich macht, ist für alle kostenlos, und bleibt es.';

  @override
  String get supportPerkThemes => 'Club-Themes';

  @override
  String get supportPerkThemesNote => 'Gruvbox, Dracula, Nord und jedes Theme außer Standard.';

  @override
  String get supportPerkIcons => 'App-Symbole';

  @override
  String get supportPerkIconsNote => 'Signal, Lines, Dots und jedes Symbol außer Standard.';

  @override
  String get supportThanks => 'Du bist für immer im Club. Danke.';

  @override
  String supportJoin(String price) {
    return 'Für $price dem Club beitreten';
  }

  @override
  String get supportRestore => 'Käufe wiederherstellen';

  @override
  String get supportUnreachable =>
      'Der App Store ist nicht erreichbar. Schließe das hier und öffne es erneut, um es noch einmal zu versuchen.';

  @override
  String get supportPending =>
      'Warten auf Genehmigung. Der Kauf wird abgeschlossen, sobald sie vorliegt.';

  @override
  String get supportRestoreNoneTitle => 'Nichts wiederherzustellen';

  @override
  String get supportRestoreNoneBody => 'Mit dieser Apple-ID ist kein Club-Kauf verknüpft.';

  @override
  String get supportFailedTitle => 'Das hat nicht geklappt';

  @override
  String get supportFailedBody => 'Der App Store konnte nicht abschließen. Versuch es erneut.';

  @override
  String get supportPrivacy => 'Datenschutzerklärung';

  @override
  String get supportTerms => 'Nutzungsbedingungen';

  @override
  String get supportUnlocksSection => 'Was du bekommst';

  @override
  String get supporterTag => 'Club';

  @override
  String supportFooter(String privacy, String terms) {
    return 'Unterstützen ändert nichts an der Privatsphäre. Das Journal verlässt das Telefon nie, siehe $privacy. Der Kauf läuft zu Apples üblichen $terms.';
  }

  @override
  String get continueRecording => 'Mehr aufnehmen';

  @override
  String continuingEntry(String title) {
    return 'Fortsetzung von $title';
  }

  @override
  String get continueUntranscribedLabel => 'Neuer Teil nicht transkribiert';

  @override
  String get continueUntranscribedTitle => 'Der neue Teil wurde nicht transkribiert';

  @override
  String get continueUntranscribedBody =>
      'Die Aufnahme ist gewachsen, aber die neuen Worte sind nicht angekommen. Erneut transkribieren, um alles zu hören.';

  @override
  String get continueSavedSeparatelyLabel => 'Als neuer Eintrag gespeichert';

  @override
  String get continueSavedSeparatelyBody =>
      'Die neue Aufnahme konnte nicht an diesen Eintrag angehängt werden und wurde daher eigenständig gespeichert.';

  @override
  String get continueEntryBusy => 'Dieser Eintrag wird noch transkribiert.';
}
