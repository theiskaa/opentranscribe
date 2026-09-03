import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/layouts/onboarding/components/onboarding_page.dart';
import 'package:opentranscribe/view/layouts/onboarding/components/scene_clock.dart';
import 'package:opentranscribe/view/layouts/recorder/components/live_transcript.dart';
import 'package:opentranscribe/view/layouts/recorder/components/waveform.dart';

/// The first page: a take, running once. The recorder's own band hears a
/// synthetic voice and the recorder's own live text lands what it heard the
/// way a recognizer does: a few words at a time, a beat after they were said,
/// with uneven gaps and a longer breath at the end of a sentence. The take
/// runs to [_takeLength] and stops there, the way a take does.
class OnboardingRecord extends StatelessWidget {
  const OnboardingRecord({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return OnboardingPage(
      scene: const _RecordScene(),
      title: l10n.onboardingRecordTitle,
      body: l10n.onboardingRecordBody,
    );
  }
}

/// The text as the scene speaks it: its tokens and what joins them back into
/// a string. Sentences in a spaced script speak word by word; sentences in a
/// CJK script speak a character at a time (a Latin run inside them stays one
/// token), each token keeping the space that followed it, and join with
/// nothing.
({List<String> tokens, String joiner}) speechTokens(List<String> sentences) {
  if (!sentences.any(_cjk.hasMatch)) {
    return (tokens: sentences.join(' ').split(' '), joiner: ' ');
  }
  final text = sentences.join();
  return (tokens: [for (final m in _cjkToken.allMatches(text)) m.group(0)!], joiner: '');
}

final _cjk = RegExp('[$cjkRange]');
final _cjkToken = RegExp('(?:[$cjkRange]|[^\\s$cjkRange]+)\\s?');

/// One burst of recognized speech: the voice runs from [speakStart] to
/// [speakEnd], and the recognizer has all [shown] tokens by [lands], a beat
/// later; the live text lands them one at a time on the way, see [tokenLandings].
@immutable
class SpeechBurst {
  const SpeechBurst({
    required this.speakStart,
    required this.speakEnd,
    required this.lands,
    required this.shown,
  });

  final Duration speakStart;
  final Duration speakEnd;
  final Duration lands;
  final int shown;
}

/// Lays [tokens] out as bursts of speech from [first]. Deterministic for a
/// [seed], so the scene plays the same take every time; the sizes and gaps
/// are drawn from ranges a speaker actually produces, and a burst never runs
/// past the end of a sentence, whose pause is the long one.
List<SpeechBurst> speechSchedule(
  List<String> tokens, {
  required Duration first,
  required Duration perToken,
  required int maxBurst,
  int seed = 7,
}) {
  final rng = math.Random(seed);
  Duration jitter(Duration base, double spread) => base * (1 + spread * (rng.nextDouble() * 2 - 1));
  final bursts = <SpeechBurst>[];
  var at = first;
  var shown = 0;
  while (shown < tokens.length) {
    var size = 1 + rng.nextInt(maxBurst);
    if (size == 1 && rng.nextBool()) size = 2;
    var end = shown;
    var closes = false;
    while (end < shown + size && end < tokens.length) {
      end++;
      if (_sentenceEnd.hasMatch(tokens[end - 1])) {
        closes = true;
        break;
      }
    }
    final spoken = jitter(perToken * (end - shown), 0.25);
    final speakStart = at;
    final speakEnd = speakStart + spoken;
    final lands = speakEnd + jitter(_recognizerLag, 0.4);
    bursts.add(SpeechBurst(speakStart: speakStart, speakEnd: speakEnd, lands: lands, shown: end));
    at = speakEnd + jitter(closes ? _sentencePause : _burstGap, 0.45);
    shown = end;
  }
  return bursts;
}

final _sentenceEnd = RegExp(r'[.!?。！？]\s?$');

/// The same [bursts] stretched or squeezed in time from [first] so the last
/// one is recognized at [end]: the take then speaks until it stops, whatever
/// the locale's word count, instead of going quiet for its final seconds.
List<SpeechBurst> fitSchedule(
  List<SpeechBurst> bursts, {
  required Duration first,
  required Duration end,
}) {
  if (bursts.isEmpty) return bursts;
  final span = bursts.last.lands - first;
  if (span <= Duration.zero) return bursts;
  final scale = (end - first).inMicroseconds / span.inMicroseconds;
  Duration fit(Duration at) => first + (at - first) * scale;
  return [
    for (final b in bursts)
      SpeechBurst(
        speakStart: fit(b.speakStart),
        speakEnd: fit(b.speakEnd),
        lands: fit(b.lands),
        shown: b.shown,
      ),
  ];
}

/// When each token lands in the live text: spoken in turn through its burst,
/// each one [lag] behind the voice, so the words keep pace with the band
/// instead of arriving in a block once the burst is over.
List<Duration> tokenLandings(List<SpeechBurst> bursts, {required Duration lag}) {
  final landings = <Duration>[];
  var from = 0;
  for (final burst in bursts) {
    final count = burst.shown - from;
    final perToken = (burst.speakEnd - burst.speakStart) ~/ count;
    for (var i = 1; i <= count; i++) {
      landings.add(burst.speakStart + perToken * i + lag);
    }
    from = burst.shown;
  }
  return landings;
}

/// Tokens shown by [elapsed]: those whose landing has passed.
int tokensShownBy(Duration elapsed, List<Duration> landings) {
  var shown = 0;
  while (shown < landings.length && landings[shown] <= elapsed) {
    shown++;
  }
  return shown;
}

/// Whether a burst is being spoken at [elapsed].
bool speakingAt(Duration elapsed, List<SpeechBurst> bursts) =>
    bursts.any((burst) => burst.speakStart <= elapsed && elapsed < burst.speakEnd);

const _takeLength = Duration(seconds: 42);
const _firstBurst = Duration(milliseconds: 500);

/// How long before the stop the last words are recognized.
const _lastBreath = Duration(milliseconds: 700);
const _recognizerLag = Duration(milliseconds: 180);
const _burstGap = Duration(milliseconds: 260);
const _sentencePause = Duration(milliseconds: 1300);

/// A spoken word's length and the most words a burst carries; the same for a
/// character where the script has no spaces.
const _perWord = Duration(milliseconds: 230);
const _wordsPerBurst = 5;
const _perCharacter = Duration(milliseconds: 95);
const _charactersPerBurst = 9;

/// The band samples at the recorder's own cadence.
const _sampleEvery = Duration(milliseconds: 50);

class _RecordScene extends StatefulWidget {
  const _RecordScene();

  @override
  State<_RecordScene> createState() => _RecordSceneState();
}

class _RecordSceneState extends State<_RecordScene> with SingleTickerProviderStateMixin {
  SceneClock? _clock;

  /// Whether the take is still running: the one thing the band needs from the
  /// clock. Its own notifier, so the band is not rebuilt (and its painter not
  /// remade) on every tick the words need.
  final ValueNotifier<bool> _running = ValueNotifier(true);

  /// The take as the current locale speaks it, laid out once per dependency
  /// change rather than per tick.
  late ({List<String> tokens, String joiner}) _speech;
  late List<SpeechBurst> _bursts;
  late List<Duration> _landings;

  /// The band's input, fed from the clock: one level per sample tick. One
  /// stream object for the band's whole life: a broadcast controller mints a
  /// new Stream per `stream` read, and a new one each frame would make the band
  /// resubscribe every frame and lose every sample in flight.
  final StreamController<double> _levels = StreamController<double>.broadcast();
  late final Stream<double> _stream = _levels.stream;
  Duration _lastSample = Duration.zero;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l10n = AppLocalizations.of(context)!;
    _speech = speechTokens([
      l10n.onboardingRecordText1,
      l10n.onboardingRecordText2,
      l10n.onboardingRecordText3,
      l10n.onboardingRecordText4,
      l10n.onboardingRecordText5,
      l10n.onboardingRecordText6,
    ]);
    final byCharacter = _speech.joiner.isEmpty;
    _bursts = fitSchedule(
      speechSchedule(
        _speech.tokens,
        first: _firstBurst,
        perToken: byCharacter ? _perCharacter : _perWord,
        maxBurst: byCharacter ? _charactersPerBurst : _wordsPerBurst,
      ),
      first: _firstBurst,
      end: _takeLength - _lastBreath,
    );
    _landings = tokenLandings(_bursts, lag: _recognizerLag);
    // Reduce Motion is an inherited read, which initState may not make. Decided
    // once, like EntranceRise.
    if (_clock == null) {
      final clock = SceneClock(length: _takeLength, vsync: this, reduceMotion: context.reduceMotion)
        ..addListener(_tick);
      _clock = clock;
      _running.value = clock.elapsed < _takeLength;
    }
  }

  void _tick() {
    final elapsed = _clock!.elapsed;
    _running.value = elapsed < _takeLength;
    if (_running.value) _feed(elapsed, speakingAt(elapsed, _bursts));
  }

  @override
  void dispose() {
    _clock?.dispose();
    _running.dispose();
    unawaited(_levels.close());
    super.dispose();
  }

  void _feed(Duration elapsed, bool speaking) {
    if (elapsed - _lastSample < _sampleEvery) return;
    _lastSample = elapsed;
    _levels.add(_voice(elapsed, speaking));
  }

  /// A speech-shaped level in the recorder's -60..0 dB window: syllables at
  /// ~4 Hz under a slower word envelope, a little jitter, room tone between.
  static double _voice(Duration at, bool speaking) {
    final t = at.inMicroseconds / Duration.microsecondsPerSecond;
    final jitter = math.sin(t * 91.7) * 0.06;
    if (!speaking) return 0.08 + jitter.abs();
    final syllable = math.pow(math.sin(t * 2 * math.pi * 4.3), 2).toDouble();
    final word = 0.55 + 0.45 * math.pow(math.sin(t * 2 * math.pi * 1.1 + 0.4), 2);
    return (0.24 + 0.6 * syllable * word + jitter).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final clock = _clock!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: _running,
          builder: (context, running, _) => Waveform(levels: _stream, active: running),
        ),
        const SizedBox(height: AppSpacing.lg),
        ListenableBuilder(
          listenable: clock,
          builder: (context, _) {
            final shown = tokensShownBy(clock.elapsed, _landings);
            return LiveTranscript(text: _speech.tokens.take(shown).join(_speech.joiner));
          },
        ),
      ],
    );
  }
}
