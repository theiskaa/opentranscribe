// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'OpenTranscribe';

  @override
  String get launchFailedTitle => 'Não foi possível iniciar';

  @override
  String get launchFailedBody =>
      'Algo de que a app precisa no arranque não carregou. Feche a app no alternador de apps e volte a abri-la; se não resolver, reinicie o telemóvel.';

  @override
  String get entryUntranscribed => 'Sem transcrição';

  @override
  String get entryUntranscribedTitle => 'Ainda não transcrito';

  @override
  String get entryUntranscribedMessage =>
      'Transforme esta gravação em texto que pode reler. Corre no seu dispositivo.';

  @override
  String get entryNoSpeechTitle => 'Nada para mostrar';

  @override
  String get entryNoSpeechMessage =>
      'Esta gravação foi transcrita, mas não se encontrou fala nela.';

  @override
  String get retranscribe => 'Retranscrever';

  @override
  String get retranscribeAllTitle => 'Retranscrever tudo';

  @override
  String get retranscribeRowQueued => 'Para retranscrever';

  @override
  String get retranscribeRowCurrent => 'Entradas já atualizadas';

  @override
  String get retranscribeRowLanded => 'Entradas retranscritas';

  @override
  String get retranscribeRowFailed => 'Com falha';

  @override
  String get retranscribeHistoryNote =>
      'As palavras substituídas ficam no histórico de cada entrada.';

  @override
  String get retranscribeFailedNote =>
      'As entradas falhadas ficam em fila para a próxima execução.';

  @override
  String retranscribeAllCurrentBody(String engine) {
    return 'Cada gravação guardada já foi transcrita por $engine.';
  }

  @override
  String get retranscribeStart => 'Começar';

  @override
  String retranscribeProgressOf(int done, int total) {
    return '$done de $total';
  }

  @override
  String get retranscribeWaitingRecording => 'Em pausa enquanto uma gravação termina';

  @override
  String get retranscribeWaitingThermal => 'Em pausa enquanto o dispositivo arrefece';

  @override
  String get retranscribeCancel => 'Cancelar';

  @override
  String get retranscribeCancelledNote => 'Parado a meio. Voltar a executar retoma onde ficou.';

  @override
  String get delete => 'Eliminar';

  @override
  String get homeEmptyHeadline => 'Fale, e fica escrito.';

  @override
  String get homeEmptySubtitle =>
      'Tudo o que diz é transcrito e guardado neste dispositivo. Puxe para baixo para gravar a sua primeira entrada.';

  @override
  String get homePullToRecord => 'Puxe para gravar';

  @override
  String get menuSourceCode => 'Código-fonte';

  @override
  String get menuHowItWorks => 'Como funciona';

  @override
  String get recordStateRecording => 'A gravar';

  @override
  String get recordStatePaused => 'Em pausa';

  @override
  String get recordErrorMessage => 'Algo correu mal durante a gravação.';

  @override
  String get recordLiveUnavailable =>
      'O texto em direto não está disponível de momento. A sua gravação está segura e será transcrita quando terminar.';

  @override
  String get recordInterruptedSaved =>
      'Gravação interrompida. A sua gravação foi guardada e pode ser transcrita a partir do seu diário.';

  @override
  String get recordPermissionTitle => 'O microfone está desligado';

  @override
  String get recordPermissionMessage =>
      'Permita o acesso ao microfone para o opentranscribe na app Definições e tente novamente.';

  @override
  String get rename => 'Mudar o nome';

  @override
  String get editTranscript => 'Editar';

  @override
  String get editedMarker => 'Editado';

  @override
  String get revisionHistory => 'Histórico';

  @override
  String get revisionHistoryBody =>
      'Tudo por que o texto desta entrada já passou. Tocar numa versão restaura-a como a mais recente.';

  @override
  String get revisionCurrent => 'Atual';

  @override
  String get revisionTranscribed => 'Transcrito';

  @override
  String get transcribe => 'Transcrever';

  @override
  String get transcribeIn => 'Transcrever em…';

  @override
  String get playbackFailed => 'A reprodução não está disponível de momento.';

  @override
  String get transcribeErrorModelInstall =>
      'Não foi possível obter o modelo de fala para este idioma. Verifique a ligação e o espaço livre, ou faça a gestão dos idiomas em Modelos.';

  @override
  String get transcribeErrorPermission =>
      'Permita o reconhecimento de fala para o opentranscribe na app Definições e tente novamente.';

  @override
  String get transcribeErrorUnavailable =>
      'A transcrição no dispositivo não está disponível para este idioma neste dispositivo.';

  @override
  String get transcribeErrorGeneric => 'Algo correu mal. Tente novamente.';

  @override
  String get transcribeErrorCapReached =>
      'Limite de idiomas atingido. Remova um idioma nas Definições e tente novamente.';

  @override
  String get transcribeErrorRecordingMissing =>
      'A gravação desta entrada já não está no dispositivo, por isso não pode ser transcrita de novo. O texto que já existe é tudo o que resta.';

  @override
  String get transcribeErrorLabelPermission => 'Reconhecimento de fala desligado';

  @override
  String get transcribeErrorLabelUnavailable => 'Indisponível neste dispositivo';

  @override
  String get transcribeErrorLabelModelInstall => 'Não foi possível obter o modelo';

  @override
  String get transcribeErrorLabelCapReached => 'Limite de idiomas atingido';

  @override
  String get transcribeErrorLabelGeneric => 'Transcrição falhou';

  @override
  String get transcribeErrorLabelRecordingMissing => 'Gravação ausente';

  @override
  String get transcribeErrorTitlePermission => 'Ativar o reconhecimento de fala';

  @override
  String get transcribeErrorTitleUnavailable => 'Indisponível aqui';

  @override
  String get transcribeErrorTitleModelInstall => 'Não foi possível transferir o modelo';

  @override
  String get transcribeErrorTitleCapReached => 'Limite de idiomas atingido';

  @override
  String get transcribeErrorTitleGeneric => 'Algo correu mal';

  @override
  String get transcribeErrorTitleRecordingMissing => 'A gravação desapareceu';

  @override
  String get settingsAppearance => 'Aparência';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get themeSystem => 'Sistema';

  @override
  String get themeLight => 'Claro';

  @override
  String get themeDark => 'Escuro';

  @override
  String get themeNameDefault => 'Predefinido';

  @override
  String get themeNameGruvbox => 'Gruvbox';

  @override
  String get themeNameSepia => 'Sépia';

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
  String get appearanceIconSection => 'Ícone da app';

  @override
  String get appIconNameSignal => 'Signal';

  @override
  String get appIconNameLines => 'Lines';

  @override
  String get appIconNameDots => 'Dots';

  @override
  String get appIconFailedTitle => 'O ícone não mudou';

  @override
  String get appIconFailedBody => 'O iOS recusou a alteração. Tente novamente.';

  @override
  String get settingsAppLanguage => 'Idioma';

  @override
  String transcriptionCap(int used, int max) {
    return '$used de $max lugares de idioma usados';
  }

  @override
  String get transcriptionErrorUnsupported =>
      'Este idioma ainda não pode ser transferido neste dispositivo.';

  @override
  String get languageNeedsDictation =>
      'Ative o ditado para este idioma nas definições de teclado do iOS.';

  @override
  String get transcriptionErrorStuck =>
      'Uma transferência anterior ainda está pendente. O sistema tenta novamente quando as condições melhorarem; tentar de novo é seguro.';

  @override
  String get transcriptionErrorGeneric =>
      'A transferência falhou. Verifique a ligação e o espaço livre e tente novamente.';

  @override
  String get transcriptionErrorCap =>
      'Limite de idiomas atingido. Remova um idioma para adicionar este.';

  @override
  String get transcriptionErrorRemove => 'Não foi possível remover este idioma. Tente novamente.';

  @override
  String get transcriptionDownloading => 'A transferir';

  @override
  String get retry => 'Tentar novamente';

  @override
  String get modelFailCapTitle => 'Limite de idiomas atingido';

  @override
  String modelFailCapBody(String language) {
    return 'O sistema limita quantos idiomas uma app pode manter prontos de cada vez. Remova um destes para dar lugar a $language.';
  }

  @override
  String get modelFailUnsupportedTitle => 'Ainda não disponível';

  @override
  String modelFailUnsupportedBody(String language) {
    return 'Ainda não há modelo no dispositivo para $language neste dispositivo. Pode chegar com uma atualização do sistema.';
  }

  @override
  String get modelFailDictationTitle => 'O ditado não está configurado';

  @override
  String modelFailDictationBody(String language) {
    return '$language é transcrito com o modelo de ditado do sistema, que ainda não está neste iPhone. Adicione o teclado e ative o ditado nas definições do iOS.';
  }

  @override
  String get modelFailStuckTitle => 'Ainda a transferir';

  @override
  String modelFailStuckBody(String language) {
    return 'Uma transferência anterior de $language ainda está pendente. O sistema tenta novamente quando as condições melhorarem, e pedir de novo é seguro.';
  }

  @override
  String get modelFailGenericTitle => 'Não foi possível transferir';

  @override
  String modelFailGenericBody(String language) {
    return 'Não foi possível transferir o modelo de $language. Verifique a ligação e o espaço livre e tente novamente.';
  }

  @override
  String get modelFailRemoveTitle => 'Não foi possível remover';

  @override
  String modelFailRemoveBody(String language) {
    return 'O sistema não libertou $language. Tentar de novo é seguro.';
  }

  @override
  String get settingsModels => 'Transcrição';

  @override
  String get transcriptionYourLanguages => 'Os seus idiomas';

  @override
  String get transcriptionAllLanguages => 'Todos os idiomas';

  @override
  String get transcriptionSpeaking => 'Idioma falado';

  @override
  String get transcriptionAlsoReady => 'Também prontos';

  @override
  String get transcriptionAddLanguage => 'Adicionar';

  @override
  String transcriptionHeroReady(String engine) {
    return 'Pronto · $engine';
  }

  @override
  String get transcriptionFootnote =>
      'Os modelos são transferidos uma vez e partilhados com o sistema.';

  @override
  String get transcriptionEngines => 'Motores';

  @override
  String get engineBlurbSpeechAnalyzer =>
      'O motor mais recente da Apple, um modelo transferido por idioma';

  @override
  String get engineBlurbDictation => 'O reconhecimento por trás do ditado do teclado do iOS';

  @override
  String get engineUnavailableNote => 'Indisponível neste iPhone';

  @override
  String get engineUnavailableTitle => 'Indisponível neste iPhone';

  @override
  String engineUnavailableBody(String engine) {
    return '$engine precisa do iOS 26 e de um iPhone mais recente. As gravações continuam a usar o motor disponível aqui.';
  }

  @override
  String get engineBusyTitle => 'Gravação em curso';

  @override
  String get engineBusyBody => 'Pare a gravação atual e depois mude de motor.';

  @override
  String get engineRetranscribingTitle => 'Retranscrição em curso';

  @override
  String get engineRetranscribingBody => 'Espere que termine, ou cancele, e depois mude de motor.';

  @override
  String get engineNotSavedTitle => 'Não foi possível guardar a escolha';

  @override
  String get engineNotSavedBody =>
      'A escolha do motor não foi guardada e não sobrevive a um reinício.';

  @override
  String get transcriptionDefaultTag => 'Predefinido';

  @override
  String transcriptionDeviceLanguageFallback(String fallback) {
    return 'O idioma do seu telemóvel ainda não é suportado para transcrição no dispositivo, por isso $fallback é o predefinido.';
  }

  @override
  String get onboardingOpenSettings => 'Ativar nas Definições';

  @override
  String get onboardingReflectTitle => 'A sua semana, relida';

  @override
  String get onboardingReflectBody =>
      'As entradas releem-se como uma breve reflexão, por dia, semana ou mês. Escrita neste dispositivo pela Apple Intelligence, nunca enviada para lado nenhum.';

  @override
  String get onboardingReflectDay1 => 'Dormi mal, mas a corrida da manhã resolveu quase tudo.';

  @override
  String get onboardingReflectDay2 => 'Dana, café, duas horas sobre nada e sobre tudo.';

  @override
  String get onboardingReflectDay3 => 'Disse não ao projeto extra. Senti-me mais leve o dia todo.';

  @override
  String get onboardingReflectDay4 =>
      'Voltei a casa pelo caminho longo. A cidade estava sossegada, por uma vez.';

  @override
  String get onboardingReflectNote =>
      'Uma semana a dizer não a mais, e as longas caminhadas que voltaram com isso.';

  @override
  String get onboardingShapeTitle => 'Seu, em qualquer forma';

  @override
  String get onboardingShapeBody =>
      'Leve o diário inteiro como Markdown, como Obsidian Vault ou como site web. Faça uma cópia de segurança selada com uma frase-passe que só você conhece. Nada é sincronizado, a menos que o leve consigo.';

  @override
  String get onboardingBackupLine => 'Selada com frase-passe, restaura-se em qualquer lado.';

  @override
  String get onboardingRecordTitle => 'Diz o que pensa, e fica escrito.';

  @override
  String get onboardingRecordBody =>
      'Cada palavra fica neste telemóvel. Sem conta, sem nuvem. O modo de voo não muda nada.';

  @override
  String get onboardingRecordText1 =>
      'Café com a Lia, e acabámos a falar da mudança durante duas horas.';

  @override
  String get onboardingRecordText2 =>
      'Digo sempre que quero uma vida mais pequena, e depois preencho todas as noites.';

  @override
  String get onboardingRecordText3 =>
      'Voltei a casa pelo caminho longo. A cidade estava sossegada, por uma vez.';

  @override
  String get onboardingRecordText4 =>
      'Depois fiquei sentado nos degraus um bocado sem fazer nada, e acho que era esse o ponto.';

  @override
  String get onboardingRecordText5 =>
      'O trabalho correu bem. Ninguém pediu nada que eu não pudesse dar.';

  @override
  String get onboardingRecordText6 => 'Amanhã quero ligar à mãe antes que fique tarde.';

  @override
  String get onboardingLanguageDownloads => 'Transfere-se uma vez e depois funciona offline.';

  @override
  String get onboardingLanguageBuiltIn => 'Incluído. Nada a transferir.';

  @override
  String get onboardingLanguageReady => 'Pronto, neste dispositivo.';

  @override
  String get onboardingLanguageLoading => 'A ler o seu idioma';

  @override
  String get onboardingPermissionsTitle => 'Conceder acesso';

  @override
  String get onboardingPermissionsBody =>
      'Tudo aqui funciona inteiramente no seu dispositivo. Começar pede o microfone e o reconhecimento de voz; ambos podem ser alterados mais tarde nas Definições.';

  @override
  String get onboardingMicName => 'Microfone';

  @override
  String get onboardingMicReason => 'Para gravar a sua voz.';

  @override
  String get onboardingSpeechName => 'Reconhecimento de fala';

  @override
  String get onboardingSpeechReason =>
      'Para transformar as suas gravações em texto, no dispositivo.';

  @override
  String onboardingReflectWeek(int number) {
    return 'Semana $number';
  }

  @override
  String get onboardingShapeObsidianName => 'Obsidian';

  @override
  String get onboardingShapeMarkdownNote => 'Um por cada';

  @override
  String get onboardingShapeObsidianNote => 'Cofre ligado';

  @override
  String get onboardingShapeWebNote => 'No browser';

  @override
  String get onboardingReflectionsOn => 'A Apple Intelligence está ativa.';

  @override
  String get onboardingReflectionsPreparing =>
      'A Apple Intelligence ainda está a preparar-se neste dispositivo.';

  @override
  String get onboardingReflectionsOff => 'Ative a Apple Intelligence nas Definições para as ter.';

  @override
  String get onboardingNext => 'Seguinte';

  @override
  String get onboardingStart => 'Começar';

  @override
  String get onboardingDone => 'Concluído';

  @override
  String get hintEntryMenu =>
      'Tudo o que esta entrada pode fazer está no menu aqui em cima: editar o texto, exportá-la, gravar mais.';

  @override
  String get settingsCache => 'Cache';

  @override
  String cacheRecordingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gravações',
      one: '$count gravação',
    );
    return '$_temp0';
  }

  @override
  String get cacheReclaimable => 'Recuperável';

  @override
  String get cacheReclaimableInfo => 'Transcrito, pode ser apagado';

  @override
  String get cacheUsageInfo =>
      'O áudio das entradas transcritas pode ser apagado; o texto fica. Gravações ainda não transcritas nunca são tocadas.';

  @override
  String get cacheKeepAudio => 'Manter áudio';

  @override
  String get cacheKeepAudioInfo =>
      'Desligado, cada gravação é apagada assim que a transcrição é concluída. Essas entradas ficam só com texto: sem reprodução e sem nova transcrição por um motor melhor.';

  @override
  String get cacheClear => 'Apagar áudio transcrito';

  @override
  String get cacheClearTitle => 'Apagar áudio transcrito?';

  @override
  String cacheClearBody(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Apaga o áudio de $count entradas transcritas ($size). O texto fica. Não é possível desfazer.',
      one:
          'Apaga o áudio de $count entrada transcrita ($size). O texto fica. Não é possível desfazer.',
    );
    return '$_temp0';
  }

  @override
  String get cacheClearConfirm => 'Apagar gravações';

  @override
  String get reflectionsTitle => 'Reflexões';

  @override
  String get reflectionPeriods => 'Períodos';

  @override
  String get reflectionDaily => 'Diárias';

  @override
  String get reflectionWeekly => 'Semanais';

  @override
  String get reflectionMonthly => 'Mensais';

  @override
  String get reflectionsEmptyTitle => 'Ainda sem reflexões';

  @override
  String get reflectionsEmptyBody =>
      'A primeira chega assim que tiver escrito no diário, relida a partir do que gravou.';

  @override
  String get reflectionQuietDay => 'Um dia tranquilo.';

  @override
  String get reflectionQuietWeek => 'Uma semana tranquila.';

  @override
  String get reflectionQuietMonth => 'Um mês tranquilo.';

  @override
  String get reflectionWaitingTitle => 'Ainda não escrita';

  @override
  String get reflectionWaitingBody =>
      'Esta será lida na próxima vez que o diário abrir com o Apple Intelligence pronto.';

  @override
  String get reflectionErasedTitle => 'Apagada';

  @override
  String get reflectionErasedBody => 'Removeu esta reflexão. Regenerar volta a escrevê-la.';

  @override
  String get reflectionQuietBody => 'Nada se tornou uma reflexão.';

  @override
  String reflectionWrittenOn(String date) {
    return 'Escrita a $date';
  }

  @override
  String reflectionOfPeriod(String range) {
    return 'Reflexão de $range';
  }

  @override
  String get reflectionVoice => 'Voz';

  @override
  String get reflectionVoiceLiterary => 'Literária';

  @override
  String get reflectionVoiceObservational => 'Observadora';

  @override
  String get reflectionVoiceSparse => 'Contida';

  @override
  String get reflectionLength => 'Extensão';

  @override
  String get reflectionLengthOneLine => 'Uma linha';

  @override
  String get reflectionLengthSentences => 'Algumas frases';

  @override
  String get reflectionLengthParagraph => 'Parágrafo curto';

  @override
  String get reflectionSpecifics => 'Detalhes';

  @override
  String get reflectionSpecificsNameFreely => 'Nomear detalhes';

  @override
  String get reflectionSpecificsThemes => 'Apenas temas';

  @override
  String get reflectionSpecificsLetPeriod => 'Deixar decidir';

  @override
  String get reflectionGenerateAll => 'Gerar reflexões';

  @override
  String get reflectionRegenerate => 'Regenerar';

  @override
  String get reflectionDeleteDay => 'Eliminar dia';

  @override
  String get reflectionDeleteWeek => 'Eliminar semana';

  @override
  String get reflectionDeleteMonth => 'Eliminar mês';

  @override
  String get reflectionRegenerateFailed => 'Não foi possível refletir. Tente novamente.';

  @override
  String get reflectionsDisabledTitle => 'As reflexões estão desativadas';

  @override
  String get reflectionsDisabledBody =>
      'Nada de novo será escrito enquanto as reflexões estiverem desativadas.';

  @override
  String get reflectionsDisabledEnable => 'Ativar';

  @override
  String get reflectionOffTitle => 'O Apple Intelligence está desligado';

  @override
  String get reflectionOffBody =>
      'Ative-o nas Definições, em Apple Intelligence e Siri, para receber reflexões.';

  @override
  String get reflectionPreparingTitle => 'A preparar';

  @override
  String get reflectionPreparingBody =>
      'O Apple Intelligence está a preparar-se neste dispositivo. As reflexões começam quando terminar.';

  @override
  String get reflectionUnsupportedTitle => 'Não disponível aqui';

  @override
  String get reflectionUnsupportedBody =>
      'Este dispositivo não suporta o Apple Intelligence, necessário para as reflexões.';

  @override
  String get settingsNotifications => 'Notificações';

  @override
  String get notifyReflectionReminders => 'Lembretes de reflexões';

  @override
  String get notifyPeriodDay => 'Dia';

  @override
  String get notifyPeriodWeek => 'Semana';

  @override
  String get notifyPeriodMonth => 'Mês';

  @override
  String get notifyReflectionsInfo =>
      'Um lembrete quando uma nova reflexão está pronta para ler. Surge no seu dispositivo; nada é enviado para lado nenhum.';

  @override
  String get notifyTime => 'Hora';

  @override
  String get notifyPermissionDenied => 'As notificações estão desativadas nas Definições.';

  @override
  String get notifyOpenSettings => 'Abrir Definições';

  @override
  String get notifyDailyTitle => 'O seu dia está pronto';

  @override
  String get notifyDailyBody => 'Abra para ler a reflexão de ontem.';

  @override
  String get notifyWeeklyTitle => 'A sua semana está pronta';

  @override
  String get notifyWeeklyBody => 'Abra para ler a reflexão da semana passada.';

  @override
  String get notifyMonthlyTitle => 'O seu mês está pronto';

  @override
  String get notifyMonthlyBody => 'Abra para ler a reflexão do mês passado.';

  @override
  String get notifyNeedsReflections =>
      'Os lembretes chegam quando uma nova reflexão está pronta para ler. As reflexões estão desativadas no momento.';

  @override
  String get notifyTurnOnReflections => 'Ativar reflexões';

  @override
  String get notifyReflectionsUnavailable =>
      'Este dispositivo não consegue gerar reflexões, portanto não há lembrete para enviar.';

  @override
  String get themeRequestInfo =>
      'Quer o OpenTranscribe num tema que não está aqui? Abra uma issue no GitHub e vamos adicioná-lo numa versão futura. Os temas adicionados são para membros do OpenTranscribe Club.';

  @override
  String get themeRequestLink => 'Pedir um tema no GitHub';

  @override
  String get exportEntry => 'Exportar';

  @override
  String get exportEntryTitle => 'Exportar a entrada';

  @override
  String get exportIncludeAudio => 'Incluir o áudio';

  @override
  String get exportFormatMarkdown => 'Markdown';

  @override
  String get exportFormatMarkdownNote => 'Uma nota por entrada, mais JSON.';

  @override
  String get exportFormatObsidian => 'Obsidian Vault';

  @override
  String get exportFormatObsidianNote => 'Notas com propriedades e áudio.';

  @override
  String get exportFormatWeb => 'Site web';

  @override
  String get exportFormatWebNote => 'Pesquisa e leitor, em qualquer navegador.';

  @override
  String get exportFailedTitle => 'A exportação falhou';

  @override
  String get exportFailedBody => 'Não foi possível preparar os ficheiros. Nada foi partilhado.';

  @override
  String get exportTooLargeBody =>
      'A exportação excede os 4 GB que um único ficheiro pode conter. Nada foi partilhado.';

  @override
  String get exportNoSpaceBody =>
      'Não há espaço livre suficiente para preparar os ficheiros. Nada foi partilhado.';

  @override
  String get exportCancel => 'Cancelar';

  @override
  String get exportUntitled => 'Sem título';

  @override
  String get exportTranscriptHeading => 'Transcrição';

  @override
  String get exportQuiet => 'Um período calmo.';

  @override
  String get exportHtmlSearch => 'Pesquisar';

  @override
  String get exportHtmlSchemeLabel => 'Esquema de cores';

  @override
  String get exportHtmlSchemeAuto => 'Auto';

  @override
  String get exportHtmlSchemeLight => 'Claro';

  @override
  String get exportHtmlSchemeDark => 'Escuro';

  @override
  String get exportHtmlEmptyTitle => 'Ainda nada por aqui';

  @override
  String get exportHtmlEmptyBody => 'Este diário não tem entradas.';

  @override
  String get exportHtmlNoMatchesTitle => 'Nada encontrado';

  @override
  String exportHtmlNoMatches(String term) {
    return 'Nenhuma entrada corresponde a «$term»';
  }

  @override
  String get exportHtmlPlay => 'Reproduzir';

  @override
  String get exportHtmlPause => 'Pausar';

  @override
  String get exportHtmlBack => 'Recuar 15 segundos';

  @override
  String get exportHtmlSpeed => 'Velocidade de reprodução';

  @override
  String get exportHtmlSeek => 'Posição';

  @override
  String get settingsBackup => 'Cópia de segurança';

  @override
  String get backupInfo =>
      'Uma cópia de segurança guarda cada entrada com o áudio e as reflexões. Se a encriptar, a frase-passe é a única chave.';

  @override
  String get backupInfoEmpty =>
      'Ainda não há nada para guardar. Uma cópia de segurança guarda cada entrada com o áudio e as reflexões.';

  @override
  String backupInfoMeasured(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Uma cópia de segurança guarda as suas $count entradas com o áudio e as reflexões, cerca de $size.',
      one:
          'Uma cópia de segurança guarda a sua única entrada com o áudio e as reflexões, cerca de $size.',
    );
    return '$_temp0 Se a encriptar, a frase-passe é a única chave.';
  }

  @override
  String get backupExportSection => 'Exportação';

  @override
  String backupExportAs(String format) {
    return 'Exportar como $format';
  }

  @override
  String get backupExportInfo =>
      'Escreve cada entrada num formato escolhido na altura da exportação, num zip para a folha de partilha. Uma cópia para outras apps; restaurar exige uma cópia de segurança.';

  @override
  String get backupSeal => 'Encriptar com frase-passe';

  @override
  String get backupSave => 'Exportar cópia de segurança';

  @override
  String backupLastBackup(String date) {
    return 'Última cópia $date';
  }

  @override
  String get passphraseCreateTitle => 'Encriptar a cópia de segurança';

  @override
  String get passphraseCreateBody =>
      'A frase-passe é a única chave. Não fica guardada em lado nenhum; sem ela, a cópia é ruído.';

  @override
  String get passphrasePlaceholder => 'Frase-passe';

  @override
  String get passphraseRepeatPlaceholder => 'Repetir a frase-passe';

  @override
  String get passphraseTooShort => 'Pelo menos 8 caracteres';

  @override
  String get passphraseMismatch => 'As frases-passe não coincidem';

  @override
  String get passphraseShow => 'Mostrar';

  @override
  String get passphraseHide => 'Ocultar';

  @override
  String get importUnlockTitle => 'Cópia de segurança encriptada';

  @override
  String get importUnlockBody =>
      'Introduza a frase-passe com que esta cópia de segurança foi encriptada.';

  @override
  String get importUnlock => 'Desbloquear';

  @override
  String get importWrongPassphrase =>
      'Não foi possível desbloquear. Frase-passe errada, ou ficheiro danificado.';

  @override
  String get importConfirmTitle => 'Restaurar esta cópia de segurança?';

  @override
  String get importConfirmBody =>
      'Acrescenta as entradas da cópia ao seu diário. Uma entrada que já existe passa a ter a versão da cópia, desfazendo as edições feitas desde então. Restaurar a mesma cópia duas vezes nunca duplica.';

  @override
  String get importConfirm => 'Restaurar';

  @override
  String get importSummaryTitle => 'Restauro concluído';

  @override
  String importSummaryAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entradas acrescentadas.',
      one: '1 entrada acrescentada.',
      zero: 'Nada de novo para acrescentar.',
    );
    return '$_temp0';
  }

  @override
  String importSummaryReplaced(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entradas foram substituídas pela versão da cópia.',
      one: '1 entrada foi substituída pela versão da cópia.',
    );
    return '$_temp0';
  }

  @override
  String importSummarySkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entradas já estavam no diário.',
      one: '1 entrada já estava no diário.',
    );
    return '$_temp0';
  }

  @override
  String importSummaryAudio(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gravações restauradas.',
      one: '1 gravação restaurada.',
    );
    return '$_temp0';
  }

  @override
  String importConfirmCounts(int count, int audio) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entradas',
      one: '1 entrada',
    );
    String _temp1 = intl.Intl.pluralLogic(
      audio,
      locale: localeName,
      other: '$audio gravações',
      one: '1 gravação',
      zero: 'sem gravações',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get importFailedTitle => 'O restauro falhou';

  @override
  String get importFailedBody =>
      'Não foi possível ler a cópia de segurança. Nada no diário foi alterado.';

  @override
  String get importNotArchive =>
      'Não é uma cópia de segurança OpenTranscribe. Nada no diário foi alterado.';

  @override
  String get importNewerVersion =>
      'Criado por uma versão mais recente da app. Atualize para o importar.';

  @override
  String get importRezipped =>
      'Esta cópia de segurança foi re-comprimida por outra ferramenta. Guarde uma nova e restaure essa.';

  @override
  String get done => 'Concluído';

  @override
  String get importFailedMidway =>
      'O restauro parou a meio. O que já foi restaurado mantém-se; restaure de novo para terminar.';

  @override
  String get settingsSupport => 'Apoiar';

  @override
  String get supportPitch =>
      'O clube é a forma de apoiar o OpenTranscribe: um único pagamento, para sempre, e alguns visuais como agradecimento.';

  @override
  String get supportPitchFree =>
      'Tudo o que torna o OpenTranscribe útil é gratuito para todos, e assim continua.';

  @override
  String get supportPerkThemes => 'Temas do clube';

  @override
  String get supportPerkThemesNote =>
      'Gruvbox, Dracula, Nord e todos os temas além do predefinido.';

  @override
  String get supportPerkIcons => 'Ícones da app';

  @override
  String get supportPerkIconsNote => 'Signal, Lines, Dots e todos os ícones além do predefinido.';

  @override
  String get supportThanks => 'Está no clube para sempre. Obrigado.';

  @override
  String supportJoin(String price) {
    return 'Entrar no clube por $price';
  }

  @override
  String get supportRestore => 'Restaurar compras';

  @override
  String get supportUnreachable =>
      'Não foi possível contactar a App Store. Feche e volte a abrir para tentar de novo.';

  @override
  String get supportPending => 'A aguardar aprovação. A compra termina assim que for aprovada.';

  @override
  String get supportRestoreNoneTitle => 'Nada a restaurar';

  @override
  String get supportRestoreNoneBody => 'Nenhuma compra do clube está associada a este ID Apple.';

  @override
  String get supportFailedTitle => 'Não foi concluído';

  @override
  String get supportFailedBody => 'A App Store não conseguiu concluir. Tente novamente.';

  @override
  String get supportPrivacy => 'política de privacidade';

  @override
  String get supportTerms => 'termos de utilização';

  @override
  String get supportUnlocksSection => 'O que recebe';

  @override
  String get supporterTag => 'Clube';

  @override
  String supportFooter(String privacy, String terms) {
    return 'Apoiar não muda nada na privacidade. O diário nunca sai do telemóvel, como diz a $privacy, e a compra segue os $terms padrão da Apple.';
  }

  @override
  String get continueRecording => 'Gravar mais';

  @override
  String continuingEntry(String title) {
    return 'A continuar $title';
  }

  @override
  String get continueUntranscribedLabel => 'Parte nova não transcrita';

  @override
  String get continueUntranscribedTitle => 'A parte nova não foi transcrita';

  @override
  String get continueUntranscribedBody =>
      'A gravação cresceu, mas as palavras que acabou de acrescentar não foram transcritas. Retranscreva para ouvir tudo.';

  @override
  String get continueSavedSeparatelyLabel => 'Guardado como nova entrada';

  @override
  String get continueSavedSeparatelyBody =>
      'A nova gravação não pôde ser junta a esta entrada, por isso foi guardada à parte.';

  @override
  String get continueEntryBusy => 'Esta entrada ainda está a ser transcrita.';
}
