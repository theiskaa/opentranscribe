// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'OpenTranscribe';

  @override
  String get settingsOffline => 'すべてこの端末内に保存されます。アカウントもクラウドも通信もありません。';

  @override
  String get entryUntranscribed => '文字起こし未実行';

  @override
  String get entryUntranscribedTitle => 'まだ文字起こししていません';

  @override
  String get entryUntranscribedMessage => 'この録音を、後で読み返せるテキストにします。処理は端末内で実行されます。';

  @override
  String get entryNoSpeechTitle => '表示できる言葉がありません';

  @override
  String get entryNoSpeechMessage => 'この録音を文字起こししましたが、音声が見つかりませんでした。';

  @override
  String get retranscribe => '再文字起こし';

  @override
  String get delete => '削除';

  @override
  String get homeEmptyHeadline => '話せば、書き留められる。';

  @override
  String get homeEmptySubtitle => '話した内容はすべて文字起こしされ、この端末内に保存されます。下に引いて最初の録音を始めましょう。';

  @override
  String get homePullToRecord => '引いて録音';

  @override
  String get menuTranscriptionLanguage => '文字起こし';

  @override
  String get menuSourceCode => 'ソースコード';

  @override
  String get recordStateRecording => '録音中';

  @override
  String get recordStatePaused => '一時停止中';

  @override
  String get recordErrorMessage => '録音中に問題が発生しました。';

  @override
  String get recordLiveUnavailable => '現在ライブテキストを利用できません。録音は保持され、終了後に文字起こしされます。';

  @override
  String get recordInterruptedSaved => '録音が中断されました。録音は保存され、ジャーナルから文字起こしできます。';

  @override
  String get recordPermissionTitle => 'マイクがオフです';

  @override
  String get recordPermissionMessage => '「設定」App で opentranscribe のマイクへのアクセスを許可してから、もう一度お試しください。';

  @override
  String get rename => '名前を変更';

  @override
  String get transcribe => '文字起こし';

  @override
  String get transcribeIn => '言語を指定して文字起こし…';

  @override
  String get playbackFailed => '現在再生を利用できません。';

  @override
  String get transcribeErrorModelInstall =>
      'この言語の音声モデルを取得できませんでした。接続と空き容量を確認するか、「モデル」で言語を管理してください。';

  @override
  String get transcribeErrorPermission => '「設定」App で opentranscribe の音声認識を許可してから、もう一度お試しください。';

  @override
  String get transcribeErrorUnavailable => 'この端末では、この言語の端末内での文字起こしを利用できません。';

  @override
  String get transcribeErrorGeneric => '問題が発生しました。もう一度お試しください。';

  @override
  String get transcribeErrorCapReached => '言語の上限に達しました。設定で言語を削除してから、もう一度お試しください。';

  @override
  String get transcribeErrorLabelPermission => '音声認識がオフです';

  @override
  String get transcribeErrorLabelUnavailable => 'この端末では利用できません';

  @override
  String get transcribeErrorLabelModelInstall => '言語モデルを取得できませんでした';

  @override
  String get transcribeErrorLabelCapReached => '言語の上限に達しました';

  @override
  String get transcribeErrorLabelGeneric => '文字起こしに失敗しました';

  @override
  String get transcribeErrorTitlePermission => '音声認識をオンにする';

  @override
  String get transcribeErrorTitleUnavailable => 'ここでは利用できません';

  @override
  String get transcribeErrorTitleModelInstall => 'モデルをダウンロードできませんでした';

  @override
  String get transcribeErrorTitleCapReached => '言語の上限に達しました';

  @override
  String get transcribeErrorTitleGeneric => '問題が発生しました';

  @override
  String get settingsAppearance => '外観';

  @override
  String get settingsTheme => 'テーマ';

  @override
  String get themeSystem => 'システム';

  @override
  String get themeLight => 'ライト';

  @override
  String get themeDark => 'ダーク';

  @override
  String get themeNameDefault => 'デフォルト';

  @override
  String get themeNameGruvbox => 'Gruvbox';

  @override
  String get themeNameSolarized => 'Solarized';

  @override
  String get themeNameSepia => 'セピア';

  @override
  String get settingsAppLanguage => '言語';

  @override
  String get transcriptionInfo =>
      '各言語は独自の端末内モデルで動作します。モデルは一度だけダウンロードされ、システムと共有されるため、このアプリのストレージには計上されません。同時に準備しておける言語の数はシステムによって制限されます。';

  @override
  String transcriptionCap(int used, int max) {
    return '$max 個中 $used 個の言語スロットを使用中';
  }

  @override
  String get transcriptionRemoveHint => '言語を左にスワイプすると削除できます。';

  @override
  String get transcriptionErrorUnsupported => 'この言語は、この端末ではまだダウンロードできません。';

  @override
  String get transcriptionErrorStuck => '以前のダウンロードがまだ保留中です。システムは条件が整うと再試行します。もう一度試しても問題ありません。';

  @override
  String get transcriptionErrorGeneric => 'ダウンロードに失敗しました。接続と空き容量を確認してから、もう一度お試しください。';

  @override
  String get transcriptionErrorCap => '言語の上限に達しました。この言語を追加するには、いずれかの言語を削除してください。';

  @override
  String get transcriptionErrorRemove => 'この言語を削除できませんでした。もう一度お試しください。';

  @override
  String get transcriptionDownloading => 'ダウンロード中';

  @override
  String get retry => 'もう一度試す';

  @override
  String get modelFailCapTitle => '言語の上限に達しました';

  @override
  String modelFailCapBody(String language) {
    return '同時に準備しておける言語の数はシステムによって制限されます。$language のために、いずれかを削除して空きを作ってください。';
  }

  @override
  String get modelFailUnsupportedTitle => 'まだ利用できません';

  @override
  String modelFailUnsupportedBody(String language) {
    return 'この端末には、まだ $language の端末内モデルがありません。システムアップデートで追加される場合があります。';
  }

  @override
  String get modelFailStuckTitle => 'まだダウンロード中です';

  @override
  String modelFailStuckBody(String language) {
    return '以前の $language のダウンロードがまだ保留中です。システムは条件が整うと再試行します。もう一度求めても問題ありません。';
  }

  @override
  String get modelFailGenericTitle => 'ダウンロードできませんでした';

  @override
  String modelFailGenericBody(String language) {
    return '$language のモデルをダウンロードできませんでした。接続と空き容量を確認してから、もう一度お試しください。';
  }

  @override
  String get modelFailRemoveTitle => '削除できませんでした';

  @override
  String modelFailRemoveBody(String language) {
    return 'システムが $language を解放しませんでした。もう一度試しても問題ありません。';
  }

  @override
  String get settingsModels => 'モデル';

  @override
  String get transcriptionLanguages => '言語';

  @override
  String get transcriptionDefaultTag => 'デフォルト';

  @override
  String get transcriptionDefaultHint => '言語を長押しすると、デフォルトに設定できます。';

  @override
  String transcriptionDeviceLanguageFallback(String fallback) {
    return 'お使いの端末の言語は、まだ端末内での文字起こしに対応していないため、$fallback がデフォルトになります。';
  }

  @override
  String get onboardingIntroBody => '思ったことを話せば、書き留められます。';

  @override
  String get onboardingSpeakTitle => '話すだけ';

  @override
  String get onboardingSpeakLine => '録音をタップして、思っていることを話しましょう。';

  @override
  String get onboardingWriteTitle => '読み返す';

  @override
  String get onboardingWriteLine => '録音はすべてテキストとして書き留められます。';

  @override
  String get onboardingPrivateTitle => '何も端末から出ません';

  @override
  String get onboardingPrivateLine => 'アカウントもクラウドもありません。機内モードでも変わりなく使えます。';

  @override
  String get onboardingSource => 'オープンソース';

  @override
  String get onboardingSourceLine => 'すべてのコードが公開されています。GitHub でご覧いただけます。';

  @override
  String get onboardingPermissionsTitle => 'アクセスを許可';

  @override
  String get onboardingPermissionsBody => 'どちらも完全に端末内で動作します。';

  @override
  String get onboardingMicName => 'マイク';

  @override
  String get onboardingMicReason => '音声を録音するため。';

  @override
  String get onboardingSpeechName => '音声認識';

  @override
  String get onboardingSpeechReason => '録音をテキストに変換するため。処理は端末内で行われます。';

  @override
  String get onboardingAllow => '許可';

  @override
  String get onboardingOpenSettings => '設定で有効にする';

  @override
  String get onboardingModelsTitle => '言語をダウンロード';

  @override
  String get onboardingModelsBody => '言語が端末に入れば、文字起こしはオフラインで動作します。メニューからいつでも追加できます。';

  @override
  String get onboardingNext => '次へ';

  @override
  String get onboardingStart => '始める';

  @override
  String get settingsCache => 'キャッシュ';

  @override
  String cacheRecordingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count件の録音');
    return '$_temp0';
  }

  @override
  String get cacheReclaimable => '解放可能';

  @override
  String get cacheReclaimableInfo => '文字起こし済み、削除可能';

  @override
  String get cacheUsageInfo => '文字起こし済みエントリーの音声は削除できます。テキストは残ります。未変換の録音には決して触れません。';

  @override
  String get cacheKeepAudio => '音声を保持';

  @override
  String get cacheKeepAudioInfo =>
      'オフにすると、文字起こしが成功した録音はその時点で削除されます。該当エントリーはテキストのみになり、再生も、将来のより良いエンジンでの再変換もできません。';

  @override
  String get cacheClear => '文字起こし済み音声を削除';

  @override
  String get cacheClearTitle => '文字起こし済み音声を削除しますか？';

  @override
  String cacheClearBody(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件の文字起こし済みエントリーの音声（$size）を削除します。テキストは残ります。元に戻せません。',
    );
    return '$_temp0';
  }

  @override
  String get cacheClearConfirm => '録音を削除';
}
