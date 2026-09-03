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
  String get launchFailedTitle => '起動できませんでした';

  @override
  String get launchFailedBody =>
      '起動に必要なものを読み込めませんでした。App スイッチャーでアプリを終了してから開き直してください。直らないときは端末を再起動してください。';

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
  String get retranscribeAllTitle => 'すべて再文字起こし';

  @override
  String get retranscribeRowQueued => '再文字起こし対象';

  @override
  String get retranscribeRowCurrent => 'すでに最新';

  @override
  String get retranscribeRowLanded => '再文字起こし済み';

  @override
  String get retranscribeRowFailed => '失敗';

  @override
  String get retranscribeHistoryNote => '置き換えられた言葉は各エントリーの履歴に残ります。';

  @override
  String get retranscribeFailedNote => '失敗したエントリーは次回の実行で再度処理されます。';

  @override
  String retranscribeAllCurrentBody(String engine) {
    return '保存済みの録音はすべて$engineで文字起こし済みです。';
  }

  @override
  String get retranscribeStart => '開始';

  @override
  String retranscribeProgressOf(int done, int total) {
    return '$total件中$done件';
  }

  @override
  String get retranscribeWaitingRecording => '録音が終わるまで一時停止中';

  @override
  String get retranscribeWaitingThermal => '本体の温度が下がるまで一時停止中';

  @override
  String get retranscribeCancel => 'キャンセル';

  @override
  String get retranscribeCancelledNote => '途中で停止しました。再実行すると続きから再開します。';

  @override
  String get delete => '削除';

  @override
  String get homeEmptyHeadline => '話せば、書き留められる。';

  @override
  String get homeEmptySubtitle => '話した内容はすべて文字起こしされ、この端末内に保存されます。下に引いて最初の録音を始めましょう。';

  @override
  String get homePullToRecord => '引いて録音';

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
  String get editTranscript => '編集';

  @override
  String get editedMarker => '編集済み';

  @override
  String get revisionHistory => '履歴';

  @override
  String get revisionHistoryBody => 'このエントリーのテキストがたどってきた履歴です。タップすると、その版が最新として復元されます。';

  @override
  String get revisionCurrent => '現在';

  @override
  String get revisionTranscribed => '文字起こし済み';

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
  String get transcribeErrorRecordingMissing =>
      'このエントリーの録音は端末に残っていないため、もう一度文字起こしはできません。すでにある文章がすべてです。';

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
  String get transcribeErrorLabelRecordingMissing => '録音なし';

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
  String get transcribeErrorTitleRecordingMissing => '録音がありません';

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
  String get themeNameSepia => 'セピア';

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
  String get appearanceIconSection => 'アプリアイコン';

  @override
  String get appIconNameSignal => 'Signal';

  @override
  String get appIconNameLines => 'Lines';

  @override
  String get appIconNameDots => 'Dots';

  @override
  String get appIconFailedTitle => 'アイコンを変更できませんでした';

  @override
  String get appIconFailedBody => 'iOSが変更を拒否しました。もう一度お試しください。';

  @override
  String get settingsAppLanguage => '言語';

  @override
  String transcriptionCap(int used, int max) {
    return '$max 個中 $used 個の言語スロットを使用中';
  }

  @override
  String get transcriptionErrorUnsupported => 'この言語は、この端末ではまだダウンロードできません。';

  @override
  String get languageNeedsDictation => 'iOS のキーボード設定でこの言語の音声入力をオンにしてください。';

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
  String get modelFailDictationTitle => '音声入力が設定されていません';

  @override
  String modelFailDictationBody(String language) {
    return '$language はシステムの音声入力モデルで文字起こしされますが、この iPhone にはまだありません。iOS 設定でキーボードを追加し、音声入力をオンにしてください。';
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
  String get settingsModels => '文字起こし';

  @override
  String get transcriptionYourLanguages => '自分の言語';

  @override
  String get transcriptionAllLanguages => 'すべての言語';

  @override
  String get transcriptionSpeaking => '話す言語';

  @override
  String get transcriptionAlsoReady => '準備済みの言語';

  @override
  String get transcriptionAddLanguage => '追加';

  @override
  String transcriptionHeroReady(String engine) {
    return '準備完了 · $engine';
  }

  @override
  String get transcriptionFootnote => 'モデルは一度だけダウンロードされ、システムと共有されます。';

  @override
  String get transcriptionEngines => 'エンジン';

  @override
  String get engineBlurbSpeechAnalyzer => 'Apple の最新エンジン。言語ごとにモデルをダウンロード';

  @override
  String get engineBlurbDictation => 'iOS キーボードの音声入力を支える認識エンジン';

  @override
  String get engineUnavailableNote => 'この iPhone では利用できません';

  @override
  String get engineUnavailableTitle => 'この iPhone では利用できません';

  @override
  String engineUnavailableBody(String engine) {
    return '$engine には iOS 26 と新しい iPhone が必要です。録音には、この iPhone で使えるエンジンが引き続き使われます。';
  }

  @override
  String get engineBusyTitle => '録音中';

  @override
  String get engineBusyBody => '録音を停止してからエンジンを切り替えてください。';

  @override
  String get engineRetranscribingTitle => '再文字起こし中';

  @override
  String get engineRetranscribingBody => '処理が終わるのを待つか中止してから、エンジンを切り替えてください。';

  @override
  String get engineNotSavedTitle => '選択を保存できませんでした';

  @override
  String get engineNotSavedBody => 'エンジンの選択を保存できなかったため、再起動後は元に戻ります。';

  @override
  String get transcriptionDefaultTag => 'デフォルト';

  @override
  String transcriptionDeviceLanguageFallback(String fallback) {
    return 'お使いの端末の言語は、まだ端末内での文字起こしに対応していないため、$fallback がデフォルトになります。';
  }

  @override
  String get onboardingOpenSettings => '設定で有効にする';

  @override
  String get onboardingReflectTitle => 'あなたの一週間を読み返す';

  @override
  String get onboardingReflectBody =>
      'エントリーは、日、週、月ごとの短い振り返りとして読み返せます。この端末上で Apple Intelligence が書き、どこにも送られません。';

  @override
  String get onboardingReflectDay1 => 'よく眠れなかったけれど、朝のランニングでほとんど立て直せた。';

  @override
  String get onboardingReflectDay2 => 'ダナとコーヒー。なんでもないことと、すべてのことを二時間。';

  @override
  String get onboardingReflectDay3 => '追加の案件を断った。一日ずっと身軽だった。';

  @override
  String get onboardingReflectDay4 => '遠回りして歩いて帰った。街は珍しく静かだった。';

  @override
  String get onboardingReflectNote => '「もっと」に断りを入れた一週間と、そうして戻ってきた長い散歩。';

  @override
  String get onboardingShapeTitle => 'あなたのもの、どんな形でも';

  @override
  String get onboardingShapeBody =>
      'ジャーナル全体を Markdown、Obsidian Vault、またはWebサイトとして持ち出せます。あなただけが知るパスフレーズで封じてバックアップできます。あなたが運ばない限り、何も同期されません。';

  @override
  String get onboardingBackupLine => 'パスフレーズで封じ、どこでも復元できます。';

  @override
  String get onboardingRecordTitle => '思ったことを話せば、書き留められます。';

  @override
  String get onboardingRecordBody => 'すべての言葉はこの端末に残ります。アカウントもクラウドもありません。機内モードでも何も変わりません。';

  @override
  String get onboardingRecordText1 => 'リアとコーヒーを飲んで、結局二時間も引っ越しの話をした。';

  @override
  String get onboardingRecordText2 => 'もっと小さな暮らしがしたいと言いながら、毎晩予定を詰め込んでいる。';

  @override
  String get onboardingRecordText3 => '遠回りして歩いて帰った。街は珍しく静かだった。';

  @override
  String get onboardingRecordText4 => 'それから階段に座って、しばらく何もしなかった。たぶんそれが大事だったのだと思う。';

  @override
  String get onboardingRecordText5 => '仕事は問題なかった。できないことを求められることもなかった。';

  @override
  String get onboardingRecordText6 => '明日は遅くなる前に母に電話したい。';

  @override
  String get onboardingLanguageDownloads => '一度ダウンロードすれば、あとはオフラインで動作します。';

  @override
  String get onboardingLanguageBuiltIn => '内蔵済み。ダウンロードは不要です。';

  @override
  String get onboardingLanguageReady => 'この端末で準備できています。';

  @override
  String get onboardingLanguageLoading => '言語を確認しています';

  @override
  String get onboardingPermissionsTitle => 'アクセスを許可';

  @override
  String get onboardingPermissionsBody =>
      'ここにあるものはすべて、この端末上で動作します。「始める」でマイクと音声認識の許可を求めます。どちらも後から設定で変更できます。';

  @override
  String get onboardingMicName => 'マイク';

  @override
  String get onboardingMicReason => '音声を録音するため。';

  @override
  String get onboardingSpeechName => '音声認識';

  @override
  String get onboardingSpeechReason => '録音をテキストに変換するため。処理は端末内で行われます。';

  @override
  String onboardingReflectWeek(int number) {
    return '第$number週';
  }

  @override
  String get onboardingShapeObsidianName => 'Obsidian';

  @override
  String get onboardingShapeMarkdownNote => '1件1ファイル';

  @override
  String get onboardingShapeObsidianNote => '相互リンク';

  @override
  String get onboardingShapeWebNote => 'ブラウザで';

  @override
  String get onboardingReflectionsOn => 'Apple Intelligence はオンです。';

  @override
  String get onboardingReflectionsPreparing => 'この端末では Apple Intelligence の準備がまだ進んでいます。';

  @override
  String get onboardingReflectionsOff => '設定で Apple Intelligence をオンにすると使えます。';

  @override
  String get onboardingNext => '次へ';

  @override
  String get onboardingStart => '始める';

  @override
  String get onboardingDone => '完了';

  @override
  String get hintEntryMenu => 'このエントリーでできることは、右上のメニューにあります。テキストの編集、書き出し、追加の録音。';

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
  String get cacheUsageInfo => '文字起こし済みエントリーの音声は削除できます。テキストは残ります。文字起こしされていない録音には決して触れません。';

  @override
  String get cacheKeepAudio => '音声を保持';

  @override
  String get cacheKeepAudioInfo =>
      'オフにすると、文字起こしが成功した録音はその時点で削除されます。該当エントリーはテキストのみになり、再生も、将来のより良いエンジンでの再文字起こしもできません。';

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

  @override
  String get reflectionsTitle => '振り返り';

  @override
  String get reflectionPeriods => '期間';

  @override
  String get reflectionDaily => '毎日';

  @override
  String get reflectionWeekly => '毎週';

  @override
  String get reflectionMonthly => '毎月';

  @override
  String get reflectionsEmptyTitle => 'まだ振り返りはありません';

  @override
  String get reflectionsEmptyBody => '最初の振り返りは、ジャーナルに書き留めると届きます。記録した内容から読み解かれます。';

  @override
  String get reflectionQuietDay => '静かな一日。';

  @override
  String get reflectionQuietWeek => '静かな一週間。';

  @override
  String get reflectionQuietMonth => '静かな一ヶ月。';

  @override
  String get reflectionWaitingTitle => 'まだ書かれていません';

  @override
  String get reflectionWaitingBody => 'Apple Intelligence の準備が整った状態で次にジャーナルを開くと、読み返されます。';

  @override
  String get reflectionErasedTitle => '消去済み';

  @override
  String get reflectionErasedBody => 'この振り返りを削除しました。再生成するともう一度書かれます。';

  @override
  String get reflectionQuietBody => '振り返りになるものはありませんでした。';

  @override
  String reflectionWrittenOn(String date) {
    return '$date に作成';
  }

  @override
  String reflectionOfPeriod(String range) {
    return '$rangeの振り返り';
  }

  @override
  String get reflectionVoice => '文体';

  @override
  String get reflectionVoiceLiterary => '文学的';

  @override
  String get reflectionVoiceObservational => '観察的';

  @override
  String get reflectionVoiceSparse => '簡素';

  @override
  String get reflectionLength => '長さ';

  @override
  String get reflectionLengthOneLine => '一行';

  @override
  String get reflectionLengthSentences => '数文';

  @override
  String get reflectionLengthParagraph => '短い段落';

  @override
  String get reflectionSpecifics => '具体性';

  @override
  String get reflectionSpecificsNameFreely => '具体的に書く';

  @override
  String get reflectionSpecificsThemes => 'テーマのみ';

  @override
  String get reflectionSpecificsLetPeriod => 'お任せする';

  @override
  String get reflectionGenerateAll => '振り返りを生成';

  @override
  String get reflectionRegenerate => '再生成';

  @override
  String get reflectionDeleteDay => '日を削除';

  @override
  String get reflectionDeleteWeek => '週を削除';

  @override
  String get reflectionDeleteMonth => '月を削除';

  @override
  String get reflectionRegenerateFailed => '振り返りを作成できませんでした。もう一度お試しください。';

  @override
  String get reflectionsDisabledTitle => '振り返りはオフです';

  @override
  String get reflectionsDisabledBody => '振り返りがオフの間は、新しいものは書かれません。';

  @override
  String get reflectionsDisabledEnable => 'オンにする';

  @override
  String get reflectionOffTitle => 'Apple Intelligence がオフです';

  @override
  String get reflectionOffBody => '振り返りを受け取るには、「設定」の「Apple Intelligence と Siri」でオンにしてください。';

  @override
  String get reflectionPreparingTitle => '準備中';

  @override
  String get reflectionPreparingBody => 'この端末で Apple Intelligence を準備しています。準備が完了すると振り返りが始まります。';

  @override
  String get reflectionUnsupportedTitle => 'ここでは利用できません';

  @override
  String get reflectionUnsupportedBody => 'この端末は、振り返りに必要な Apple Intelligence に対応していません。';

  @override
  String get settingsNotifications => '通知';

  @override
  String get notifyReflectionReminders => '振り返りのリマインダー';

  @override
  String get notifyPeriodDay => '日';

  @override
  String get notifyPeriodWeek => '週';

  @override
  String get notifyPeriodMonth => '月';

  @override
  String get notifyReflectionsInfo => '新しい振り返りを読む準備ができたら知らせます。デバイス上で動作し、どこにも送信されません。';

  @override
  String get notifyTime => '時刻';

  @override
  String get notifyPermissionDenied => '通知は「設定」でオフになっています。';

  @override
  String get notifyOpenSettings => '設定を開く';

  @override
  String get notifyDailyTitle => '昨日の振り返りができました';

  @override
  String get notifyDailyBody => '開いて昨日の振り返りを読む。';

  @override
  String get notifyWeeklyTitle => '今週の振り返りができました';

  @override
  String get notifyWeeklyBody => '開いて先週の振り返りを読む。';

  @override
  String get notifyMonthlyTitle => '先月の振り返りができました';

  @override
  String get notifyMonthlyBody => '開いて先月の振り返りを読む。';

  @override
  String get notifyNeedsReflections => '新しい振り返りを読む準備ができると、通知が届きます。今は振り返りがオフになっています。';

  @override
  String get notifyTurnOnReflections => '振り返りをオンにする';

  @override
  String get notifyReflectionsUnavailable => 'このデバイスは振り返りを生成できないため、送信する通知はありません。';

  @override
  String get themeRequestInfo =>
      'ここにないテーマで OpenTranscribe を使いたいですか？GitHub で issue を作成していただければ、今後のリリースで追加します。追加されたテーマは OpenTranscribe Club のメンバー向けです。';

  @override
  String get themeRequestLink => 'GitHub でテーマをリクエスト';

  @override
  String get exportEntry => '書き出す';

  @override
  String get exportEntryTitle => 'エントリーを書き出す';

  @override
  String get exportIncludeAudio => '音声を含める';

  @override
  String get exportFormatMarkdown => 'Markdown';

  @override
  String get exportFormatMarkdownNote => 'エントリーごとのノートとJSON。';

  @override
  String get exportFormatObsidian => 'Obsidian Vault';

  @override
  String get exportFormatObsidianNote => 'プロパティ付きノート、録音を埋め込み。';

  @override
  String get exportFormatWeb => 'Webサイト';

  @override
  String get exportFormatWebNote => '検索とプレイヤー、どのブラウザでも。';

  @override
  String get exportFailedTitle => '書き出しに失敗しました';

  @override
  String get exportFailedBody => 'ファイルを準備できませんでした。何も共有されていません。';

  @override
  String get exportTooLargeBody => '書き出しが1ファイルに収まる4 GBを超えています。何も共有されていません。';

  @override
  String get exportNoSpaceBody => 'ファイルを準備するための空き容量が足りません。何も共有されていません。';

  @override
  String get exportCancel => 'キャンセル';

  @override
  String get exportUntitled => '無題';

  @override
  String get exportTranscriptHeading => '文字起こし';

  @override
  String get exportQuiet => '静かなひととき。';

  @override
  String get exportHtmlSearch => '検索';

  @override
  String get exportHtmlSchemeLabel => '配色';

  @override
  String get exportHtmlSchemeAuto => '自動';

  @override
  String get exportHtmlSchemeLight => 'ライト';

  @override
  String get exportHtmlSchemeDark => 'ダーク';

  @override
  String get exportHtmlEmptyTitle => 'まだ何もありません';

  @override
  String get exportHtmlEmptyBody => 'このジャーナルにはエントリーがありません。';

  @override
  String get exportHtmlNoMatchesTitle => '見つかりませんでした';

  @override
  String exportHtmlNoMatches(String term) {
    return '「$term」に一致するエントリーはありません';
  }

  @override
  String get exportHtmlPlay => '再生';

  @override
  String get exportHtmlPause => '一時停止';

  @override
  String get exportHtmlBack => '15秒戻る';

  @override
  String get exportHtmlSpeed => '再生速度';

  @override
  String get exportHtmlSeek => 'シーク';

  @override
  String get settingsBackup => 'バックアップ';

  @override
  String get backupInfo => 'バックアップには全エントリーと音声、振り返りが入ります。暗号化すれば、パスフレーズが唯一の鍵です。';

  @override
  String get backupInfoEmpty => 'まだバックアップするものがありません。バックアップにはエントリーと音声、振り返りが入ります。';

  @override
  String backupInfoMeasured(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'バックアップには$count件のエントリーと音声、振り返りが入り、約$sizeです。暗号化すれば、パスフレーズが唯一の鍵です。',
    );
    return '$_temp0';
  }

  @override
  String get backupExportSection => '書き出し';

  @override
  String backupExportAs(String format) {
    return '$formatとして書き出す';
  }

  @override
  String get backupExportInfo =>
      'すべてのエントリーを書き出し時に選んだ形式でzipにまとめ、共有シートへ渡します。他のアプリで読むための複製で、復元にはバックアップが要ります。';

  @override
  String get backupSeal => 'パスフレーズで暗号化';

  @override
  String get backupSave => 'バックアップを書き出す';

  @override
  String backupLastBackup(String date) {
    return '前回のバックアップ $date';
  }

  @override
  String get passphraseCreateTitle => 'バックアップを暗号化';

  @override
  String get passphraseCreateBody => 'パスフレーズが唯一の鍵です。どこにも保存されません。なければバックアップはただのノイズです。';

  @override
  String get passphrasePlaceholder => 'パスフレーズ';

  @override
  String get passphraseRepeatPlaceholder => 'パスフレーズを再入力';

  @override
  String get passphraseTooShort => '8文字以上';

  @override
  String get passphraseMismatch => 'パスフレーズが一致しません';

  @override
  String get passphraseShow => '表示';

  @override
  String get passphraseHide => '非表示';

  @override
  String get importUnlockTitle => '暗号化されたバックアップ';

  @override
  String get importUnlockBody => 'このバックアップを暗号化したパスフレーズを入力してください。';

  @override
  String get importUnlock => '解錠';

  @override
  String get importWrongPassphrase => '解錠できませんでした。パスフレーズが違うか、ファイルが破損しています。';

  @override
  String get importConfirmTitle => 'このバックアップを復元しますか？';

  @override
  String get importConfirmBody =>
      'そのエントリーをジャーナルに追加します。既にあるエントリーはバックアップの内容に置き換わり、その後の編集は失われます。同じバックアップを二度復元しても重複しません。';

  @override
  String get importConfirm => '復元';

  @override
  String get importSummaryTitle => '復元完了';

  @override
  String importSummaryAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件のエントリーを追加しました。',
      zero: '新しく追加するものはありません。',
    );
    return '$_temp0';
  }

  @override
  String importSummaryReplaced(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件はバックアップの内容に置き換わりました。',
    );
    return '$_temp0';
  }

  @override
  String importSummarySkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count件は既にジャーナルにありました。',
    );
    return '$_temp0';
  }

  @override
  String importSummaryAudio(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count件の録音を復元しました。');
    return '$_temp0';
  }

  @override
  String importConfirmCounts(int count, int audio) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: 'エントリー$count件');
    String _temp1 = intl.Intl.pluralLogic(
      audio,
      locale: localeName,
      other: '録音$audio件',
      zero: '録音なし',
    );
    return '$_temp0・$_temp1';
  }

  @override
  String get importFailedTitle => '復元に失敗しました';

  @override
  String get importFailedBody => 'バックアップを読めませんでした。ジャーナルは何も変わっていません。';

  @override
  String get importNotArchive => 'OpenTranscribeのバックアップではありません。ジャーナルは何も変わっていません。';

  @override
  String get importNewerVersion => 'より新しいバージョンのアプリで作られています。更新してから読み込んでください。';

  @override
  String get importRezipped => 'このバックアップは別のツールで再圧縮されています。新しく保存したものを復元してください。';

  @override
  String get done => '完了';

  @override
  String get importFailedMidway => '復元が途中で止まりました。ここまでの復元は残っています。もう一度復元すれば完了します。';

  @override
  String get settingsSupport => 'サポート';

  @override
  String get supportPitch => 'クラブはOpenTranscribeを支える方法です。一度の支払いでずっと有効、お礼にいくつかのルックが付きます。';

  @override
  String get supportPitchFree => 'OpenTranscribeを便利にしているものはすべて誰でも無料で、これからも変わりません。';

  @override
  String get supportPerkThemes => 'クラブのテーマ';

  @override
  String get supportPerkThemesNote => 'Gruvbox、Dracula、Nord、デフォルト以外のすべてのテーマ。';

  @override
  String get supportPerkIcons => 'アプリアイコン';

  @override
  String get supportPerkIconsNote => 'Signal、Lines、Dots、デフォルト以外のすべてのアイコン。';

  @override
  String get supportThanks => 'ずっとクラブの一員です。ありがとうございます。';

  @override
  String supportJoin(String price) {
    return '$priceでクラブに参加';
  }

  @override
  String get supportRestore => '購入を復元';

  @override
  String get supportUnreachable => 'App Storeに接続できません。閉じてから開き直すと再試行します。';

  @override
  String get supportPending => '承認待ちです。承認されると購入が完了します。';

  @override
  String get supportRestoreNoneTitle => '復元できる購入はありません';

  @override
  String get supportRestoreNoneBody => 'このApple IDにクラブの購入は関連付けられていません。';

  @override
  String get supportFailedTitle => '完了できませんでした';

  @override
  String get supportFailedBody => 'App Storeが完了できませんでした。もう一度お試しください。';

  @override
  String get supportPrivacy => 'プライバシーポリシー';

  @override
  String get supportTerms => '利用規約';

  @override
  String get supportUnlocksSection => '受け取れるもの';

  @override
  String get supporterTag => 'クラブ';

  @override
  String supportFooter(String privacy, String terms) {
    return 'サポートしてもプライバシーは何も変わりません。ジャーナルが端末の外に出ることはありません（$privacy）。購入はAppleの標準$termsに従います。';
  }

  @override
  String get continueRecording => '追加で録音';

  @override
  String continuingEntry(String title) {
    return '$titleの続き';
  }

  @override
  String get continueUntranscribedLabel => '追加部分の文字起こしなし';

  @override
  String get continueUntranscribedTitle => '追加部分は文字起こしされませんでした';

  @override
  String get continueUntranscribedBody => '録音は追加されましたが、追加した言葉は文字起こしされませんでした。再文字起こしですべてを聞き取れます。';

  @override
  String get continueSavedSeparatelyLabel => '新しいエントリとして保存';

  @override
  String get continueSavedSeparatelyBody => '新しい録音はこのエントリに結合できなかったため、単独で保存しました。';

  @override
  String get continueEntryBusy => 'このエントリはまだ文字起こし中です。';
}
