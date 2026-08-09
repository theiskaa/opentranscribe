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
  String get themeNameSolarized => 'Solarized';

  @override
  String get themeNameSepia => 'Sepia';

  @override
  String get settingsAppLanguage => '语言';

  @override
  String get transcriptionInfo => '每种语言都使用各自的设备端模型，下载一次后与系统共享；模型不计入本应用的存储占用。系统会限制一个应用同时可保持就绪的语言数量。';

  @override
  String transcriptionCap(int used, int max) {
    return '已使用 $max 个语言名额中的 $used 个';
  }

  @override
  String get transcriptionRemoveHint => '向左滑动某种语言即可移除。';

  @override
  String get transcriptionErrorUnsupported => '本机暂时无法下载该语言。';

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
  String get transcriptionLanguages => '语言';

  @override
  String get transcriptionDefaultTag => '默认';

  @override
  String get transcriptionDefaultHint => '轻触并按住某种语言，即可将其设为默认。';

  @override
  String transcriptionDeviceLanguageFallback(String fallback) {
    return '你手机的语言暂不支持设备端转写，因此默认使用 $fallback。';
  }

  @override
  String get onboardingIntroBody => '你说出心中所想，它替你记录成文。';

  @override
  String get onboardingSpeakTitle => '只管说';

  @override
  String get onboardingSpeakLine => '点击录制，说出你的想法。';

  @override
  String get onboardingWriteTitle => '回看文字';

  @override
  String get onboardingWriteLine => '每段录音都会转写成文字。';

  @override
  String get onboardingPrivateTitle => '一切都不离开手机';

  @override
  String get onboardingPrivateLine => '无账号、无云端。开启飞行模式也毫无影响。';

  @override
  String get onboardingReflectTitle => '回顾';

  @override
  String get onboardingReflectLine => '你的记录会汇成一段简短的笔记，全部在设备上完成。';

  @override
  String get onboardingSource => '开源';

  @override
  String get onboardingSourceLine => '每一行代码都是公开的。可在 GitHub 上查看。';

  @override
  String get onboardingPermissionsTitle => '允许访问';

  @override
  String get onboardingPermissionsBody => '这一切都完全在你的设备上运行。';

  @override
  String get onboardingMicName => '麦克风';

  @override
  String get onboardingMicReason => '用于录制你的声音。';

  @override
  String get onboardingSpeechName => '语音识别';

  @override
  String get onboardingSpeechReason => '用于在设备上把录音转成文字。';

  @override
  String get onboardingNotifyName => '通知';

  @override
  String get onboardingNotifyReason => '回顾准备好时提醒你。';

  @override
  String get onboardingAllow => '允许';

  @override
  String get onboardingOpenSettings => '在“设置”中启用';

  @override
  String get onboardingModelsTitle => '设置转写';

  @override
  String get onboardingModelsBody => '只要设备上有了你的语言，转写就会离线进行。你随时可以从菜单中添加更多。';

  @override
  String get onboardingReflectionsOn => '你的记录会汇成一段简短回顾，完全在此设备上完成。';

  @override
  String get onboardingReflectionsPreparing => 'Apple Intelligence 在此设备上准备完成后即会开始。';

  @override
  String get onboardingReflectionsOff => '在“设置”的“Apple Intelligence 与 Siri”中开启即可使用。';

  @override
  String get onboardingNext => '下一步';

  @override
  String get onboardingStart => '开始使用';

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
  String get themeRequestInfo => '想要这里没有的主题吗？在 GitHub 上创建一个 issue，我们会在后续版本中添加。';

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
  String get exportFormatMarkdownNote => '每条记录一个文本文件，外加 .json。';

  @override
  String get exportFormatObsidian => 'Obsidian';

  @override
  String get exportFormatObsidianNote => '带属性和内嵌音频的笔记。';

  @override
  String get exportFormatWeb => '网站';

  @override
  String get exportFormatWebNote => '任何浏览器都能打开，带播放器。';

  @override
  String get exportFailedTitle => '导出失败';

  @override
  String get exportFailedBody => '无法准备文件。未共享任何内容。';

  @override
  String get exportUntitled => '无标题';

  @override
  String get exportTranscriptHeading => '转写';

  @override
  String get exportQuiet => '一段安静的时光。';

  @override
  String get settingsBackup => '备份';

  @override
  String get backupInfo => '备份包含所有记录、音频和回顾。如果加密，口令就是唯一的钥匙。';

  @override
  String backupInfoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '备份包含 $count 条记录、音频和回顾。如果加密，口令就是唯一的钥匙。',
      zero: '暂时没有可备份的内容。备份包含记录、音频和回顾。',
    );
    return '$_temp0';
  }

  @override
  String get backupExportSection => '导出';

  @override
  String get backupExportJournal => '导出日记';

  @override
  String get backupExportInfo => '以所选格式写出每条记录，连同音频打包成 zip，交给共享面板。这是给其他应用阅读的副本；要恢复得靠备份。';

  @override
  String get backupSeal => '用口令加密';

  @override
  String get backupSave => '保存备份';

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
  String get importConfirmBody => '把其中的记录加入你的日记。同一份备份恢复两次也不会重复。';

  @override
  String get importConfirm => '恢复';

  @override
  String get importSummaryTitle => '恢复完成';

  @override
  String importSummaryImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '已恢复 $count 条记录。',
      zero: '没有新内容可恢复。',
    );
    return '$_temp0';
  }

  @override
  String importSummarySkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count 条记录已在日记中。');
    return '$_temp0';
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
}
