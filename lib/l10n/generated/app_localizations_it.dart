// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'OpenTranscribe';

  @override
  String get settingsOffline =>
      'Tutto resta su questo dispositivo. Nessun account, nessun cloud, nessuna rete.';

  @override
  String get entryUntranscribed => 'Non trascritta';

  @override
  String get entryUntranscribedTitle => 'Non ancora trascritta';

  @override
  String get entryUntranscribedMessage =>
      'Trasforma questa registrazione in testo da rileggere. Tutto avviene sul tuo dispositivo.';

  @override
  String get entryNoSpeechTitle => 'Nessuna parola da mostrare';

  @override
  String get entryNoSpeechMessage =>
      'Questa registrazione è stata trascritta, ma non è stato trovato parlato.';

  @override
  String get retranscribe => 'Ritrascrivi';

  @override
  String get delete => 'Elimina';

  @override
  String get homeEmptyHeadline => 'Parla, e viene scritto.';

  @override
  String get homeEmptySubtitle =>
      'Tutto ciò che dici viene trascritto e conservato su questo dispositivo. Tira giù per registrare la prima voce.';

  @override
  String get homePullToRecord => 'Tira per registrare';

  @override
  String get menuSourceCode => 'Codice sorgente';

  @override
  String get recordStateRecording => 'In registrazione';

  @override
  String get recordStatePaused => 'In pausa';

  @override
  String get recordErrorMessage => 'Qualcosa è andato storto durante la registrazione.';

  @override
  String get recordLiveUnavailable =>
      'Il testo in tempo reale non è disponibile ora. La registrazione è al sicuro e verrà trascritta quando avrai finito.';

  @override
  String get recordInterruptedSaved =>
      'Registrazione interrotta. La ripresa è stata salvata e può essere trascritta dal tuo diario.';

  @override
  String get recordPermissionTitle => 'Microfono disattivato';

  @override
  String get recordPermissionMessage =>
      'Consenti l\'accesso al microfono per opentranscribe nell\'app Impostazioni, poi riprova.';

  @override
  String get rename => 'Rinomina';

  @override
  String get transcribe => 'Trascrivi';

  @override
  String get transcribeIn => 'Trascrivi in…';

  @override
  String get playbackFailed => 'La riproduzione non è disponibile ora.';

  @override
  String get transcribeErrorModelInstall =>
      'Impossibile ottenere il modello vocale per questa lingua. Controlla la connessione e lo spazio libero, oppure gestisci le lingue in Modelli.';

  @override
  String get transcribeErrorPermission =>
      'Consenti il riconoscimento vocale per opentranscribe nell\'app Impostazioni, poi riprova.';

  @override
  String get transcribeErrorUnavailable =>
      'La trascrizione sul dispositivo non è disponibile per questa lingua su questo dispositivo.';

  @override
  String get transcribeErrorGeneric => 'Qualcosa è andato storto. Riprova.';

  @override
  String get transcribeErrorCapReached =>
      'Limite di lingue raggiunto. Rimuovi una lingua in Impostazioni, poi riprova.';

  @override
  String get transcribeErrorLabelPermission => 'Riconoscimento vocale disattivato';

  @override
  String get transcribeErrorLabelUnavailable => 'Non disponibile su questo dispositivo';

  @override
  String get transcribeErrorLabelModelInstall => 'Impossibile ottenere il modello';

  @override
  String get transcribeErrorLabelCapReached => 'Limite di lingue raggiunto';

  @override
  String get transcribeErrorLabelGeneric => 'Trascrizione non riuscita';

  @override
  String get transcribeErrorTitlePermission => 'Attiva il riconoscimento vocale';

  @override
  String get transcribeErrorTitleUnavailable => 'Non disponibile qui';

  @override
  String get transcribeErrorTitleModelInstall => 'Impossibile scaricare il modello';

  @override
  String get transcribeErrorTitleCapReached => 'Limite di lingue raggiunto';

  @override
  String get transcribeErrorTitleGeneric => 'Qualcosa è andato storto';

  @override
  String get settingsAppearance => 'Aspetto';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Chiaro';

  @override
  String get themeDark => 'Scuro';

  @override
  String get themeNameDefault => 'Predefinito';

  @override
  String get themeNameGruvbox => 'Gruvbox';

  @override
  String get themeNameSolarized => 'Solarized';

  @override
  String get themeNameSepia => 'Seppia';

  @override
  String get settingsAppLanguage => 'Lingua';

  @override
  String get transcriptionInfo =>
      'Ogni lingua usa il proprio modello sul dispositivo, scaricato una volta e condiviso con il sistema; i modelli non incidono sullo spazio di questa app. Il sistema limita quante lingue un\'app può tenere pronte contemporaneamente.';

  @override
  String transcriptionCap(int used, int max) {
    return '$used di $max slot lingua usati';
  }

  @override
  String get transcriptionRemoveHint => 'Scorri verso sinistra su una lingua per rimuoverla.';

  @override
  String get transcriptionErrorUnsupported =>
      'Questa lingua non può ancora essere scaricata su questo dispositivo.';

  @override
  String get transcriptionErrorStuck =>
      'Un download precedente è ancora in sospeso. Il sistema riprova quando le condizioni migliorano; riprovare è sicuro.';

  @override
  String get transcriptionErrorGeneric =>
      'Download non riuscito. Controlla la connessione e lo spazio libero, poi riprova.';

  @override
  String get transcriptionErrorCap =>
      'Limite di lingue raggiunto. Rimuovi una lingua per aggiungere questa.';

  @override
  String get transcriptionErrorRemove => 'Impossibile rimuovere questa lingua. Riprova.';

  @override
  String get transcriptionDownloading => 'Download in corso';

  @override
  String get retry => 'Riprova';

  @override
  String get modelFailCapTitle => 'Limite di lingue raggiunto';

  @override
  String modelFailCapBody(String language) {
    return 'Il sistema limita quante lingue un\'app può tenere pronte contemporaneamente. Rimuovine una per fare spazio a $language.';
  }

  @override
  String get modelFailUnsupportedTitle => 'Non ancora disponibile';

  @override
  String modelFailUnsupportedBody(String language) {
    return 'Non c\'è ancora un modello sul dispositivo per $language su questo dispositivo. Potrebbe arrivare con un aggiornamento di sistema.';
  }

  @override
  String get modelFailStuckTitle => 'Ancora in download';

  @override
  String modelFailStuckBody(String language) {
    return 'Un download precedente per $language è ancora in sospeso. Il sistema riprova quando le condizioni migliorano, e richiederlo di nuovo è sicuro.';
  }

  @override
  String get modelFailGenericTitle => 'Download non riuscito';

  @override
  String modelFailGenericBody(String language) {
    return 'Impossibile scaricare il modello $language. Controlla la connessione e lo spazio libero, poi riprova.';
  }

  @override
  String get modelFailRemoveTitle => 'Rimozione non riuscita';

  @override
  String modelFailRemoveBody(String language) {
    return 'Il sistema non ha rilasciato $language. Riprovare è sicuro.';
  }

  @override
  String get settingsModels => 'Trascrizione';

  @override
  String get transcriptionLanguages => 'Lingue';

  @override
  String get transcriptionDefaultTag => 'Predefinita';

  @override
  String get transcriptionDefaultHint =>
      'Tocca e tieni premuta una lingua per renderla predefinita.';

  @override
  String transcriptionDeviceLanguageFallback(String fallback) {
    return 'La lingua del tuo telefono non è ancora supportata per la trascrizione sul dispositivo, quindi la predefinita è $fallback.';
  }

  @override
  String get onboardingIntroBody => 'Dici quello che pensi, e viene scritto.';

  @override
  String get onboardingSpeakTitle => 'Parla e basta';

  @override
  String get onboardingSpeakLine => 'Tocca registra e di\' quello che hai in mente.';

  @override
  String get onboardingWriteTitle => 'Rileggilo';

  @override
  String get onboardingWriteLine => 'Ogni registrazione viene scritta come testo.';

  @override
  String get onboardingPrivateTitle => 'Niente lascia il telefono';

  @override
  String get onboardingPrivateLine =>
      'Nessun account, nessun cloud. La modalità aereo non cambia nulla.';

  @override
  String get onboardingReflectTitle => 'Riflessioni';

  @override
  String get onboardingReflectLine =>
      'Le tue voci tornano come una breve nota, tutto sul dispositivo.';

  @override
  String get onboardingSource => 'Open source';

  @override
  String get onboardingSourceLine => 'Ogni riga è pubblica. Leggila su GitHub.';

  @override
  String get onboardingPermissionsTitle => 'Consenti l\'accesso';

  @override
  String get onboardingPermissionsBody => 'Tutto questo funziona interamente sul tuo dispositivo.';

  @override
  String get onboardingMicName => 'Microfono';

  @override
  String get onboardingMicReason => 'Per registrare la tua voce.';

  @override
  String get onboardingSpeechName => 'Riconoscimento vocale';

  @override
  String get onboardingSpeechReason =>
      'Per trasformare le registrazioni in testo, sul dispositivo.';

  @override
  String get onboardingNotifyName => 'Notifiche';

  @override
  String get onboardingNotifyReason => 'Per un promemoria quando una riflessione è pronta.';

  @override
  String get onboardingAllow => 'Consenti';

  @override
  String get onboardingOpenSettings => 'Abilita in Impostazioni';

  @override
  String get onboardingModelsTitle => 'Configura la trascrizione';

  @override
  String get onboardingModelsBody =>
      'Funziona offline una volta che la tua lingua è sul dispositivo. Puoi aggiungerne altre in qualsiasi momento dal menu.';

  @override
  String get onboardingReflectionsOn =>
      'Le tue registrazioni diventano una breve riflessione, interamente su questo dispositivo.';

  @override
  String get onboardingReflectionsPreparing =>
      'Iniziano quando Apple Intelligence è pronto su questo dispositivo.';

  @override
  String get onboardingReflectionsOff =>
      'Attiva Apple Intelligence in Impostazioni, in Apple Intelligence e Siri, per riceverle.';

  @override
  String get onboardingNext => 'Avanti';

  @override
  String get onboardingStart => 'Inizia';

  @override
  String get settingsCache => 'Cache';

  @override
  String cacheRecordingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count registrazioni',
      one: '1 registrazione',
    );
    return '$_temp0';
  }

  @override
  String get cacheReclaimable => 'Recuperabile';

  @override
  String get cacheReclaimableInfo => 'Trascritto, si può eliminare';

  @override
  String get cacheUsageInfo =>
      'L\'audio delle voci trascritte può essere eliminato; il testo resta. Le registrazioni non ancora trascritte non vengono mai toccate.';

  @override
  String get cacheKeepAudio => 'Conserva audio';

  @override
  String get cacheKeepAudioInfo =>
      'Se disattivato, ogni registrazione viene eliminata appena la trascrizione riesce. Queste voci sono solo testo: niente riproduzione, niente nuova trascrizione con un motore migliore.';

  @override
  String get cacheClear => 'Elimina audio trascritto';

  @override
  String get cacheClearTitle => 'Eliminare l\'audio trascritto?';

  @override
  String cacheClearBody(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Elimina l\'audio di $count voci trascritte ($size). Il testo resta. Non si può annullare.',
      one: 'Elimina l\'audio di una voce trascritta ($size). Il testo resta. Non si può annullare.',
    );
    return '$_temp0';
  }

  @override
  String get cacheClearConfirm => 'Elimina registrazioni';

  @override
  String get reflectionsTitle => 'Riflessioni';

  @override
  String get reflectionPeriods => 'Periodi';

  @override
  String get reflectionDaily => 'Giornaliera';

  @override
  String get reflectionWeekly => 'Settimanale';

  @override
  String get reflectionMonthly => 'Mensile';

  @override
  String get reflectionsEmptyTitle => 'Ancora nessuna riflessione';

  @override
  String get reflectionsEmptyBody =>
      'La prima arriva dopo che hai scritto nel diario, rileggendo ciò che hai registrato.';

  @override
  String get reflectionQuietDay => 'Una giornata tranquilla.';

  @override
  String get reflectionQuietWeek => 'Una settimana tranquilla.';

  @override
  String get reflectionQuietMonth => 'Un mese tranquillo.';

  @override
  String get reflectionWaitingTitle => 'Non ancora scritta';

  @override
  String get reflectionWaitingBody =>
      'Sarà riletta alla prossima apertura del diario, quando Apple Intelligence è pronto.';

  @override
  String get reflectionErasedTitle => 'Eliminata';

  @override
  String get reflectionErasedBody => 'Hai rimosso questa riflessione. Rigenera la scrive di nuovo.';

  @override
  String get reflectionQuietBody => 'Niente è diventato una riflessione.';

  @override
  String reflectionWrittenOn(String date) {
    return 'Scritta il $date';
  }

  @override
  String reflectionOfPeriod(String range) {
    return 'Riflessione del $range';
  }

  @override
  String get reflectionVoice => 'Voce';

  @override
  String get reflectionVoiceLiterary => 'Letteraria';

  @override
  String get reflectionVoiceObservational => 'Osservativa';

  @override
  String get reflectionVoiceSparse => 'Essenziale';

  @override
  String get reflectionLength => 'Lunghezza';

  @override
  String get reflectionLengthOneLine => 'Una riga';

  @override
  String get reflectionLengthSentences => 'Qualche frase';

  @override
  String get reflectionLengthParagraph => 'Paragrafo breve';

  @override
  String get reflectionSpecifics => 'Dettagli';

  @override
  String get reflectionSpecificsNameFreely => 'Nomina i dettagli';

  @override
  String get reflectionSpecificsThemes => 'Solo temi';

  @override
  String get reflectionSpecificsLetPeriod => 'Lascia decidere';

  @override
  String get reflectionGenerateAll => 'Genera riflessioni';

  @override
  String get reflectionRegenerate => 'Rigenera';

  @override
  String get reflectionDeleteDay => 'Elimina giorno';

  @override
  String get reflectionDeleteWeek => 'Elimina settimana';

  @override
  String get reflectionDeleteMonth => 'Elimina mese';

  @override
  String get reflectionRegenerateFailed => 'Riflessione non riuscita. Riprova.';

  @override
  String get reflectionsDisabledTitle => 'Le riflessioni sono disattivate';

  @override
  String get reflectionsDisabledBody =>
      'Niente di nuovo sarà scritto mentre le riflessioni sono disattivate.';

  @override
  String get reflectionsDisabledEnable => 'Attiva';

  @override
  String get reflectionOffTitle => 'Apple Intelligence è disattivato';

  @override
  String get reflectionOffBody =>
      'Attivalo in Impostazioni, in Apple Intelligence e Siri, per ricevere le riflessioni.';

  @override
  String get reflectionPreparingTitle => 'Preparazione in corso';

  @override
  String get reflectionPreparingBody =>
      'Apple Intelligence si sta preparando su questo dispositivo. Le riflessioni iniziano quando ha finito.';

  @override
  String get reflectionUnsupportedTitle => 'Non disponibile qui';

  @override
  String get reflectionUnsupportedBody =>
      'Questo dispositivo non supporta Apple Intelligence, necessario per le riflessioni.';

  @override
  String get settingsNotifications => 'Notifiche';

  @override
  String get notifyReflectionReminders => 'Promemoria delle riflessioni';

  @override
  String get notifyPeriodDay => 'Giorno';

  @override
  String get notifyPeriodWeek => 'Settimana';

  @override
  String get notifyPeriodMonth => 'Mese';

  @override
  String get notifyReflectionsInfo =>
      'Un promemoria quando una nuova riflessione è pronta da leggere. Arriva sul tuo dispositivo; nulla viene inviato altrove.';

  @override
  String get notifyTime => 'Ora';

  @override
  String get notifyPermissionDenied => 'Le notifiche sono disattivate in Impostazioni.';

  @override
  String get notifyOpenSettings => 'Apri Impostazioni';

  @override
  String get notifyDailyTitle => 'La tua giornata è pronta';

  @override
  String get notifyDailyBody => 'Apri per leggere la riflessione di ieri.';

  @override
  String get notifyWeeklyTitle => 'La tua settimana è pronta';

  @override
  String get notifyWeeklyBody => 'Apri per leggere la riflessione della settimana scorsa.';

  @override
  String get notifyMonthlyTitle => 'Il tuo mese è pronto';

  @override
  String get notifyMonthlyBody => 'Apri per leggere la riflessione del mese scorso.';

  @override
  String get notifyNeedsReflections =>
      'I promemoria arrivano quando una nuova riflessione è pronta da leggere. Le riflessioni sono disattivate al momento.';

  @override
  String get notifyTurnOnReflections => 'Attiva le riflessioni';

  @override
  String get notifyReflectionsUnavailable =>
      'Questo dispositivo non può generare riflessioni, quindi non c\'è alcun promemoria da inviare.';

  @override
  String get themeRequestInfo =>
      'Vuoi OpenTranscribe in un tema non presente qui? Apri una issue su GitHub e lo aggiungeremo in una prossima versione.';

  @override
  String get themeRequestLink => 'Richiedi un tema su GitHub';

  @override
  String get exportEntry => 'Esporta';

  @override
  String get exportEntryTitle => 'Esporta la voce';

  @override
  String get exportIncludeAudio => 'Includi l\'audio';

  @override
  String get exportFailedTitle => 'Esportazione non riuscita';

  @override
  String get exportFailedBody => 'Impossibile preparare i file. Non è stato condiviso nulla.';

  @override
  String get exportUntitled => 'Senza titolo';

  @override
  String get exportTranscriptHeading => 'Trascrizione';

  @override
  String get exportQuiet => 'Un periodo tranquillo.';

  @override
  String get exportRecorded => 'Registrato';

  @override
  String get exportDuration => 'Durata';

  @override
  String get exportLanguage => 'Lingua';

  @override
  String get exportAudio => 'Audio';

  @override
  String get settingsBackup => 'Backup';

  @override
  String get backupInfo =>
      'Tutto vive su questo telefono; eliminare l\'app elimina il diario. Un export o un archivio passa al foglio di condivisione solo su tua richiesta.';

  @override
  String backupEntriesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count voci',
      one: '1 voce',
      zero: '0 voci',
    );
    return '$_temp0';
  }

  @override
  String get backupExportSection => 'Export';

  @override
  String get backupExportJournal => 'Esporta il diario';

  @override
  String get backupExportInfo =>
      'Scrive ogni voce nel formato scelto, audio incluso, in uno zip per il foglio di condivisione.';

  @override
  String get backupArchiveSection => 'Archivio';

  @override
  String get backupSeal => 'Sigilla con passphrase';

  @override
  String get backupSaveArchive => 'Salva archivio';

  @override
  String backupLastArchive(String date) {
    return 'Ultimo archivio $date';
  }

  @override
  String get backupArchiveInfo =>
      'Un solo file con l\'intero diario, per ripristinare su un\'installazione nuova. Sigillato, si apre solo in questa app con la passphrase; non esiste recupero.';

  @override
  String get backupImportSection => 'Import';

  @override
  String get backupImport => 'Importa archivio';

  @override
  String get backupImportInfo =>
      'Aggiunge le voci di un archivio al diario. Una voce presente in entrambi tiene la versione dell\'archivio, e importare due volte non duplica mai.';

  @override
  String get passphraseCreateTitle => 'Sigilla l\'archivio';

  @override
  String get passphraseCreateBody =>
      'La passphrase è l\'unica chiave. Non viene salvata da nessuna parte; senza, l\'archivio è rumore.';

  @override
  String get passphrasePlaceholder => 'Passphrase';

  @override
  String get passphraseRepeatPlaceholder => 'Ripeti la passphrase';

  @override
  String get passphraseTooShort => 'Almeno 8 caratteri';

  @override
  String get passphraseMismatch => 'Le passphrase non coincidono';

  @override
  String get importUnlockTitle => 'Archivio sigillato';

  @override
  String get importUnlockBody =>
      'Inserisci la passphrase con cui questo archivio è stato sigillato.';

  @override
  String get importUnlock => 'Sblocca';

  @override
  String get importWrongPassphrase =>
      'Impossibile sbloccare. Passphrase errata o file danneggiato.';

  @override
  String get importConfirmTitle => 'Importare l\'archivio?';

  @override
  String get importConfirmBody =>
      'Aggiunge le sue voci al tuo diario. Importare due volte lo stesso archivio non duplica mai.';

  @override
  String get importConfirm => 'Importa';

  @override
  String get importSummaryTitle => 'Import completato';

  @override
  String importSummaryImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count voci importate.',
      one: '1 voce importata.',
      zero: 'Niente di nuovo da importare.',
    );
    return '$_temp0';
  }

  @override
  String importSummarySkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count voci erano già nel diario.',
      one: '1 voce era già nel diario.',
    );
    return '$_temp0';
  }

  @override
  String get importFailedTitle => 'Import non riuscito';

  @override
  String get importFailedBody =>
      'Impossibile leggere l\'archivio. Nulla nel diario è stato modificato.';

  @override
  String get importNotArchive =>
      'Non è un archivio opentranscribe. Nulla nel diario è stato modificato.';

  @override
  String get importNewerVersion =>
      'Creato da una versione più recente dell\'app. Aggiorna per importarlo.';

  @override
  String get importRezipped =>
      'Questo archivio è stato ri-zippato da un altro strumento. Esportane uno nuovo e importa quello.';

  @override
  String get done => 'Fine';

  @override
  String get importFailedMidway =>
      'L\'importazione si è fermata a metà. Quanto già ripristinato resta; importa di nuovo per finire.';
}
