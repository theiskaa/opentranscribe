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
  String get themeNameSolarized => 'Solarized';

  @override
  String get themeNameSepia => 'Sépia';

  @override
  String get settingsAppLanguage => 'Idioma';

  @override
  String get transcriptionInfo =>
      'Cada idioma corre o seu próprio modelo no dispositivo, transferido uma vez e partilhado com o sistema; os modelos não contam para o armazenamento desta app. O sistema limita quantos idiomas uma app pode manter prontos de cada vez.';

  @override
  String transcriptionCap(int used, int max) {
    return '$used de $max lugares de idioma usados';
  }

  @override
  String get transcriptionRemoveHint => 'Deslize para a esquerda num idioma para o remover.';

  @override
  String get transcriptionErrorUnsupported =>
      'Este idioma ainda não pode ser transferido neste dispositivo.';

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
  String get transcriptionLanguages => 'Idiomas';

  @override
  String get transcriptionDefaultTag => 'Predefinido';

  @override
  String get transcriptionDefaultHint =>
      'Toque e mantenha premido um idioma para o tornar predefinido.';

  @override
  String transcriptionDeviceLanguageFallback(String fallback) {
    return 'O idioma do seu telemóvel ainda não é suportado para transcrição no dispositivo, por isso $fallback é o predefinido.';
  }

  @override
  String get onboardingIntroBody => 'Diz o que pensa, e fica escrito.';

  @override
  String get onboardingSpeakTitle => 'Basta falar';

  @override
  String get onboardingSpeakLine => 'Toque em gravar e diga o que lhe vai na mente.';

  @override
  String get onboardingWriteTitle => 'Releia depois';

  @override
  String get onboardingWriteLine => 'Cada gravação fica escrita em texto.';

  @override
  String get onboardingPrivateTitle => 'Nada sai do telemóvel';

  @override
  String get onboardingPrivateLine => 'Sem conta, sem nuvem. O modo de voo não muda nada.';

  @override
  String get onboardingReflectTitle => 'Reflexões';

  @override
  String get onboardingReflectLine =>
      'As suas entradas voltam como uma nota breve, tudo no dispositivo.';

  @override
  String get onboardingSource => 'Código aberto';

  @override
  String get onboardingSourceLine => 'Cada linha é pública. Leia no GitHub.';

  @override
  String get onboardingPermissionsTitle => 'Conceder acesso';

  @override
  String get onboardingPermissionsBody => 'Tudo isto funciona inteiramente no seu dispositivo.';

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
  String get onboardingOpenSettings => 'Ativar nas Definições';

  @override
  String get onboardingModelsTitle => 'Configurar a transcrição';

  @override
  String get onboardingModelsBody =>
      'Corre offline assim que o seu idioma estiver no dispositivo. Pode adicionar mais a qualquer momento a partir do menu.';

  @override
  String get onboardingReflectionsOn =>
      'As suas entradas tornam-se uma breve reflexão, inteiramente neste dispositivo.';

  @override
  String get onboardingReflectionsPreparing =>
      'Começa assim que o Apple Intelligence estiver pronto neste dispositivo.';

  @override
  String get onboardingReflectionsOff =>
      'Ative o Apple Intelligence nas Definições, em Apple Intelligence e Siri, para as receber.';

  @override
  String get onboardingNext => 'Seguinte';

  @override
  String get onboardingStart => 'Começar';

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
      'Quer o OpenTranscribe num tema que não está aqui? Abra uma issue no GitHub e vamos adicioná-lo numa versão futura.';

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
  String get exportFormatMarkdownNote => 'Um ficheiro de texto por entrada e .json.';

  @override
  String get exportFormatObsidian => 'Obsidian';

  @override
  String get exportFormatObsidianNote => 'Notas com propriedades e áudio.';

  @override
  String get exportFormatWeb => 'Site web';

  @override
  String get exportFormatWebNote => 'Abre em qualquer navegador, com leitor.';

  @override
  String get exportFailedTitle => 'A exportação falhou';

  @override
  String get exportFailedBody => 'Não foi possível preparar os ficheiros. Nada foi partilhado.';

  @override
  String get exportUntitled => 'Sem título';

  @override
  String get exportTranscriptHeading => 'Transcrição';

  @override
  String get exportQuiet => 'Um período calmo.';

  @override
  String get settingsBackup => 'Cópia de segurança';

  @override
  String get backupInfo =>
      'Uma cópia de segurança guarda cada entrada com o áudio e as reflexões. Se a encriptar, a frase-passe é a única chave.';

  @override
  String backupInfoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Uma cópia de segurança guarda as suas $count entradas com o áudio e as reflexões. Se a encriptar, a frase-passe é a única chave.',
      one:
          'Uma cópia de segurança guarda a sua única entrada com o áudio e as reflexões. Se a encriptar, a frase-passe é a única chave.',
      zero:
          'Ainda não há nada para guardar. Uma cópia de segurança guarda cada entrada com o áudio e as reflexões.',
    );
    return '$_temp0';
  }

  @override
  String get backupExportSection => 'Exportação';

  @override
  String get backupExportJournal => 'Exportar o diário';

  @override
  String get backupExportInfo =>
      'Escreve cada entrada no formato escolhido, áudio incluído, num zip para a folha de partilha. Uma cópia para outras apps; restaurar exige uma cópia de segurança.';

  @override
  String get backupSeal => 'Encriptar com frase-passe';

  @override
  String get backupSave => 'Guardar cópia de segurança';

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
      'Acrescenta as entradas da cópia ao seu diário. Restaurar a mesma cópia duas vezes nunca duplica.';

  @override
  String get importConfirm => 'Restaurar';

  @override
  String get importSummaryTitle => 'Restauro concluído';

  @override
  String importSummaryImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entradas restauradas.',
      one: '1 entrada restaurada.',
      zero: 'Nada de novo para restaurar.',
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
  String get supportGateTitle => 'Uma funcionalidade do clube';

  @override
  String get supportGateBody =>
      'As exportações formatadas são desbloqueadas ao apoiar o OpenTranscribe. A cópia de segurança continua gratuita.';

  @override
  String get supportGateAction => 'Apoiar a app';

  @override
  String get settingsSupport => 'Apoiar';

  @override
  String get supportPitch =>
      'O OpenTranscribe é gratuito e privado, e apoiá-lo mantém-no assim. Hoje, entrar no clube desbloqueia as exportações formatadas. As novidades chegam primeiro ao clube, e algumas serão só dele.';

  @override
  String get supportThanksMonthly => 'Está no clube. Obrigado.';

  @override
  String get supportThanksLifetime => 'Está no clube para sempre. Obrigado.';

  @override
  String get supportMonthly => 'Mensal';

  @override
  String get supportLifetime => 'Vitalício';

  @override
  String supportPerMonth(String price) {
    return '$price por mês';
  }

  @override
  String supportOnce(String price) {
    return '$price uma vez';
  }

  @override
  String get supportManage => 'Gerir subscrição';

  @override
  String get supportRestore => 'Restaurar compras';

  @override
  String get supportUnreachable =>
      'Não foi possível contactar a App Store. Os preços aparecem assim que for possível.';

  @override
  String get supportUpgradeInfo =>
      'O vitalício cobre tudo a partir daí. A subscrição mensal cancela-se em Gerir subscrição.';

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
  String get supportUnlocksSection => 'Para membros do clube';

  @override
  String get supporterTag => 'Club';

  @override
  String supportFooter(String privacy, String terms) {
    return 'Apoiar não muda nada na privacidade. O diário nunca sai do telemóvel, como diz a $privacy, e a subscrição segue os $terms padrão da Apple.';
  }
}
