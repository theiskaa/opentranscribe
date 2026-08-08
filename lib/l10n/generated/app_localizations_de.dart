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
  String get settingsModels => 'Transkription';

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
  String get onboardingReflectTitle => 'Rückblicke';

  @override
  String get onboardingReflectLine =>
      'Ihre Einträge werden zu einer kurzen Notiz, ganz auf dem Gerät.';

  @override
  String get onboardingSource => 'Open Source';

  @override
  String get onboardingSourceLine => 'Jede Zeile davon ist öffentlich. Lesen Sie sie auf GitHub.';

  @override
  String get onboardingPermissionsTitle => 'Zugriff erlauben';

  @override
  String get onboardingPermissionsBody => 'Alles hier läuft vollständig auf Ihrem Gerät.';

  @override
  String get onboardingMicName => 'Mikrofon';

  @override
  String get onboardingMicReason => 'Um Ihre Stimme aufzunehmen.';

  @override
  String get onboardingSpeechName => 'Spracherkennung';

  @override
  String get onboardingSpeechReason => 'Um Ihre Aufnahmen auf dem Gerät in Text umzuwandeln.';

  @override
  String get onboardingNotifyName => 'Mitteilungen';

  @override
  String get onboardingNotifyReason => 'Für einen Hinweis, wenn ein Rückblick bereit ist.';

  @override
  String get onboardingAllow => 'Erlauben';

  @override
  String get onboardingOpenSettings => 'In Einstellungen aktivieren';

  @override
  String get onboardingModelsTitle => 'Transkription einrichten';

  @override
  String get onboardingModelsBody =>
      'Sie läuft offline, sobald Ihre Sprache auf dem Gerät ist. Weitere können Sie jederzeit über das Menü hinzufügen.';

  @override
  String get onboardingReflectionsOn =>
      'Ihre Einträge werden zu einem kurzen Rückblick, ganz auf diesem Gerät.';

  @override
  String get onboardingReflectionsPreparing =>
      'Startet, sobald Apple Intelligence auf diesem Gerät bereit ist.';

  @override
  String get onboardingReflectionsOff =>
      'Schalten Sie Apple Intelligence in den Einstellungen unter Apple Intelligence und Siri ein, um sie zu erhalten.';

  @override
  String get onboardingNext => 'Weiter';

  @override
  String get onboardingStart => 'Los geht’s';

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
      'Möchtest du OpenTranscribe in einem Theme, das hier fehlt? Öffne ein Issue auf GitHub, und wir fügen es in einer kommenden Version hinzu.';

  @override
  String get themeRequestLink => 'Theme auf GitHub anfragen';

  @override
  String get exportEntry => 'Exportieren';

  @override
  String get exportEntryTitle => 'Eintrag exportieren';

  @override
  String get exportIncludeAudio => 'Audio einschließen';

  @override
  String get exportFailedTitle => 'Export fehlgeschlagen';

  @override
  String get exportFailedBody =>
      'Die Dateien konnten nicht vorbereitet werden. Nichts wurde geteilt.';

  @override
  String get exportUntitled => 'Ohne Titel';

  @override
  String get exportTranscriptHeading => 'Transkript';

  @override
  String get exportQuiet => 'Eine stille Zeit.';

  @override
  String get exportRecorded => 'Aufgenommen';

  @override
  String get exportDuration => 'Dauer';

  @override
  String get exportLanguage => 'Sprache';

  @override
  String get exportAudio => 'Audio';

  @override
  String get settingsBackup => 'Backup';

  @override
  String get backupInfo =>
      'Ein Backup enthält jeden Eintrag mit Audio und Rückblicken. Verschlüsselst du es, ist die Passphrase der einzige Schlüssel.';

  @override
  String backupInfoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Ein Backup enthält alle $count Einträge mit Audio und Rückblicken. Verschlüsselst du es, ist die Passphrase der einzige Schlüssel.',
      one:
          'Ein Backup enthält deinen einen Eintrag mit Audio und Rückblicken. Verschlüsselst du es, ist die Passphrase der einzige Schlüssel.',
      zero: 'Noch nichts zu sichern. Ein Backup enthält jeden Eintrag mit Audio und Rückblicken.',
    );
    return '$_temp0';
  }

  @override
  String get backupExportSection => 'Export';

  @override
  String get backupExportJournal => 'Journal exportieren';

  @override
  String get backupExportInfo =>
      'Schreibt jeden Eintrag im gewählten Format, Audio inklusive, als Zip für das Teilen-Menü. Eine Kopie für andere Apps; Wiederherstellen braucht ein Backup.';

  @override
  String get backupSeal => 'Mit Passphrase verschlüsseln';

  @override
  String get backupSave => 'Backup sichern';

  @override
  String backupLastBackup(String date) {
    return 'Letztes Backup $date';
  }

  @override
  String get backupRestore => 'Backup wiederherstellen';

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
      'Fügt seine Einträge deinem Journal hinzu. Dasselbe Backup zweimal wiederherzustellen dupliziert nie.';

  @override
  String get importConfirm => 'Wiederherstellen';

  @override
  String get importSummaryTitle => 'Wiederherstellung abgeschlossen';

  @override
  String importSummaryImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einträge wiederhergestellt.',
      one: '1 Eintrag wiederhergestellt.',
      zero: 'Nichts Neues wiederherzustellen.',
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
  String get done => 'Fertig';

  @override
  String get importFailedMidway =>
      'Die Wiederherstellung brach mittendrin ab. Alles bisher Wiederhergestellte bleibt; stelle erneut wieder her, um abzuschließen.';
}
