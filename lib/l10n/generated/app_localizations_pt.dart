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
  String get settingsOffline => 'Tudo permanece neste dispositivo. Sem conta, sem nuvem, sem rede.';

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
  String get menuTranscriptionLanguage => 'Transcrição';

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
  String get settingsModels => 'Modelos';

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
  String get onboardingSource => 'Código aberto';

  @override
  String get onboardingSourceLine => 'Cada linha é pública. Leia no GitHub.';

  @override
  String get onboardingPermissionsTitle => 'Conceder acesso';

  @override
  String get onboardingPermissionsBody => 'Ambos funcionam inteiramente no seu dispositivo.';

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
  String get onboardingAllow => 'Permitir';

  @override
  String get onboardingOpenSettings => 'Ativar nas Definições';

  @override
  String get onboardingModelsTitle => 'Transferir um idioma';

  @override
  String get onboardingModelsBody =>
      'A transcrição corre offline assim que um idioma estiver no seu dispositivo. Pode adicionar mais a qualquer momento a partir do menu.';

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
      one: '1 gravação',
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
          'Apaga o áudio de uma entrada transcrita ($size). O texto fica. Não é possível desfazer.',
    );
    return '$_temp0';
  }

  @override
  String get cacheClearConfirm => 'Apagar gravações';
}
