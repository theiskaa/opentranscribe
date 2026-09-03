// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'OpenTranscribe';

  @override
  String get launchFailedTitle => '无法启动';

  @override
  String get launchFailedBody => '启动所需的内容没有加载成功。请在应用切换器中关闭应用后重新打开；如果还不行，请重启手机。';

  @override
  String get entryUntranscribed => '未转写';

  @override
  String get entryUntranscribedTitle => '尚未转写';

  @override
  String get entryUntranscribedMessage => '把这段录音转成可以回看的文字。转写在本机进行。';

  @override
  String get entryNoSpeechTitle => '没有可显示的内容';

  @override
  String get entryNoSpeechMessage => '这段录音已转写，但其中没有检测到语音。';

  @override
  String get retranscribe => '重新转写';

  @override
  String get retranscribeAllTitle => '全部重新转写';

  @override
  String get retranscribeRowQueued => '待重新转写';

  @override
  String get retranscribeRowCurrent => '已是最新';

  @override
  String get retranscribeRowLanded => '已重新转写';

  @override
  String get retranscribeRowFailed => '失败';

  @override
  String get retranscribeHistoryNote => '被替换的文字会保留在条目的历史中。';

  @override
  String get retranscribeFailedNote => '失败的条目会在下次运行时重试。';

  @override
  String retranscribeAllCurrentBody(String engine) {
    return '保留的录音均已由 $engine 转写。';
  }

  @override
  String get retranscribeStart => '开始';

  @override
  String retranscribeProgressOf(int done, int total) {
    return '$done / $total';
  }

  @override
  String get retranscribeWaitingRecording => '录音结束前暂停';

  @override
  String get retranscribeWaitingThermal => '设备降温前暂停';

  @override
  String get retranscribeCancel => '取消';

  @override
  String get retranscribeCancelledNote => '已提前停止。再次运行会从中断处继续。';

  @override
  String get delete => '删除';

  @override
  String get homeEmptyHeadline => '开口说，即刻成文。';

  @override
  String get homeEmptySubtitle => '你说的每一句都会被转写，并保存在这台设备上。下拉即可录制第一条。';

  @override
  String get homePullToRecord => '下拉录制';

  @override
  String get menuSourceCode => '源代码';

  @override
  String get menuHowItWorks => '使用方法';

  @override
  String get recordStateRecording => '录制中';

  @override
  String get recordStatePaused => '已暂停';

  @override
  String get recordErrorMessage => '录制时出了点问题。';

  @override
  String get recordLiveUnavailable => '实时文字暂时不可用。你的录音已妥善保存，结束后会自动转写。';

  @override
  String get recordInterruptedSaved => '录制被打断。你的录音已保存，可在日志中转写。';

  @override
  String get recordPermissionTitle => '麦克风已关闭';

  @override
  String get recordPermissionMessage => '请在“设置”应用中为 opentranscribe 开启麦克风权限，然后重试。';

  @override
  String get rename => '重命名';

  @override
  String get editTranscript => '编辑';

  @override
  String get editedMarker => '已编辑';

  @override
  String get revisionHistory => '历史记录';

  @override
  String get revisionHistoryBody => '这条条目的文字经历过的所有版本。轻点某个版本即可将其恢复为最新版本。';

  @override
  String get revisionCurrent => '当前';

  @override
  String get revisionTranscribed => '已转写';

  @override
  String get transcribe => '转写';

  @override
  String get transcribeIn => '转写为…';

  @override
  String get playbackFailed => '播放暂时不可用。';

  @override
  String get transcribeErrorModelInstall => '无法获取该语言的语音模型。请检查网络连接和可用空间，或在“模型”中管理语言。';

  @override
  String get transcribeErrorPermission => '请在“设置”应用中为 opentranscribe 开启语音识别权限，然后重试。';

  @override
  String get transcribeErrorUnavailable => '本机的设备端转写暂不支持该语言。';

  @override
  String get transcribeErrorGeneric => '出了点问题。请重试。';

  @override
  String get transcribeErrorCapReached => '语言数量已达上限。请在“设置”中移除一种语言，然后重试。';

  @override
  String get transcribeErrorRecordingMissing => '这条记录的录音已不在设备上，无法再次转写。现有的文字就是全部内容。';

  @override
  String get transcribeErrorLabelPermission => '语音识别已关闭';

  @override
  String get transcribeErrorLabelUnavailable => '本机不支持';

  @override
  String get transcribeErrorLabelModelInstall => '无法获取语言模型';

  @override
  String get transcribeErrorLabelCapReached => '语言数量已达上限';

  @override
  String get transcribeErrorLabelGeneric => '转写失败';

  @override
  String get transcribeErrorLabelRecordingMissing => '录音已不在';

  @override
  String get transcribeErrorTitlePermission => '开启语音识别';

  @override
  String get transcribeErrorTitleUnavailable => '此处不支持';

  @override
  String get transcribeErrorTitleModelInstall => '无法下载模型';

  @override
  String get transcribeErrorTitleCapReached => '语言数量已达上限';

  @override
  String get transcribeErrorTitleGeneric => '出了点问题';

  @override
  String get transcribeErrorTitleRecordingMissing => '录音已不在';

  @override
  String get settingsAppearance => '外观';

  @override
  String get settingsTheme => '主题';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get themeNameDefault => '默认';

  @override
  String get themeNameGruvbox => 'Gruvbox';

  @override
  String get themeNameSepia => 'Sepia';

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
  String get appearanceIconSection => '应用图标';

  @override
  String get appIconNameSignal => 'Signal';

  @override
  String get appIconNameLines => 'Lines';

  @override
  String get appIconNameDots => 'Dots';

  @override
  String get appIconFailedTitle => '图标未更改';

  @override
  String get appIconFailedBody => 'iOS 拒绝了更改。请重试。';

  @override
  String get settingsAppLanguage => '语言';

  @override
  String transcriptionCap(int used, int max) {
    return '已使用 $max 个语言名额中的 $used 个';
  }

  @override
  String get transcriptionErrorUnsupported => '本机暂时无法下载该语言。';

  @override
  String get languageNeedsDictation => '请在 iOS 键盘设置中为此语言开启听写。';

  @override
  String get transcriptionErrorStuck => '上一次下载仍在等待中。条件改善后系统会自动重试，再试一次也没有问题。';

  @override
  String get transcriptionErrorGeneric => '下载失败。请检查网络连接和可用空间，然后重试。';

  @override
  String get transcriptionErrorCap => '语言数量已达上限。请移除一种语言以添加这一种。';

  @override
  String get transcriptionErrorRemove => '无法移除该语言。请重试。';

  @override
  String get transcriptionDownloading => '下载中';

  @override
  String get retry => '重试';

  @override
  String get modelFailCapTitle => '语言数量已达上限';

  @override
  String modelFailCapBody(String language) {
    return '系统会限制一个应用同时可保持就绪的语言数量。请移除以下语言之一，为 $language 腾出空间。';
  }

  @override
  String get modelFailUnsupportedTitle => '暂不支持';

  @override
  String modelFailUnsupportedBody(String language) {
    return '本机暂时还没有 $language 的设备端模型。它可能会随系统更新一同到来。';
  }

  @override
  String get modelFailDictationTitle => '听写尚未设置';

  @override
  String modelFailDictationBody(String language) {
    return '$language 使用系统听写模型转写，此 iPhone 上还没有该模型。请在 iOS 设置中添加对应键盘并开启听写。';
  }

  @override
  String get modelFailStuckTitle => '仍在下载';

  @override
  String modelFailStuckBody(String language) {
    return '$language 的上一次下载仍在等待中。条件改善后系统会自动重试，再次请求也没有问题。';
  }

  @override
  String get modelFailGenericTitle => '无法下载';

  @override
  String modelFailGenericBody(String language) {
    return '无法下载 $language 模型。请检查网络连接和可用空间，然后重试。';
  }

  @override
  String get modelFailRemoveTitle => '无法移除';

  @override
  String modelFailRemoveBody(String language) {
    return '系统未能释放 $language。再试一次也没有问题。';
  }

  @override
  String get settingsModels => '转写';

  @override
  String get transcriptionYourLanguages => '我的语言';

  @override
  String get transcriptionAllLanguages => '所有语言';

  @override
  String get transcriptionSpeaking => '你说的语言';

  @override
  String get transcriptionAlsoReady => '其他就绪语言';

  @override
  String get transcriptionAddLanguage => '添加';

  @override
  String transcriptionHeroReady(String engine) {
    return '已就绪 · $engine';
  }

  @override
  String get transcriptionFootnote => '模型只下载一次，并与系统共享。';

  @override
  String get transcriptionEngines => '引擎';

  @override
  String get engineBlurbSpeechAnalyzer => 'Apple 最新的引擎，每种语言下载一个模型';

  @override
  String get engineBlurbDictation => 'iOS 键盘听写背后的识别引擎';

  @override
  String get engineUnavailableNote => '此 iPhone 上不可用';

  @override
  String get engineUnavailableTitle => '此 iPhone 上不可用';

  @override
  String engineUnavailableBody(String engine) {
    return '$engine 需要 iOS 26 和更新的 iPhone。录音将继续使用此设备可用的引擎。';
  }

  @override
  String get engineBusyTitle => '正在录音';

  @override
  String get engineBusyBody => '请先停止当前录音，再切换引擎。';

  @override
  String get engineRetranscribingTitle => '正在重新转写';

  @override
  String get engineRetranscribingBody => '请等待完成或取消后，再切换引擎。';

  @override
  String get engineNotSavedTitle => '无法保存选择';

  @override
  String get engineNotSavedBody => '无法保存引擎选择，重新启动后将不会保留。';

  @override
  String get transcriptionDefaultTag => '默认';

  @override
  String transcriptionDeviceLanguageFallback(String fallback) {
    return '你手机的语言暂不支持设备端转写，因此默认使用 $fallback。';
  }

  @override
  String get onboardingOpenSettings => '在“设置”中启用';

  @override
  String get onboardingReflectTitle => '回看你的一周';

  @override
  String get onboardingReflectBody => '条目会按日、按周或按月，被写成一段简短的回顾。由 Apple Intelligence 在本机写成，从不发往任何地方。';

  @override
  String get onboardingReflectDay1 => '睡得不好，但晨跑把大半修好了。';

  @override
  String get onboardingReflectDay2 => 'Dana，咖啡，两小时聊了无关紧要又无所不包的事。';

  @override
  String get onboardingReflectDay3 => '拒绝了额外的项目。一整天都轻松了。';

  @override
  String get onboardingReflectDay4 => '绕远路走回家。城市难得地安静。';

  @override
  String get onboardingReflectNote => '一个对“更多”说不的星期，以及随之回来的长长的散步。';

  @override
  String get onboardingShapeTitle => '属于你，任何形式';

  @override
  String get onboardingShapeBody =>
      '把整本日记带走：Markdown、Obsidian Vault，或一个网站。用只有你知道的口令封存备份。除非你亲自带走，否则什么都不会同步。';

  @override
  String get onboardingBackupLine => '以口令封存，随处可恢复。';

  @override
  String get onboardingRecordTitle => '你说出心里话，它替你写下来。';

  @override
  String get onboardingRecordBody => '每个字都留在这台手机上。没有账户，没有云端。飞行模式下也一样。';

  @override
  String get onboardingRecordText1 => '和 Lia 喝咖啡，结果聊搬家的事聊了两个小时。';

  @override
  String get onboardingRecordText2 => '我总说想过更简单的生活，却把每个晚上都排满。';

  @override
  String get onboardingRecordText3 => '绕远路走回家。城市难得地安静。';

  @override
  String get onboardingRecordText4 => '然后我在台阶上坐了一会儿，什么也没做，大概这才是重点。';

  @override
  String get onboardingRecordText5 => '工作还好。没有人要求我给不出的东西。';

  @override
  String get onboardingRecordText6 => '明天想在太晚之前给妈妈打个电话。';

  @override
  String get onboardingLanguageDownloads => '下载一次，之后离线可用。';

  @override
  String get onboardingLanguageBuiltIn => '已内置，无需下载。';

  @override
  String get onboardingLanguageReady => '已就绪，在本机运行。';

  @override
  String get onboardingLanguageLoading => '正在读取你的语言';

  @override
  String get onboardingPermissionsTitle => '允许访问';

  @override
  String get onboardingPermissionsBody => '这里的一切都完全在你的设备上运行。“开始使用”会请求麦克风与语音识别权限，两者稍后都可在“设置”中更改。';

  @override
  String get onboardingMicName => '麦克风';

  @override
  String get onboardingMicReason => '用于录制你的声音。';

  @override
  String get onboardingSpeechName => '语音识别';

  @override
  String get onboardingSpeechReason => '用于在设备上把录音转成文字。';

  @override
  String onboardingReflectWeek(int number) {
    return '第 $number 周';
  }

  @override
  String get onboardingShapeObsidianName => 'Obsidian';

  @override
  String get onboardingShapeMarkdownNote => '每条一个文件';

  @override
  String get onboardingShapeObsidianNote => '互相链接';

  @override
  String get onboardingShapeWebNote => '任何浏览器';

  @override
  String get onboardingReflectionsOn => 'Apple Intelligence 已开启。';

  @override
  String get onboardingReflectionsPreparing => 'Apple Intelligence 仍在本机准备中。';

  @override
  String get onboardingReflectionsOff => '在“设置”中开启 Apple Intelligence 即可使用。';

  @override
  String get onboardingNext => '下一步';

  @override
  String get onboardingStart => '开始使用';

  @override
  String get onboardingDone => '完成';

  @override
  String get hintEntryMenu => '这个条目能做的一切都在上方菜单里：编辑文字、导出、继续录音。';

  @override
  String get settingsCache => '缓存';

  @override
  String cacheRecordingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count 个录音');
    return '$_temp0';
  }

  @override
  String get cacheReclaimable => '可释放';

  @override
  String get cacheReclaimableInfo => '已转写，可安全清除';

  @override
  String get cacheUsageInfo => '已转写条目的音频可以清除，文字会保留。尚未转写的录音绝不会被触碰。';

  @override
  String get cacheKeepAudio => '保留音频';

  @override
  String get cacheKeepAudioInfo => '关闭后，录音在转写成功后即被删除。这类条目仅剩文字：无法回放，也无法日后用更好的引擎重新转写。';

  @override
  String get cacheClear => '清除已转写音频';

  @override
  String get cacheClearTitle => '清除已转写音频？';

  @override
  String cacheClearBody(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '将删除 $count 个已转写条目的音频（$size）。文字保留。此操作无法撤销。',
    );
    return '$_temp0';
  }

  @override
  String get cacheClearConfirm => '删除录音';

  @override
  String get reflectionsTitle => '回顾';

  @override
  String get reflectionPeriods => '周期';

  @override
  String get reflectionDaily => '每日';

  @override
  String get reflectionWeekly => '每周';

  @override
  String get reflectionMonthly => '每月';

  @override
  String get reflectionsEmptyTitle => '还没有回顾';

  @override
  String get reflectionsEmptyBody => '有了日记之后，第一篇就会出现，取自你所记录的内容。';

  @override
  String get reflectionQuietDay => '平静的一天。';

  @override
  String get reflectionQuietWeek => '平静的一周。';

  @override
  String get reflectionQuietMonth => '平静的一个月。';

  @override
  String get reflectionWaitingTitle => '尚未写下';

  @override
  String get reflectionWaitingBody => '下次在 Apple Intelligence 就绪时打开日记，就会回顾这段内容。';

  @override
  String get reflectionErasedTitle => '已抹掉';

  @override
  String get reflectionErasedBody => '你删除了这篇回顾。重新生成会再次写下。';

  @override
  String get reflectionQuietBody => '这一周没有值得回顾的内容。';

  @override
  String reflectionWrittenOn(String date) {
    return '写于 $date';
  }

  @override
  String reflectionOfPeriod(String range) {
    return '$range的回顾';
  }

  @override
  String get reflectionVoice => '文风';

  @override
  String get reflectionVoiceLiterary => '文学化';

  @override
  String get reflectionVoiceObservational => '观察式';

  @override
  String get reflectionVoiceSparse => '简约';

  @override
  String get reflectionLength => '长度';

  @override
  String get reflectionLengthOneLine => '一行';

  @override
  String get reflectionLengthSentences => '几句话';

  @override
  String get reflectionLengthParagraph => '短段落';

  @override
  String get reflectionSpecifics => '细节';

  @override
  String get reflectionSpecificsNameFreely => '点明细节';

  @override
  String get reflectionSpecificsThemes => '仅主题';

  @override
  String get reflectionSpecificsLetPeriod => '由它决定';

  @override
  String get reflectionGenerateAll => '生成回顾';

  @override
  String get reflectionRegenerate => '重新生成';

  @override
  String get reflectionDeleteDay => '删除这一天';

  @override
  String get reflectionDeleteWeek => '删除这一周';

  @override
  String get reflectionDeleteMonth => '删除这个月';

  @override
  String get reflectionRegenerateFailed => '无法生成回顾。请重试。';

  @override
  String get reflectionsDisabledTitle => '回顾已关闭';

  @override
  String get reflectionsDisabledBody => '回顾关闭期间，将不会写下任何新内容。';

  @override
  String get reflectionsDisabledEnable => '开启';

  @override
  String get reflectionOffTitle => 'Apple Intelligence 已关闭';

  @override
  String get reflectionOffBody => '在“设置”的“Apple Intelligence 与 Siri”中开启，即可获得回顾。';

  @override
  String get reflectionPreparingTitle => '正在准备';

  @override
  String get reflectionPreparingBody => 'Apple Intelligence 正在此设备上准备。准备完成后即可开始回顾。';

  @override
  String get reflectionUnsupportedTitle => '此处不可用';

  @override
  String get reflectionUnsupportedBody => '此设备不支持回顾所需的 Apple Intelligence。';

  @override
  String get settingsNotifications => '通知';

  @override
  String get notifyReflectionReminders => '回顾提醒';

  @override
  String get notifyPeriodDay => '日';

  @override
  String get notifyPeriodWeek => '周';

  @override
  String get notifyPeriodMonth => '月';

  @override
  String get notifyReflectionsInfo => '新的回顾可供阅读时提醒你。它在你的设备上触发，不会发送到任何地方。';

  @override
  String get notifyTime => '时间';

  @override
  String get notifyPermissionDenied => '通知已在“设置”中关闭。';

  @override
  String get notifyOpenSettings => '打开设置';

  @override
  String get notifyDailyTitle => '昨日回顾已就绪';

  @override
  String get notifyDailyBody => '打开以阅读昨日回顾。';

  @override
  String get notifyWeeklyTitle => '本周回顾已就绪';

  @override
  String get notifyWeeklyBody => '打开以阅读上周回顾。';

  @override
  String get notifyMonthlyTitle => '上月回顾已就绪';

  @override
  String get notifyMonthlyBody => '打开以阅读上月回顾。';

  @override
  String get notifyNeedsReflections => '新的回顾可供阅读时会收到提醒。回顾目前已关闭。';

  @override
  String get notifyTurnOnReflections => '开启回顾';

  @override
  String get notifyReflectionsUnavailable => '此设备无法生成回顾，因此没有提醒可发送。';

  @override
  String get themeRequestInfo =>
      '想要这里没有的主题吗？在 GitHub 上创建一个 issue，我们会在后续版本中添加。新增的主题仅面向 OpenTranscribe Club 会员。';

  @override
  String get themeRequestLink => '在 GitHub 上申请主题';

  @override
  String get exportEntry => '导出';

  @override
  String get exportEntryTitle => '导出条目';

  @override
  String get exportIncludeAudio => '包含音频';

  @override
  String get exportFormatMarkdown => 'Markdown';

  @override
  String get exportFormatMarkdownNote => '每条记录一个笔记，附 JSON。';

  @override
  String get exportFormatObsidian => 'Obsidian Vault';

  @override
  String get exportFormatObsidianNote => '带属性的笔记，内嵌录音。';

  @override
  String get exportFormatWeb => '网站';

  @override
  String get exportFormatWebNote => '带搜索和播放器，任何浏览器可开。';

  @override
  String get exportFailedTitle => '导出失败';

  @override
  String get exportFailedBody => '无法准备文件。未共享任何内容。';

  @override
  String get exportTooLargeBody => '导出超过了单个文件可容纳的 4 GB。未共享任何内容。';

  @override
  String get exportNoSpaceBody => '可用空间不足，无法准备文件。未共享任何内容。';

  @override
  String get exportCancel => '取消';

  @override
  String get exportUntitled => '无标题';

  @override
  String get exportTranscriptHeading => '转写';

  @override
  String get exportQuiet => '一段安静的时光。';

  @override
  String get exportHtmlSearch => '搜索';

  @override
  String get exportHtmlSchemeLabel => '配色';

  @override
  String get exportHtmlSchemeAuto => '自动';

  @override
  String get exportHtmlSchemeLight => '浅色';

  @override
  String get exportHtmlSchemeDark => '深色';

  @override
  String get exportHtmlEmptyTitle => '这里还没有内容';

  @override
  String get exportHtmlEmptyBody => '这本日记还没有记录。';

  @override
  String get exportHtmlNoMatchesTitle => '未找到结果';

  @override
  String exportHtmlNoMatches(String term) {
    return '没有与“$term”匹配的记录';
  }

  @override
  String get exportHtmlPlay => '播放';

  @override
  String get exportHtmlPause => '暂停';

  @override
  String get exportHtmlBack => '后退 15 秒';

  @override
  String get exportHtmlSpeed => '播放速度';

  @override
  String get exportHtmlSeek => '进度';

  @override
  String get settingsBackup => '备份';

  @override
  String get backupInfo => '备份包含所有记录、音频和回顾。如果加密，口令就是唯一的钥匙。';

  @override
  String get backupInfoEmpty => '暂时没有可备份的内容。备份包含记录、音频和回顾。';

  @override
  String backupInfoMeasured(int count, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '备份包含 $count 条记录、音频和回顾，约 $size。如果加密，口令就是唯一的钥匙。',
    );
    return '$_temp0';
  }

  @override
  String get backupExportSection => '导出';

  @override
  String backupExportAs(String format) {
    return '导出为 $format';
  }

  @override
  String get backupExportInfo => '以导出时选择的格式写出每条记录，打包成 zip，交给共享面板。这是给其他应用阅读的副本；要恢复得靠备份。';

  @override
  String get backupSeal => '用口令加密';

  @override
  String get backupSave => '导出备份';

  @override
  String backupLastBackup(String date) {
    return '上次备份 $date';
  }

  @override
  String get passphraseCreateTitle => '加密备份';

  @override
  String get passphraseCreateBody => '口令是唯一的钥匙。它不会被保存在任何地方；没有它，备份只是噪音。';

  @override
  String get passphrasePlaceholder => '口令';

  @override
  String get passphraseRepeatPlaceholder => '再次输入口令';

  @override
  String get passphraseTooShort => '至少 8 个字符';

  @override
  String get passphraseMismatch => '两次口令不一致';

  @override
  String get passphraseShow => '显示';

  @override
  String get passphraseHide => '隐藏';

  @override
  String get importUnlockTitle => '已加密的备份';

  @override
  String get importUnlockBody => '输入加密这份备份时使用的口令。';

  @override
  String get importUnlock => '解锁';

  @override
  String get importWrongPassphrase => '无法解锁。口令错误，或文件已损坏。';

  @override
  String get importConfirmTitle => '恢复这份备份？';

  @override
  String get importConfirmBody => '把其中的记录加入你的日记。已有的记录会被备份中的版本替换，之后的编辑将丢失。同一份备份恢复两次也不会重复。';

  @override
  String get importConfirm => '恢复';

  @override
  String get importSummaryTitle => '恢复完成';

  @override
  String importSummaryAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已添加 $count 条记录。',
      zero: '没有新内容可添加。',
    );
    return '$_temp0';
  }

  @override
  String importSummaryReplaced(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条记录已替换为备份中的版本。',
    );
    return '$_temp0';
  }

  @override
  String importSummarySkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count 条记录已在日记中。');
    return '$_temp0';
  }

  @override
  String importSummaryAudio(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '已恢复 $count 段录音。');
    return '$_temp0';
  }

  @override
  String importConfirmCounts(int count, int audio) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count 条记录');
    String _temp1 = intl.Intl.pluralLogic(
      audio,
      locale: localeName,
      other: '$audio 段录音',
      zero: '无录音',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String get importFailedTitle => '恢复失败';

  @override
  String get importFailedBody => '无法读取备份。日记没有任何改动。';

  @override
  String get importNotArchive => '这不是 OpenTranscribe 备份。日记没有任何改动。';

  @override
  String get importNewerVersion => '由更新版本的应用创建。请更新后再导入。';

  @override
  String get importRezipped => '这份备份被其他工具重新压缩过。请重新保存一份再恢复。';

  @override
  String get done => '完成';

  @override
  String get importFailedMidway => '恢复中途停止了。已恢复的内容会保留；再次恢复即可完成。';

  @override
  String get settingsSupport => '支持';

  @override
  String get supportPitch => '俱乐部是支持 OpenTranscribe 的方式：付费一次，永久有效，并以几款外观作为答谢。';

  @override
  String get supportPitchFree => '让 OpenTranscribe 好用的一切都对所有人免费，并将一直如此。';

  @override
  String get supportPerkThemes => '俱乐部主题';

  @override
  String get supportPerkThemesNote => 'Gruvbox、Dracula、Nord 以及默认之外的所有主题。';

  @override
  String get supportPerkIcons => '应用图标';

  @override
  String get supportPerkIconsNote => 'Signal、Lines、Dots 以及默认之外的所有图标。';

  @override
  String get supportThanks => '你已永久加入俱乐部。谢谢。';

  @override
  String supportJoin(String price) {
    return '以 $price 加入俱乐部';
  }

  @override
  String get supportRestore => '恢复购买';

  @override
  String get supportUnreachable => '无法连接 App Store。关闭后重新打开即可重试。';

  @override
  String get supportPending => '等待批准。批准后购买即完成。';

  @override
  String get supportRestoreNoneTitle => '没有可恢复的购买';

  @override
  String get supportRestoreNoneBody => '此 Apple ID 未关联任何俱乐部购买。';

  @override
  String get supportFailedTitle => '未能完成';

  @override
  String get supportFailedBody => 'App Store 未能完成。请重试。';

  @override
  String get supportPrivacy => '隐私政策';

  @override
  String get supportTerms => '使用条款';

  @override
  String get supportUnlocksSection => '你会得到';

  @override
  String get supporterTag => '俱乐部';

  @override
  String supportFooter(String privacy, String terms) {
    return '支持不会改变任何隐私设定，日记永远不会离开手机（见$privacy）。购买遵循 Apple 的标准$terms。';
  }

  @override
  String get continueRecording => '继续录音';

  @override
  String continuingEntry(String title) {
    return '继续$title';
  }

  @override
  String get continueUntranscribedLabel => '新增部分未转写';

  @override
  String get continueUntranscribedTitle => '新增部分未被转写';

  @override
  String get continueUntranscribedBody => '录音已加长，但刚添加的话没有转写。重新转写即可听到全部内容。';

  @override
  String get continueSavedSeparatelyLabel => '已保存为新条目';

  @override
  String get continueSavedSeparatelyBody => '新录音无法合并到此条目，因此已单独保存。';

  @override
  String get continueEntryBusy => '此条目仍在转写中。';
}
