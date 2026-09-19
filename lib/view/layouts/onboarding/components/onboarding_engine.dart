import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/state/engines_cubit.dart';
import 'package:opentranscribe/core/state/models_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/superellipse.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/layouts/onboarding/components/onboarding_page.dart';
import 'package:opentranscribe/view/layouts/onboarding/components/onboarding_record.dart';
import 'package:opentranscribe/view/layouts/onboarding/components/scene_clock.dart';
import 'package:opentranscribe/view/layouts/recorder/components/waveform.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/app_sheet.dart';
import 'package:opentranscribe/view/widgets/engine_picker.dart';
import 'package:opentranscribe/view/widgets/formatting.dart';
import 'package:opentranscribe/view/widgets/ink_reveal.dart';
import 'package:opentranscribe/view/widgets/invisible_ink.dart';
import 'package:opentranscribe/view/widgets/melt_stack.dart';
import 'package:opentranscribe/view/widgets/model_card.dart';
import 'package:opentranscribe/view/widgets/model_sheet.dart';
import 'package:opentranscribe/view/widgets/segmented_control.dart';
import 'package:opentranscribe/view/widgets/sheet_message.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';
import 'package:transcriber/transcriber.dart';

/// The page's two answers.
enum WordsWhen { asYouSpeak, afterYouStop }

WordsWhen wordsWhenOf(EngineRowState row) =>
    row.live ? WordsWhen.asYouSpeak : WordsWhen.afterYouStop;

/// The engines that answer [when], in registry order.
List<EngineRowState> enginesAnswering(List<EngineRowState> rows, WordsWhen when) => [
  for (final row in rows)
    if (wordsWhenOf(row) == when) row,
];

/// The one engine an answer stands for: the first that runs here, in
/// registry order. Null when nothing under [when] runs on this phone.
String? engineForAnswer(List<EngineRowState> rows, WordsWhen when) =>
    enginesAnswering(rows, when).where((row) => row.available).firstOrNull?.descriptor.engineId;

/// The selected model, or the largest that fits when it is too large and not
/// here (the catalog runs small to large). Null when none stands.
String? fittingModelId(List<ModelRowState> models) {
  final selected = models.where((row) => row.selected).firstOrNull;
  if (selected == null) return null;
  if (!selected.heavy || selected.installed) return selected.option.id;
  return models.where((row) => !row.heavy).lastOrNull?.option.id;
}

/// The model to switch to so the choice fits this phone, null when it does.
String? modelSwap(ModelsState state) {
  final id = fittingModelId(state.models);
  return id == state.selectedModel?.option.id ? null : id;
}

/// Applies [modelSwap]; true when it had one to apply. A failed persist keeps
/// the choice for the session, which is all onboarding needs.
Future<bool> settleModel(ModelsCubit cubit) async {
  final id = modelSwap(cubit.state);
  if (id == null) return false;
  try {
    await cubit.selectModel(id);
  } catch (_) {}
  return true;
}

/// Whether leaving the page starts the chosen model's download.
bool downloadsOnLeave(ModelsState state) {
  final selected = state.selectedModel;
  return state.offersModelChoice &&
      selected != null &&
      !selected.installed &&
      !selected.installing &&
      !selected.heavy;
}

/// The engine page: the answer picks the engine, a short take plays it, and a
/// slot under the take names who writes the words, or which model does.
class OnboardingEngine extends StatelessWidget {
  const OnboardingEngine({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return OnboardingPage(
      scene: const _EngineScene(),
      title: l10n.onboardingEngineTitle,
      body: l10n.onboardingEngineBody,
    );
  }
}

class _EngineScene extends StatefulWidget {
  const _EngineScene();

  @override
  State<_EngineScene> createState() => _EngineSceneState();
}

class _EngineSceneState extends State<_EngineScene> {
  /// The engine a pick waits on, so the take follows the tap mid-pick.
  String? _pending;

  /// The answer tapped, until settled: only a changed selection moves the
  /// native control back after a refusal.
  WordsWhen? _asking;

  @override
  void initState() {
    super.initState();
    unawaited(settleModel(context.read<ModelsCubit>()));
  }

  Future<void> _answer(List<EngineRowState> rows, WordsWhen when) async {
    if (_asking != null || wordsWhenOf(shownRow(rows)) == when || !isTopRoute(context)) return;
    final l10n = AppLocalizations.of(context)!;
    final id = engineForAnswer(rows, when);
    setState(() {
      _asking = when;
      _pending = id;
    });
    try {
      if (id != null) {
        await pickEngine(context, id);
      } else if (enginesAnswering(rows, when).firstOrNull case final row?) {
        await showAppSheet<void>(
          context,
          builder: (context) => SheetMessage(
            icon: row.descriptor.logo,
            title: l10n.engineUnavailableTitle,
            body: engineUnavailableBody(l10n, row),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _asking = null;
          _pending = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocListener<ModelsCubit, ModelsState>(
      listenWhen: (previous, current) =>
          modelSwap(current) != null && modelSwap(current) != modelSwap(previous),
      listener: (context, _) => unawaited(settleModel(context.read<ModelsCubit>())),
      child: BlocBuilder<EnginesCubit, EnginesState>(
        builder: (context, state) {
          final rows = state.rows;
          if (rows.isEmpty) return const SizedBox.shrink();
          final shown = shownRow(rows, pending: _pending);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSegmentedControl<WordsWhen>(
                segments: [
                  (WordsWhen.asYouSpeak, l10n.onboardingEngineAsYouSpeak),
                  (WordsWhen.afterYouStop, l10n.onboardingEngineAfterYouStop),
                ],
                selected: _asking ?? wordsWhenOf(shown),
                onChanged: (answer) => unawaited(_answer(rows, answer)),
              ),
              const SizedBox(height: AppSpacing.md),
              _TakeCard(shown: shown, rows: rows),
            ],
          );
        },
      ),
    );
  }
}

class _TakeCard extends StatelessWidget {
  const _TakeCard({required this.shown, required this.rows});

  final EngineRowState shown;
  final List<EngineRowState> rows;

  @override
  Widget build(BuildContext context) {
    final tokens = context.theme.settings;
    return DecoratedBox(
      decoration: SuperellipseDecoration(
        borderRadius: tokens.cardRadius,
        color: tokens.cardBackground,
        border: BorderSide(color: tokens.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: tokens.rowPadding,
            child: _Take(when: wordsWhenOf(shown)),
          ),
          Container(height: 1, color: tokens.dividerColor),
          Padding(
            padding: tokens.rowPadding,
            child: _Slot(shown: shown, rows: rows),
          ),
        ],
      ),
    );
  }
}

const _takeLength = Duration(seconds: 7);
const _firstWord = Duration(milliseconds: 400);
const _lastWord = Duration(milliseconds: 6400);
const _perWord = Duration(milliseconds: 230);
const _wordsPerBurst = 5;
const _perCharacter = Duration(milliseconds: 95);
const _charactersPerBurst = 9;
const _wordLag = Duration(milliseconds: 180);

/// How long a landed word takes to come fully in.
const _wordFade = Duration(milliseconds: 220);

/// How long the previous take's words take to fade out after a change.
const _carryFade = Duration(milliseconds: 260);

/// A short take, replayed on every answer. One ink surface serves both
/// answers, so a change dissolves what is on screen instead of swapping it.
class _Take extends StatefulWidget {
  const _Take({required this.when});

  final WordsWhen when;

  @override
  State<_Take> createState() => _TakeState();
}

class _TakeState extends State<_Take> with TickerProviderStateMixin {
  /// A band and a line height sized for a card on a page, not the recorder's
  /// full screen: the page has to fit an SE without scrolling.
  static const double _bandHeight = 32;
  static const double _lineHeight = 1.35;

  SceneClock? _clock;
  final ValueNotifier<bool> _running = ValueNotifier(true);
  final StreamController<double> _levels = StreamController<double>.broadcast();
  late final Stream<double> _stream = _levels.stream;
  Duration _lastSample = Duration.zero;

  late ({List<String> tokens, String joiner}) _speech;
  late List<SpeechBurst> _bursts;
  late List<Duration> _landings;

  /// Each word's opacity at the last answer change, so the next take starts
  /// from what the eye had.
  List<double> _carried = const [];

  /// Mounted straight into its cloud, the ink shows a spinner for a frame.
  bool _inkArmed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _inkArmed = true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l10n = AppLocalizations.of(context)!;
    _speech = speechTokens([l10n.onboardingRecordText3]);
    final byCharacter = _speech.joiner.isEmpty;
    _bursts = fitSchedule(
      speechSchedule(
        _speech.tokens,
        first: _firstWord,
        perToken: byCharacter ? _perCharacter : _perWord,
        maxBurst: byCharacter ? _charactersPerBurst : _wordsPerBurst,
      ),
      first: _firstWord,
      end: _lastWord,
    );
    _landings = tokenLandings(_bursts, lag: _wordLag);
    if (_carried.length != _speech.tokens.length) {
      _carried = List.filled(_speech.tokens.length, 0);
    }
    if (_clock == null) _startClock();
  }

  @override
  void didUpdateWidget(_Take old) {
    super.didUpdateWidget(old);
    if (old.when == widget.when) return;
    _carried = _alphas(old.when);
    _clock?.dispose();
    _clock = null;
    _lastSample = Duration.zero;
    _startClock();
  }

  void _startClock() {
    final clock = SceneClock(length: _takeLength, vsync: this, reduceMotion: context.reduceMotion)
      ..addListener(_tick);
    _clock = clock;
    _running.value = clock.elapsed < _takeLength;
  }

  void _tick() {
    final elapsed = _clock!.elapsed;
    _running.value = elapsed < _takeLength;
    if (!_running.value || elapsed - _lastSample < sceneSampleEvery) return;
    _lastSample = elapsed;
    _levels.add(sceneVoiceLevel(elapsed, speaking: speakingAt(elapsed, _bursts)));
  }

  @override
  void dispose() {
    _clock?.dispose();
    _running.dispose();
    unawaited(_levels.close());
    super.dispose();
  }

  String get _text => _speech.tokens.join(_speech.joiner);

  /// What each word shows under [when] right now.
  List<double> _alphas(WordsWhen when) {
    final elapsed = _clock!.elapsed;
    return [
      for (final (i, landing) in _landings.indexed)
        switch (when) {
          WordsWhen.asYouSpeak => math.max(
            landedFraction(elapsed, landing, fade: _wordFade),
            _carried[i] * (1 - landedFraction(elapsed, Duration.zero, fade: _carryFade)),
          ),
          // Under the cloud the words stay as they were; the ink fades them.
          WordsWhen.afterYouStop => elapsed < _takeLength ? _carried[i] : 1,
        },
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final style = AppType.boldAware(
      AppType.subhead.copyWith(color: theme.text, height: _lineHeight),
      bold: MediaQuery.boldTextOf(context),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: _running,
          builder: (context, running, _) =>
              Waveform(levels: _stream, active: running, height: _bandHeight),
        ),
        const SizedBox(height: AppSpacing.sm),
        Stack(
          children: [
            Visibility(
              visible: false,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: Text(_text, style: style),
            ),
            Positioned.fill(
              child: ListenableBuilder(
                listenable: _clock!,
                builder: (context, _) {
                  final alphas = _alphas(widget.when);
                  return InkReveal(
                    phase: widget.when == WordsWhen.asYouSpeak || !_inkArmed
                        ? InkPhase.settled
                        : _running.value
                        ? InkPhase.pending
                        : InkPhase.write,
                    color: theme.text,
                    background: theme.settings.cardBackground,
                    placeholderRows: (width, scaler) => textInkRows(
                      text: _text,
                      style: style,
                      width: width,
                      scaler: scaler,
                      locale: Localizations.maybeLocaleOf(context),
                    ),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          for (final (i, token) in _speech.tokens.indexed)
                            TextSpan(
                              text: i == _speech.tokens.length - 1 ? token : token + _speech.joiner,
                              style: style.copyWith(color: theme.text.withValues(alpha: alphas[i])),
                            ),
                        ],
                      ),
                      style: style,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// How far a word landing at [landing] has come in by [elapsed], over [fade].
double landedFraction(Duration elapsed, Duration landing, {required Duration fade}) {
  if (elapsed < landing) return 0;
  if (fade <= Duration.zero) return 1;
  return ((elapsed - landing).inMicroseconds / fade.inMicroseconds).clamp(0.0, 1.0);
}

/// The ink rows of [text] as it sets at [width], so the cloud stands where
/// the words land.
List<InkRow> textInkRows({
  required String text,
  required TextStyle style,
  required double width,
  required TextScaler scaler,
  required Locale? locale,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: scaler,
    locale: locale,
  )..layout(maxWidth: width);
  final fontSize = scaler.scale(style.fontSize!);
  final rows = <InkRow>[];
  var top = 0.0;
  for (final line in painter.computeLineMetrics()) {
    rows.add((top: top, fontSize: fontSize, lineHeight: line.height, measure: line.width));
    top += line.height;
  }
  painter.dispose();
  return rows;
}

/// Who writes the words: the engine, or its model. Every face it could show
/// lies unseen beneath the real one, so no choice moves the page.
class _Slot extends StatefulWidget {
  const _Slot({required this.shown, required this.rows});

  final EngineRowState shown;
  final List<EngineRowState> rows;

  @override
  State<_Slot> createState() => _SlotState();
}

class _SlotState extends State<_Slot> {
  /// The engine and models that last agreed: models reach a switch a beat
  /// late, and a face drawn from the two apart would melt through a wrong one.
  ({EngineRowState shown, ModelsState models})? _settled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = context.theme;
    return BlocBuilder<ModelsCubit, ModelsState>(
      builder: (context, models) {
        if (_settled == null || models.engineId == widget.shown.descriptor.engineId) {
          _settled = (shown: widget.shown, models: models);
        }
        final (:shown, models: settled) = _settled!;
        final model = settled.offersModelChoice ? settled.selectedModel : null;
        final ghosts = <Widget>[
          for (final row in widget.rows) _EngineFace(shown: row),
          for (final quality in ModelQuality.values)
            _ModelFace.ghost(engine: shown, info: modelTierInfo(l10n, quality)),
        ];
        return Stack(
          children: [
            for (final ghost in ghosts)
              Visibility(
                visible: false,
                maintainSize: true,
                maintainAnimation: true,
                maintainState: true,
                child: ghost,
              ),
            AnimatedSwitcher(
              duration: context.reduceMotion ? Duration.zero : theme.motion.crossfade,
              layoutBuilder: meltStack,
              child: model == null
                  ? _EngineFace(key: ValueKey(shown.descriptor.engineId), shown: shown)
                  : _ModelFace(
                      key: ValueKey((shown.descriptor.engineId, model.option.id)),
                      engine: shown,
                      model: model,
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _EngineFace extends StatelessWidget {
  const _EngineFace({required this.shown, super.key});

  final EngineRowState shown;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final descriptor = shown.descriptor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FaceTitle(
          icon: descriptor.logo,
          title: l10n.onboardingEngineWrittenBy(descriptor.displayName),
        ),
        SizedBox(height: theme.settings.noteGap),
        Text(descriptor.blurb(l10n), style: AppType.note.copyWith(color: theme.textSecondary)),
      ],
    );
  }
}

class _ModelFace extends StatelessWidget {
  const _ModelFace({required this.engine, required ModelRowState this.model, super.key})
    : info = null;

  /// The face's shape around [info], holding the slot's height.
  const _ModelFace.ghost({required this.engine, required String this.info}) : model = null;

  final EngineRowState engine;
  final ModelRowState? model;
  final String? info;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final model = this.model;
    final option = model?.option;
    final note = AppType.note.copyWith(color: theme.textSecondary);
    final size = formatBytes(option?.bytes ?? _ghostBytes, localeTag(context));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FaceTitle(
          icon: engine.descriptor.logo,
          title: option == null
              ? engine.descriptor.displayName
              : '${engine.descriptor.displayName} · ${option.displayName}',
          trailing: Semantics(
            button: true,
            child: Touchable(
              onTap: model == null ? null : () => openModelSheet(context, choosing: true),
              haptic: true,
              child: Text(
                l10n.onboardingEngineChangeModel,
                style: AppType.note.copyWith(color: theme.accent, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
        SizedBox(height: theme.settings.noteGap),
        Text('$size · ${info ?? modelTierInfo(l10n, option!.quality)}', style: note),
      ],
    );
  }
}

/// Reads 999.9 MB, at least as wide as any real download size.
const _ghostBytes = 999900000;

class _FaceTitle extends StatelessWidget {
  const _FaceTitle({required this.icon, required this.title, this.trailing});

  final IconData icon;
  final String title;
  final Widget? trailing;

  static const double _glyph = 16;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Row(
      children: [
        AppIcon(icon, size: _glyph, color: theme.textSecondary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.subhead.copyWith(color: theme.text, fontWeight: FontWeight.w600),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: AppSpacing.sm), trailing!],
      ],
    );
  }
}
