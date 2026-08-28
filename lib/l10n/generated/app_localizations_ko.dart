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
  String get launchFailedTitle => '시작하지 못했습니다';

  @override
  String get launchFailedBody =>
      '실행에 필요한 것을 불러오지 못했습니다. 앱 전환기에서 앱을 종료한 뒤 다시 열어 보세요. 그래도 안 되면 기기를 재시작하세요.';

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
  String get retranscribeAllTitle => '모두 다시 전사';

  @override
  String get retranscribeRowQueued => '다시 전사할 항목';

  @override
  String get retranscribeRowCurrent => '이미 최신';

  @override
  String get retranscribeRowLanded => '다시 전사됨';

  @override
  String get retranscribeRowFailed => '실패';

  @override
  String get retranscribeHistoryNote => '대체된 문구는 각 항목의 기록에 남습니다.';

  @override
  String get retranscribeFailedNote => '실패한 항목은 다음 실행 때 다시 처리됩니다.';

  @override
  String retranscribeAllCurrentBody(String engine) {
    return '보관된 모든 녹음이 이미 $engine 엔진으로 전사되어 있습니다.';
  }

  @override
  String get retranscribeStart => '시작';

  @override
  String retranscribeProgressOf(int done, int total) {
    return '$total개 중 $done개';
  }

  @override
  String get retranscribeWaitingRecording => '녹음이 끝날 때까지 일시 정지';

  @override
  String get retranscribeWaitingThermal => '기기 온도가 내려갈 때까지 일시 정지';

  @override
  String get retranscribeCancel => '취소';

  @override
  String get retranscribeCancelledNote => '도중에 중지되었습니다. 다시 실행하면 이어서 진행됩니다.';

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
  String get editTranscript => '편집';

  @override
  String get editedMarker => '편집됨';

  @override
  String get revisionHistory => '기록';

  @override
  String get revisionHistoryBody => '이 항목의 텍스트가 거쳐 온 모든 버전입니다. 탭하면 해당 버전이 최신으로 복원됩니다.';

  @override
  String get revisionCurrent => '현재';

  @override
  String get revisionTranscribed => '전사됨';

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
  String get themeNameMidnight => 'Midnight';

  @override
  String get themeNameEmber => 'Ember';

  @override
  String get themeNameForest => 'Forest';

  @override
  String get appearanceClubSection => '클럽';

  @override
  String get settingsAppLanguage => '언어';

  @override
  String transcriptionCap(int used, int max) {
    return '언어 슬롯 $max개 중 $used개 사용 중';
  }

  @override
  String get transcriptionErrorUnsupported => '이 언어는 아직 이 기기에서 다운로드할 수 없습니다.';

  @override
  String get languageNeedsDictation => 'iOS 키보드 설정에서 이 언어의 받아쓰기를 켜세요.';

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
  String get modelFailDictationTitle => '받아쓰기가 설정되지 않음';

  @override
  String modelFailDictationBody(String language) {
    return '$language은(는) 시스템 받아쓰기 모델로 전사되는데, 이 iPhone에는 아직 없습니다. iOS 설정에서 키보드를 추가하고 받아쓰기를 켜세요.';
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
  String get transcriptionYourLanguages => '내 언어';

  @override
  String get transcriptionAllLanguages => '모든 언어';

  @override
  String get transcriptionSpeaking => '말하는 언어';

  @override
  String get transcriptionAlsoReady => '준비된 다른 언어';

  @override
  String get transcriptionAddLanguage => '추가';

  @override
  String transcriptionHeroReady(String engine) {
    return '준비 완료 · $engine';
  }

  @override
  String get transcriptionFootnote => '모델은 한 번만 다운로드되며 시스템과 공유됩니다.';

  @override
  String get transcriptionEngines => '엔진';

  @override
  String get engineBlurbSpeechAnalyzer => 'Apple의 최신 엔진, 언어마다 모델을 다운로드';

  @override
  String get engineBlurbDictation => 'iOS 키보드 받아쓰기에 쓰이는 인식 엔진';

  @override
  String get engineUnavailableNote => '이 iPhone에서는 사용할 수 없음';

  @override
  String get engineUnavailableTitle => '이 iPhone에서는 사용할 수 없음';

  @override
  String engineUnavailableBody(String engine) {
    return '$engine은(는) iOS 26과 최신 iPhone이 필요합니다. 녹음은 사용 가능한 엔진으로 계속됩니다.';
  }

  @override
  String get engineBusyTitle => '녹음 진행 중';

  @override
  String get engineBusyBody => '녹음을 중지한 다음 엔진을 전환하세요.';

  @override
  String get engineRetranscribingTitle => '다시 전사 진행 중';

  @override
  String get engineRetranscribingBody => '작업이 끝날 때까지 기다리거나 취소한 다음 엔진을 전환하세요.';

  @override
  String get engineNotSavedTitle => '선택을 저장하지 못함';

  @override
  String get engineNotSavedBody => '엔진 선택을 저장하지 못해 다시 시작하면 유지되지 않습니다.';

  @override
  String get transcriptionDefaultTag => '기본';

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
  String get onboardingReflectTitle => '돌아보기';

  @override
  String get onboardingReflectLine => '기록이 짧은 노트로 정리됩니다. 모두 이 기기에서.';

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
  String get onboardingOpenSettings => '설정에서 사용 설정';

  @override
  String get onboardingModelsTitle => '전사 설정';

  @override
  String get onboardingModelsBody => '사용하는 언어가 기기에 있으면 전사가 오프라인으로 실행됩니다. 메뉴에서 언제든 더 추가할 수 있습니다.';

  @override
  String get onboardingReflectionsOn => '기록을 짧은 돌아보기로 정리합니다. 모두 이 기기에서 이루어집니다.';

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
  String get reflectionPeriods => '기간';

  @override
  String get reflectionDaily => '매일';

  @override
  String get reflectionWeekly => '매주';

  @override
  String get reflectionMonthly => '매월';

  @override
  String get reflectionsEmptyTitle => '아직 돌아보기가 없습니다';

  @override
  String get reflectionsEmptyBody => '첫 돌아보기는 기록을 시작하면 도착하며, 기록한 내용을 되짚어 만들어집니다.';

  @override
  String get reflectionQuietDay => '조용한 하루.';

  @override
  String get reflectionQuietWeek => '조용한 한 주.';

  @override
  String get reflectionQuietMonth => '조용한 한 달.';

  @override
  String get reflectionWaitingTitle => '아직 작성되지 않음';

  @override
  String get reflectionWaitingBody => 'Apple Intelligence가 준비된 상태로 저널을 다시 열면 이 내용을 돌아봅니다.';

  @override
  String get reflectionErasedTitle => '지움';

  @override
  String get reflectionErasedBody => '이 돌아보기를 삭제했습니다. 다시 생성하면 다시 작성됩니다.';

  @override
  String get reflectionQuietBody => '돌아볼 만한 것이 없었습니다.';

  @override
  String reflectionWrittenOn(String date) {
    return '$date에 작성됨';
  }

  @override
  String reflectionOfPeriod(String range) {
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
  String get reflectionSpecificsLetPeriod => '알아서 정하도록';

  @override
  String get reflectionGenerateAll => '돌아보기 생성';

  @override
  String get reflectionRegenerate => '다시 생성';

  @override
  String get reflectionDeleteDay => '하루 삭제';

  @override
  String get reflectionDeleteWeek => '한 주 삭제';

  @override
  String get reflectionDeleteMonth => '한 달 삭제';

  @override
  String get reflectionRegenerateFailed => '돌아보기를 만들지 못했습니다. 다시 시도하세요.';

  @override
  String get reflectionsDisabledTitle => '돌아보기가 꺼져 있습니다';

  @override
  String get reflectionsDisabledBody => '돌아보기가 꺼져 있는 동안에는 새로운 내용이 작성되지 않습니다.';

  @override
  String get reflectionsDisabledEnable => '켜기';

  @override
  String get reflectionOffTitle => 'Apple Intelligence가 꺼져 있습니다';

  @override
  String get reflectionOffBody => '돌아보기를 받으려면 \'설정\'의 \'Apple Intelligence 및 Siri\'에서 켜세요.';

  @override
  String get reflectionPreparingTitle => '준비 중';

  @override
  String get reflectionPreparingBody =>
      '이 기기에서 Apple Intelligence를 준비하고 있습니다. 준비가 끝나면 돌아보기가 시작됩니다.';

  @override
  String get reflectionUnsupportedTitle => '여기서는 사용할 수 없습니다';

  @override
  String get reflectionUnsupportedBody => '이 기기는 돌아보기에 필요한 Apple Intelligence를 지원하지 않습니다.';

  @override
  String get settingsNotifications => '알림';

  @override
  String get notifyReflectionReminders => '돌아보기 알림';

  @override
  String get notifyPeriodDay => '일';

  @override
  String get notifyPeriodWeek => '주';

  @override
  String get notifyPeriodMonth => '월';

  @override
  String get notifyReflectionsInfo => '새로운 돌아보기를 읽을 수 있을 때 알려줍니다. 기기에서 실행되며 어디로도 전송되지 않습니다.';

  @override
  String get notifyTime => '시간';

  @override
  String get notifyPermissionDenied => '설정에서 알림이 꺼져 있습니다.';

  @override
  String get notifyOpenSettings => '설정 열기';

  @override
  String get notifyDailyTitle => '어제 하루가 준비되었어요';

  @override
  String get notifyDailyBody => '열어서 어제의 돌아보기를 읽어보세요.';

  @override
  String get notifyWeeklyTitle => '이번 주가 준비되었어요';

  @override
  String get notifyWeeklyBody => '열어서 지난주 돌아보기를 읽어보세요.';

  @override
  String get notifyMonthlyTitle => '지난달이 준비되었어요';

  @override
  String get notifyMonthlyBody => '열어서 지난달 돌아보기를 읽어보세요.';

  @override
  String get notifyNeedsReflections => '새로운 돌아보기를 읽을 수 있을 때 알림이 도착합니다. 지금은 돌아보기가 꺼져 있습니다.';

  @override
  String get notifyTurnOnReflections => '돌아보기 켜기';

  @override
  String get notifyReflectionsUnavailable => '이 기기는 돌아보기를 생성할 수 없어 보낼 알림이 없습니다.';

  @override
  String get themeRequestInfo =>
      '여기에 없는 테마로 OpenTranscribe를 사용하고 싶나요? GitHub에 이슈를 남겨 주시면 다음 릴리스에서 추가하겠습니다.';

  @override
  String get themeRequestLink => 'GitHub에서 테마 요청하기';

  @override
  String get exportEntry => '내보내기';

  @override
  String get exportEntryTitle => '항목 내보내기';

  @override
  String get exportIncludeAudio => '오디오 포함';

  @override
  String get exportFormatMarkdown => 'Markdown';

  @override
  String get exportFormatMarkdownNote => '항목마다 텍스트 파일 하나와 .json.';

  @override
  String get exportFormatObsidian => 'Obsidian';

  @override
  String get exportFormatObsidianNote => '속성과 오디오가 담긴 노트.';

  @override
  String get exportFormatWeb => '웹사이트';

  @override
  String get exportFormatWebNote => '어떤 브라우저에서나 열립니다. 재생 지원.';

  @override
  String get exportFailedTitle => '내보내기 실패';

  @override
  String get exportFailedBody => '파일을 준비하지 못했습니다. 아무것도 공유되지 않았습니다.';

  @override
  String get exportUntitled => '제목 없음';

  @override
  String get exportTranscriptHeading => '텍스트 변환';

  @override
  String get exportQuiet => '조용한 시간.';

  @override
  String get settingsBackup => '백업';

  @override
  String get backupInfo => '백업에는 모든 항목과 오디오, 돌아보기가 담깁니다. 암호화하면 암호구가 유일한 열쇠입니다.';

  @override
  String backupInfoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '백업에는 항목 $count개와 오디오, 돌아보기가 담깁니다. 암호화하면 암호구가 유일한 열쇠입니다.',
      zero: '아직 백업할 것이 없습니다. 백업에는 항목과 오디오, 돌아보기가 담깁니다.',
    );
    return '$_temp0';
  }

  @override
  String get backupExportSection => '내보내기';

  @override
  String get backupExportJournal => '저널 내보내기';

  @override
  String get backupExportInfo =>
      '모든 항목을 선택한 형식으로, 오디오까지 zip으로 묶어 공유 시트로 전달합니다. 다른 앱에서 읽기 위한 사본이며, 복원에는 백업이 필요합니다.';

  @override
  String get backupSeal => '암호구로 암호화';

  @override
  String get backupSave => '백업 저장';

  @override
  String backupLastBackup(String date) {
    return '마지막 백업 $date';
  }

  @override
  String get passphraseCreateTitle => '백업 암호화';

  @override
  String get passphraseCreateBody => '암호구가 유일한 열쇠입니다. 어디에도 저장되지 않으며, 없으면 백업은 잡음일 뿐입니다.';

  @override
  String get passphrasePlaceholder => '암호구';

  @override
  String get passphraseRepeatPlaceholder => '암호구 다시 입력';

  @override
  String get passphraseTooShort => '8자 이상';

  @override
  String get passphraseMismatch => '암호구가 일치하지 않습니다';

  @override
  String get importUnlockTitle => '암호화된 백업';

  @override
  String get importUnlockBody => '이 백업을 암호화한 암호구를 입력하세요.';

  @override
  String get importUnlock => '잠금 해제';

  @override
  String get importWrongPassphrase => '열 수 없습니다. 암호구가 틀렸거나 파일이 손상되었습니다.';

  @override
  String get importConfirmTitle => '이 백업을 복원할까요?';

  @override
  String get importConfirmBody => '그 항목을 저널에 추가합니다. 같은 백업을 두 번 복원해도 중복되지 않습니다.';

  @override
  String get importConfirm => '복원';

  @override
  String get importSummaryTitle => '복원 완료';

  @override
  String importSummaryImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '항목 $count개를 복원했습니다.',
      zero: '새로 복원할 것이 없습니다.',
    );
    return '$_temp0';
  }

  @override
  String importSummarySkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count개는 이미 저널에 있었습니다.',
    );
    return '$_temp0';
  }

  @override
  String get importFailedTitle => '복원 실패';

  @override
  String get importFailedBody => '백업을 읽을 수 없습니다. 저널은 아무것도 바뀌지 않았습니다.';

  @override
  String get importNotArchive => 'OpenTranscribe 백업이 아닙니다. 저널은 아무것도 바뀌지 않았습니다.';

  @override
  String get importNewerVersion => '더 새로운 버전의 앱으로 만들어졌습니다. 업데이트 후 가져오세요.';

  @override
  String get importRezipped => '이 백업은 다른 도구로 다시 압축되었습니다. 새로 저장한 것을 복원하세요.';

  @override
  String get done => '완료';

  @override
  String get importFailedMidway => '복원이 도중에 멈췄습니다. 지금까지 복원된 것은 유지됩니다. 다시 복원하면 마무리됩니다.';

  @override
  String get settingsSupport => '후원';

  @override
  String get supportPitch =>
      'OpenTranscribe는 무료이고 프라이빗합니다. 후원은 그것을 지켜줍니다. 클럽 가입은 한 번의 결제로 평생 유지됩니다.';

  @override
  String get supportPerkExports => '서식 있는 내보내기';

  @override
  String get supportPerkExportsNote => 'Markdown, Obsidian 또는 웹사이트로.';

  @override
  String get supportPerkRetranscribeNote => '일기 전체를 더 새로운 엔진으로 다시 듣습니다.';

  @override
  String get supportPerkFuture => '앞으로의 클럽 기능';

  @override
  String get supportPerkFutureNote => '나중에 추가되는 클럽 기능도 포함됩니다.';

  @override
  String get supportThanks => '평생 클럽의 일원입니다. 감사합니다.';

  @override
  String supportJoin(String price) {
    return '$price에 클럽 가입';
  }

  @override
  String get supportRestore => '구입 항목 복원';

  @override
  String get supportUnreachable => 'App Store에 연결할 수 없습니다. 이 화면을 다시 열면 다시 시도합니다.';

  @override
  String get supportPending => '승인 대기 중입니다. 승인되면 구입이 완료됩니다.';

  @override
  String get supportRestoreNoneTitle => '복원할 항목 없음';

  @override
  String get supportRestoreNoneBody => '이 Apple ID에 연결된 클럽 구입이 없습니다.';

  @override
  String get supportFailedTitle => '완료되지 않았습니다';

  @override
  String get supportFailedBody => 'App Store에서 완료하지 못했습니다. 다시 시도하세요.';

  @override
  String get supportPrivacy => '개인정보 처리방침';

  @override
  String get supportTerms => '이용 약관';

  @override
  String get supportUnlocksSection => '클럽 혜택';

  @override
  String get supportMemberUnlocks => '이용 가능한 혜택';

  @override
  String get supporterTag => '클럽';

  @override
  String supportFooter(String privacy, String terms) {
    return '후원해도 프라이버시는 달라지지 않습니다. 저널은 절대 기기를 떠나지 않습니다($privacy). 구매는 Apple 표준 $terms을 따릅니다.';
  }
}
