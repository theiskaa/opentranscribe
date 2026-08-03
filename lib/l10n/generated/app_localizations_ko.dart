// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'OpenTranscribe';

  @override
  String get settingsOffline => '모든 것이 이 기기에만 남습니다. 계정도, 클라우드도, 네트워크도 없습니다.';

  @override
  String get entryUntranscribed => '미전사';

  @override
  String get entryUntranscribedTitle => '아직 전사되지 않음';

  @override
  String get entryUntranscribedMessage => '이 녹음을 다시 읽을 수 있는 텍스트로 바꿔 보세요. 기기에서 처리됩니다.';

  @override
  String get entryNoSpeechTitle => '표시할 내용이 없음';

  @override
  String get entryNoSpeechMessage => '이 녹음은 전사되었지만 음성이 발견되지 않았습니다.';

  @override
  String get retranscribe => '다시 전사';

  @override
  String get delete => '삭제';

  @override
  String get homeEmptyHeadline => '말하면, 글로 남습니다.';

  @override
  String get homeEmptySubtitle => '말하는 모든 내용이 전사되어 이 기기에 저장됩니다. 아래로 당겨 첫 기록을 녹음해 보세요.';

  @override
  String get homePullToRecord => '당겨서 녹음';

  @override
  String get menuSourceCode => '소스 코드';

  @override
  String get recordStateRecording => '녹음 중';

  @override
  String get recordStatePaused => '일시 정지됨';

  @override
  String get recordErrorMessage => '녹음 중 문제가 발생했습니다.';

  @override
  String get recordLiveUnavailable => '실시간 텍스트를 지금은 사용할 수 없습니다. 녹음은 안전하게 보관되며 끝나면 전사됩니다.';

  @override
  String get recordInterruptedSaved => '녹음이 중단되었습니다. 녹음본이 저장되었으며 기록에서 전사할 수 있습니다.';

  @override
  String get recordPermissionTitle => '마이크가 꺼져 있음';

  @override
  String get recordPermissionMessage => '\'설정\' 앱에서 opentranscribe의 마이크 접근을 허용한 뒤 다시 시도하세요.';

  @override
  String get rename => '이름 변경';

  @override
  String get transcribe => '전사';

  @override
  String get transcribeIn => '다른 언어로 전사…';

  @override
  String get playbackFailed => '재생을 지금은 사용할 수 없습니다.';

  @override
  String get transcribeErrorModelInstall =>
      '이 언어의 음성 모델을 가져오지 못했습니다. 연결과 여유 공간을 확인하거나 모델에서 언어를 관리하세요.';

  @override
  String get transcribeErrorPermission => '\'설정\' 앱에서 opentranscribe의 음성 인식을 허용한 뒤 다시 시도하세요.';

  @override
  String get transcribeErrorUnavailable => '이 기기에서는 이 언어의 온디바이스 전사를 사용할 수 없습니다.';

  @override
  String get transcribeErrorGeneric => '문제가 발생했습니다. 다시 시도하세요.';

  @override
  String get transcribeErrorCapReached => '언어 한도에 도달했습니다. 설정에서 언어를 하나 삭제한 뒤 다시 시도하세요.';

  @override
  String get transcribeErrorLabelPermission => '음성 인식이 꺼져 있음';

  @override
  String get transcribeErrorLabelUnavailable => '이 기기에서 사용 불가';

  @override
  String get transcribeErrorLabelModelInstall => '언어 모델을 가져오지 못함';

  @override
  String get transcribeErrorLabelCapReached => '언어 한도에 도달함';

  @override
  String get transcribeErrorLabelGeneric => '전사 실패';

  @override
  String get transcribeErrorTitlePermission => '음성 인식 켜기';

  @override
  String get transcribeErrorTitleUnavailable => '여기서는 사용 불가';

  @override
  String get transcribeErrorTitleModelInstall => '모델을 다운로드하지 못함';

  @override
  String get transcribeErrorTitleCapReached => '언어 한도에 도달함';

  @override
  String get transcribeErrorTitleGeneric => '문제가 발생함';

  @override
  String get settingsAppearance => '화면 표시';

  @override
  String get settingsTheme => '테마';

  @override
  String get themeSystem => '시스템';

  @override
  String get themeLight => '라이트';

  @override
  String get themeDark => '다크';

  @override
  String get themeNameDefault => '기본';

  @override
  String get themeNameGruvbox => 'Gruvbox';

  @override
  String get themeNameSolarized => 'Solarized';

  @override
  String get themeNameSepia => '세피아';

  @override
  String get settingsAppLanguage => '언어';

  @override
  String get transcriptionInfo =>
      '각 언어는 자체 온디바이스 모델로 실행되며, 한 번 다운로드하면 시스템과 공유됩니다. 모델은 이 앱의 저장 공간에 포함되지 않습니다. 시스템은 앱이 한 번에 준비해 둘 수 있는 언어 수를 제한합니다.';

  @override
  String transcriptionCap(int used, int max) {
    return '언어 슬롯 $max개 중 $used개 사용 중';
  }

  @override
  String get transcriptionRemoveHint => '언어를 왼쪽으로 밀어 삭제하세요.';

  @override
  String get transcriptionErrorUnsupported => '이 언어는 아직 이 기기에서 다운로드할 수 없습니다.';

  @override
  String get transcriptionErrorStuck =>
      '이전 다운로드가 아직 대기 중입니다. 시스템이 조건이 좋아지면 다시 시도하며, 다시 시도해도 안전합니다.';

  @override
  String get transcriptionErrorGeneric => '다운로드에 실패했습니다. 연결과 여유 공간을 확인한 뒤 다시 시도하세요.';

  @override
  String get transcriptionErrorCap => '언어 한도에 도달했습니다. 이 언어를 추가하려면 언어를 하나 삭제하세요.';

  @override
  String get transcriptionErrorRemove => '이 언어를 삭제하지 못했습니다. 다시 시도하세요.';

  @override
  String get transcriptionDownloading => '다운로드 중';

  @override
  String get retry => '다시 시도';

  @override
  String get modelFailCapTitle => '언어 한도에 도달함';

  @override
  String modelFailCapBody(String language) {
    return '시스템은 앱이 한 번에 준비해 둘 수 있는 언어 수를 제한합니다. $language을(를) 위한 공간을 만들려면 아래에서 하나를 삭제하세요.';
  }

  @override
  String get modelFailUnsupportedTitle => '아직 사용 불가';

  @override
  String modelFailUnsupportedBody(String language) {
    return '이 기기에는 아직 $language의 온디바이스 모델이 없습니다. 시스템 업데이트로 제공될 수 있습니다.';
  }

  @override
  String get modelFailStuckTitle => '아직 다운로드 중';

  @override
  String modelFailStuckBody(String language) {
    return '$language의 이전 다운로드가 아직 대기 중입니다. 시스템이 조건이 좋아지면 다시 시도하며, 다시 요청해도 안전합니다.';
  }

  @override
  String get modelFailGenericTitle => '다운로드하지 못함';

  @override
  String modelFailGenericBody(String language) {
    return '$language 모델을 다운로드하지 못했습니다. 연결과 여유 공간을 확인한 뒤 다시 시도하세요.';
  }

  @override
  String get modelFailRemoveTitle => '삭제하지 못함';

  @override
  String modelFailRemoveBody(String language) {
    return '시스템이 $language을(를) 해제하지 않았습니다. 다시 시도해도 안전합니다.';
  }

  @override
  String get settingsModels => '전사';

  @override
  String get transcriptionLanguages => '언어';

  @override
  String get transcriptionDefaultTag => '기본';

  @override
  String get transcriptionDefaultHint => '언어를 길게 눌러 기본으로 설정하세요.';

  @override
  String transcriptionDeviceLanguageFallback(String fallback) {
    return '휴대폰 언어는 아직 온디바이스 전사를 지원하지 않아 $fallback이(가) 기본으로 설정됩니다.';
  }

  @override
  String get onboardingIntroBody => '생각을 말하면, 글로 적어 줍니다.';

  @override
  String get onboardingSpeakTitle => '그냥 말하세요';

  @override
  String get onboardingSpeakLine => '녹음을 누르고 마음에 있는 것을 말하세요.';

  @override
  String get onboardingWriteTitle => '다시 읽어 보세요';

  @override
  String get onboardingWriteLine => '모든 녹음이 텍스트로 기록됩니다.';

  @override
  String get onboardingPrivateTitle => '무엇도 기기를 떠나지 않음';

  @override
  String get onboardingPrivateLine => '계정도, 클라우드도 없습니다. 비행기 모드에서도 그대로 동작합니다.';

  @override
  String get onboardingReflectTitle => '주간 돌아보기';

  @override
  String get onboardingReflectLine => '일주일에 한 번, 기록이 짧은 노트로 정리됩니다. 모두 이 기기에서.';

  @override
  String get onboardingSource => '오픈 소스';

  @override
  String get onboardingSourceLine => '모든 코드가 공개되어 있습니다. GitHub에서 확인하세요.';

  @override
  String get onboardingPermissionsTitle => '접근 허용';

  @override
  String get onboardingPermissionsBody => '모든 기능이 전적으로 기기에서 처리됩니다.';

  @override
  String get onboardingMicName => '마이크';

  @override
  String get onboardingMicReason => '음성을 녹음하기 위해서입니다.';

  @override
  String get onboardingSpeechName => '음성 인식';

  @override
  String get onboardingSpeechReason => '녹음을 기기에서 텍스트로 바꾸기 위해서입니다.';

  @override
  String get onboardingNotifyName => '알림';

  @override
  String get onboardingNotifyReason => '돌아보기가 준비되면 주간 알림을 보내드립니다.';

  @override
  String get onboardingAllow => '허용';

  @override
  String get onboardingOpenSettings => '설정에서 사용 설정';

  @override
  String get onboardingModelsTitle => '언어 다운로드';

  @override
  String get onboardingModelsBody => '언어가 기기에 있으면 전사가 오프라인으로 실행됩니다. 메뉴에서 언제든 더 추가할 수 있습니다.';

  @override
  String get onboardingReflectionsOn => '일주일에 한 번, 기록을 짧은 돌아보기로 정리합니다. 모두 이 기기에서 이루어집니다.';

  @override
  String get onboardingReflectionsPreparing => '이 기기에서 Apple Intelligence 준비가 끝나면 시작됩니다.';

  @override
  String get onboardingReflectionsOff => '\'설정\'의 \'Apple Intelligence 및 Siri\'에서 켜면 이용할 수 있습니다.';

  @override
  String get onboardingNext => '다음';

  @override
  String get onboardingStart => '시작하기';

  @override
  String get settingsCache => '캐시';

  @override
  String cacheRecordingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '녹음 $count개');
    return '$_temp0';
  }

  @override
  String get cacheReclaimable => '확보 가능';

  @override
  String get cacheReclaimableInfo => '전사됨, 지워도 안전';

  @override
  String get cacheUsageInfo => '전사된 항목의 오디오는 지울 수 있으며 텍스트는 남습니다. 아직 전사되지 않은 녹음은 절대 건드리지 않습니다.';

  @override
  String get cacheKeepAudio => '오디오 보관';

  @override
  String get cacheKeepAudioInfo =>
      '끄면 전사가 성공한 녹음은 즉시 삭제됩니다. 해당 항목은 텍스트만 남아 재생할 수 없고, 나중에 더 나은 엔진으로 다시 전사할 수도 없습니다.';

  @override
  String get cacheClear => '전사된 오디오 지우기';

  @override
  String get cacheClearTitle => '전사된 오디오를 지울까요?';

  @override
  String cacheClearBody(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '전사된 항목 $count개의 오디오($size)를 삭제합니다. 텍스트는 남습니다. 되돌릴 수 없습니다.',
    );
    return '$_temp0';
  }

  @override
  String get cacheClearConfirm => '녹음 삭제';

  @override
  String get reflectionsTitle => '돌아보기';

  @override
  String get reflectionPeriodDay => 'Day';

  @override
  String get reflectionPeriodWeek => 'Week';

  @override
  String get reflectionPeriodMonth => 'Month';

  @override
  String get reflectionDaily => 'Daily';

  @override
  String get reflectionWeekly => 'Weekly';

  @override
  String get reflectionMonthly => 'Monthly';

  @override
  String get reflectionsEmptyTitle => '아직 돌아보기가 없습니다';

  @override
  String get reflectionsEmptyBody => '첫 돌아보기는 이번 주가 끝나면 도착하며, 기록한 내용을 되짚어 만들어집니다.';

  @override
  String get reflectionQuietWeek => '조용한 한 주.';

  @override
  String get reflectionWaitingTitle => '아직 작성되지 않음';

  @override
  String get reflectionWaitingBody => 'Apple Intelligence가 준비된 상태로 저널을 다시 열면 이 주를 돌아봅니다.';

  @override
  String get reflectionErasedTitle => '지움';

  @override
  String get reflectionErasedBody => '이 주의 돌아보기를 삭제했습니다. 다시 생성하면 다시 작성됩니다.';

  @override
  String get reflectionQuietBody => '돌아볼 만한 것이 없었습니다.';

  @override
  String reflectionWrittenOn(String date) {
    return '$date에 작성됨';
  }

  @override
  String reflectionOfWeek(String range) {
    return '$range 돌아보기';
  }

  @override
  String get reflectionVoice => '문체';

  @override
  String get reflectionVoiceLiterary => '문학적';

  @override
  String get reflectionVoiceObservational => '관찰적';

  @override
  String get reflectionVoiceSparse => '간결';

  @override
  String get reflectionLength => '길이';

  @override
  String get reflectionLengthOneLine => '한 줄';

  @override
  String get reflectionLengthSentences => '몇 문장';

  @override
  String get reflectionLengthParagraph => '짧은 문단';

  @override
  String get reflectionSpecifics => '구체성';

  @override
  String get reflectionSpecificsNameFreely => '구체적으로 쓰기';

  @override
  String get reflectionSpecificsThemes => '주제만';

  @override
  String get reflectionSpecificsLetWeek => '이번 주에 맡기기';

  @override
  String get reflectionRegenerate => '다시 생성';

  @override
  String get reflectionDelete => '삭제';

  @override
  String get reflectionRegenerateFailed => '돌아보기를 만들지 못했습니다. 다시 시도하세요.';

  @override
  String get reflectionsDisabledTitle => '돌아보기가 꺼져 있습니다';

  @override
  String get reflectionsDisabledBody => '진행 중인 주는 주가 끝나도 작성되지 않습니다.';

  @override
  String get reflectionsDisabledEnable => '켜기';

  @override
  String get reflectionOffTitle => 'Apple Intelligence가 꺼져 있습니다';

  @override
  String get reflectionOffBody => '주간 돌아보기를 받으려면 \'설정\'의 \'Apple Intelligence 및 Siri\'에서 켜세요.';

  @override
  String get reflectionPreparingTitle => '준비 중';

  @override
  String get reflectionPreparingBody =>
      '이 기기에서 Apple Intelligence를 준비하고 있습니다. 준비가 끝나면 돌아보기가 시작됩니다.';

  @override
  String get reflectionUnsupportedTitle => '여기서는 사용할 수 없습니다';

  @override
  String get reflectionUnsupportedBody => '이 기기는 주간 돌아보기에 필요한 Apple Intelligence를 지원하지 않습니다.';

  @override
  String get settingsNotifications => '알림';

  @override
  String get notifyWeeklyReflection => '주간 돌아보기';

  @override
  String get notifyWeeklyReflectionInfo => '새로운 한 주를 읽을 수 있을 때 알려줍니다. 기기에서 실행되며 어디로도 전송되지 않습니다.';

  @override
  String get notifyTime => '시간';

  @override
  String get notifyPermissionDenied => '설정에서 알림이 꺼져 있습니다.';

  @override
  String get notifyOpenSettings => '설정 열기';

  @override
  String get notifyWeeklyTitle => '이번 주가 준비되었어요';

  @override
  String get notifyWeeklyBody => '열어서 이번 주 돌아보기를 읽어보세요.';

  @override
  String get notifyNeedsReflections => '새로운 한 주를 읽을 수 있을 때 주간 알림이 도착합니다. 지금은 돌아보기가 꺼져 있습니다.';

  @override
  String get notifyTurnOnReflections => '돌아보기 켜기';

  @override
  String get notifyReflectionsUnavailable => '이 기기는 돌아보기를 생성할 수 없어 보낼 주간 알림이 없습니다.';

  @override
  String get themeRequestInfo =>
      '여기에 없는 테마로 OpenTranscribe를 사용하고 싶나요? GitHub에 이슈를 남겨 주시면 다음 릴리스에서 추가하겠습니다.';

  @override
  String get themeRequestLink => 'GitHub에서 테마 요청하기';
}
