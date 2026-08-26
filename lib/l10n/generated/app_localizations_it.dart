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
  String get launchFailedTitle => 'Avvio non riuscito';

  @override
  String get launchFailedBody =>
      'Qualcosa che serve all\'avvio non si è caricato. Chiudi l\'app dal selettore delle app e riaprila; se non basta, riavvia il telefono.';

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
  String get editTranscript => 'Modifica';

  @override
  String get editedMarker => 'Modificato';

  @override
  String get revisionHistory => 'Cronologia';

  @override
  String get revisionHistoryBody =>
      'Tutto ciò che il testo di questa voce ha attraversato. Un tocco ripristina una versione come la più recente.';

  @override
  String get revisionCurrent => 'Attuale';

  @override
  String get revisionTranscribed => 'Trascritto';

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
  String transcriptionCap(int used, int max) {
    return '$used di $max slot lingua usati';
  }

  @override
  String get transcriptionErrorUnsupported =>
      'Questa lingua non può ancora essere scaricata su questo dispositivo.';

  @override
  String get languageNeedsDictation =>
      'Attiva la dettatura per questa lingua nelle impostazioni della tastiera di iOS.';

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
  String get modelFailDictationTitle => 'La dettatura non è configurata';

  @override
  String modelFailDictationBody(String language) {
    return '$language viene trascritto con il modello di dettatura del sistema, che non è ancora su questo iPhone. Aggiungi la sua tastiera e attiva la dettatura nelle impostazioni di iOS.';
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
  String get transcriptionYourLanguages => 'Le tue lingue';

  @override
  String get transcriptionAllLanguages => 'Tutte le lingue';

  @override
  String get transcriptionSpeaking => 'Lingua parlata';

  @override
  String get transcriptionAlsoReady => 'Anche pronte';

  @override
  String get transcriptionAddLanguage => 'Aggiungi';

  @override
  String transcriptionHeroReady(String engine) {
    return 'Pronta · $engine';
  }

  @override
  String get transcriptionFootnote =>
      'I modelli si scaricano una volta e sono condivisi con il sistema.';

  @override
  String get transcriptionEngines => 'Motori';

  @override
  String get engineBlurbSpeechAnalyzer =>
      'Il motore più recente di Apple, un modello scaricato per lingua';

  @override
  String get engineBlurbDictation => 'Il riconoscimento dietro la dettatura della tastiera iOS';

  @override
  String get engineUnavailableNote => 'Non disponibile su questo iPhone';

  @override
  String get engineUnavailableTitle => 'Non disponibile su questo iPhone';

  @override
  String engineUnavailableBody(String engine) {
    return '$engine richiede iOS 26 e un iPhone più recente. La registrazione continua a usare il motore disponibile qui.';
  }

  @override
  String get engineBusyTitle => 'Registrazione in corso';

  @override
  String get engineBusyBody => 'Interrompi la registrazione in corso, poi cambia motore.';

  @override
  String get engineNotSavedTitle => 'Scelta non salvata';

  @override
  String get engineNotSavedBody =>
      'La scelta del motore non è stata salvata e non sopravviverà a un riavvio.';

  @override
  String get transcriptionDefaultTag => 'Predefinita';

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
  String get exportFormatMarkdown => 'Markdown';

  @override
  String get exportFormatMarkdownNote => 'Un file di testo per voce, più un .json.';

  @override
  String get exportFormatObsidian => 'Obsidian';

  @override
  String get exportFormatObsidianNote => 'Note con proprietà e audio incorporato.';

  @override
  String get exportFormatWeb => 'Sito web';

  @override
  String get exportFormatWebNote => 'Si apre in ogni browser, con player.';

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
  String get settingsBackup => 'Backup';

  @override
  String get backupInfo =>
      'Un backup contiene ogni voce con il suo audio e le riflessioni. Se lo cifri, la passphrase è l\'unica chiave.';

  @override
  String backupInfoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Un backup contiene tutte le $count voci con il loro audio e le riflessioni. Se lo cifri, la passphrase è l\'unica chiave.',
      one:
          'Un backup contiene la tua unica voce con il suo audio e le riflessioni. Se lo cifri, la passphrase è l\'unica chiave.',
      zero:
          'Ancora nulla da salvare. Un backup contiene ogni voce con il suo audio e le riflessioni.',
    );
    return '$_temp0';
  }

  @override
  String get backupExportSection => 'Export';

  @override
  String get backupExportJournal => 'Esporta il diario';

  @override
  String get backupExportInfo =>
      'Scrive ogni voce nel formato scelto, audio incluso, in uno zip per il foglio di condivisione. Una copia per altre app; per ripristinare serve un backup.';

  @override
  String get backupSeal => 'Cifra con passphrase';

  @override
  String get backupSave => 'Salva backup';

  @override
  String backupLastBackup(String date) {
    return 'Ultimo backup $date';
  }

  @override
  String get passphraseCreateTitle => 'Cifra il backup';

  @override
  String get passphraseCreateBody =>
      'La passphrase è l\'unica chiave. Non viene salvata da nessuna parte; senza, il backup è rumore.';

  @override
  String get passphrasePlaceholder => 'Passphrase';

  @override
  String get passphraseRepeatPlaceholder => 'Ripeti la passphrase';

  @override
  String get passphraseTooShort => 'Almeno 8 caratteri';

  @override
  String get passphraseMismatch => 'Le passphrase non coincidono';

  @override
  String get importUnlockTitle => 'Backup cifrato';

  @override
  String get importUnlockBody => 'Inserisci la passphrase con cui questo backup è stato cifrato.';

  @override
  String get importUnlock => 'Sblocca';

  @override
  String get importWrongPassphrase =>
      'Impossibile sbloccare. Passphrase errata o file danneggiato.';

  @override
  String get importConfirmTitle => 'Ripristinare questo backup?';

  @override
  String get importConfirmBody =>
      'Aggiunge le sue voci al tuo diario. Ripristinare due volte lo stesso backup non duplica mai.';

  @override
  String get importConfirm => 'Ripristina';

  @override
  String get importSummaryTitle => 'Ripristino completato';

  @override
  String importSummaryImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count voci ripristinate.',
      one: '1 voce ripristinata.',
      zero: 'Niente di nuovo da ripristinare.',
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
  String get importFailedTitle => 'Ripristino non riuscito';

  @override
  String get importFailedBody =>
      'Impossibile leggere il backup. Nulla nel diario è stato modificato.';

  @override
  String get importNotArchive =>
      'Non è un backup OpenTranscribe. Nulla nel diario è stato modificato.';

  @override
  String get importNewerVersion =>
      'Creato da una versione più recente dell\'app. Aggiorna per importarlo.';

  @override
  String get importRezipped =>
      'Questo backup è stato ri-zippato da un altro strumento. Salvane uno nuovo e ripristina quello.';

  @override
  String get done => 'Fine';

  @override
  String get importFailedMidway =>
      'Il ripristino si è fermato a metà. Quanto già ripristinato resta; ripristina di nuovo per finire.';

  @override
  String get supportGateBody =>
      'Le esportazioni formattate sono per i membri del club. Il backup resta gratuito per tutti.';

  @override
  String get settingsSupport => 'Sostieni';

  @override
  String get supportGateAction => 'Diventa membro del club';

  @override
  String get supportPitch =>
      'OpenTranscribe è gratuito e privato, e sostenerlo lo mantiene così. Entrare nel club è un solo pagamento, per sempre.';

  @override
  String get supportPerkExports => 'Esportazioni formattate';

  @override
  String get supportPerkExportsNote => 'Markdown, Obsidian o un sito web.';

  @override
  String get supportPerkFuture => 'Future funzioni del club';

  @override
  String get supportPerkFutureNote => 'Ciò che arriverà al club, incluso.';

  @override
  String get supportThanks => 'Sei nel club per sempre. Grazie.';

  @override
  String supportJoin(String price) {
    return 'Entra nel club per $price';
  }

  @override
  String get supportRestore => 'Ripristina acquisti';

  @override
  String get supportUnreachable =>
      'Impossibile raggiungere l\'App Store. Riapri questa schermata per riprovare.';

  @override
  String get supportPending =>
      'In attesa di approvazione. L\'acquisto si completa una volta approvato.';

  @override
  String get supportRestoreNoneTitle => 'Niente da ripristinare';

  @override
  String get supportRestoreNoneBody => 'Nessun acquisto del club è associato a questo ID Apple.';

  @override
  String get supportFailedTitle => 'Non è andata a buon fine';

  @override
  String get supportFailedBody => 'L\'App Store non è riuscito a completare. Riprova.';

  @override
  String get supportPrivacy => 'informativa sulla privacy';

  @override
  String get supportTerms => 'condizioni d\'uso';

  @override
  String get supportUnlocksSection => 'Per i membri del club';

  @override
  String get supportMemberUnlocks => 'Cosa ottieni';

  @override
  String get supporterTag => 'Club';

  @override
  String supportFooter(String privacy, String terms) {
    return 'Sostenere non cambia nulla per la privacy. Il diario non lascia mai il telefono, come indicato nella $privacy, e l\'acquisto segue le $terms standard di Apple.';
  }
}
