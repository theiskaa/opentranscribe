import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/view/widgets/app_spinner.dart';
import 'package:opentranscribe/view/widgets/invisible_ink.dart';

/// What the caller wants the text to be doing.
enum InkPhase {
  /// The child renders plain; no tickers run.
  settled,

  /// The child arrives by writing itself: its own ink shimmers, then resolves
  /// into the text. Plays once; the caller flips to [settled] (or keeps a
  /// ledger) after [InkReveal.onWriteStarted].
  write,

  /// Work is in flight: the current text dissolves into a living cloud (or a
  /// placeholder cloud shimmers when there is no text yet) until the caller
  /// transitions out - to [write] when new words landed, to [settled] when the
  /// run failed and the old words return.
  pending,
}

/// The invisible-ink driver for text that arrives by being written in place:
/// wraps [child] in a capture boundary, owns the crossfade and the shimmer
/// clock, and gates the whole effect on Reduce Motion (immediate text; a plain
/// spinner while pending). [InvisibleInk] itself always shimmers; every
/// choreography decision lives here.
///
/// The write-on never shows bare text early: the first frame renders the child
/// under an opaque [background] sheet so a painted frame exists to capture,
/// then the cloud fades in from that capture. The write begins as soon as
/// that frame exists; whether a begun write counts as seen is the caller's
/// ledger's decision, not this widget's.
class InkReveal extends StatefulWidget {
  const InkReveal({
    required this.child,
    required this.phase,
    required this.color,
    required this.background,
    this.placeholderLines = 4,
    this.onWriteStarted,
    super.key,
  });

  final Widget child;
  final InkPhase phase;

  /// The ink colour, usually the text's own.
  final Color color;

  /// The page background, used to cover the capture frame.
  final Color background;

  /// Placeholder cloud height, in [AppType.body] lines, when pending has no
  /// text to dissolve.
  final int placeholderLines;

  /// Fired once when a write-on actually begins (or is skipped under Reduce
  /// Motion), so the caller can mark its replay ledger.
  final VoidCallback? onWriteStarted;

  @override
  State<InkReveal> createState() => _InkRevealState();
}

class _InkRevealState extends State<InkReveal> with TickerProviderStateMixin {
  /// Wraps the child so its last painted frame can be captured.
  final GlobalKey _textKey = GlobalKey();

  /// 1 shows the text, 0 shows the cloud; created eagerly so a widget disposed
  /// without ever shimmering does not create its ticker during teardown.
  late final AnimationController _reveal;
  late final Animation<double> _hide;

  /// The seamless shimmer loop; its lap is [AppMotion.inkLoop].
  late final AnimationController _clock;

  ui.Image? _inkImage;
  Float32List? _inkPoints;
  Size? _inkSize;
  double _inkDpr = 1;

  /// Identifies the current run, so a delayed continuation from a superseded
  /// one cannot act on the wrong state.
  int _run = 0;

  bool _shimmering = false;

  /// The cloud has held its beat and may resolve.
  bool _inkHeld = false;

  /// An arrival (pending -> write) landed before the hold elapsed.
  bool _arrivalQueued = false;

  /// This widget's write finished or was skipped; the child renders plain even
  /// while the parent still says [InkPhase.write].
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _reveal = AnimationController(vsync: this, value: 1);
    _hide = ReverseAnimation(_reveal);
    _clock = AnimationController(vsync: this);
  }

  @override
  void didUpdateWidget(InkReveal old) {
    super.didUpdateWidget(old);
    if (old.phase == widget.phase) return;

    if (widget.phase == InkPhase.pending) {
      _beginDissolve(hadText: old.phase != InkPhase.write || _done);
      return;
    }
    if (old.phase != InkPhase.pending) return;

    if (widget.phase == InkPhase.write) {
      // New words landed while the cloud was up: resolve into them. No fresh
      // capture; the cloud already carries the old shape (or the placeholder).
      _resolveArrival();
      return;
    }
    // pending -> settled: the run failed, the old words return. A quick
    // crossfade, not the slow arrival, which new words alone have earned.
    _failBack();
  }

  /// Text (or nothing) -> cloud. With text on screen the capture succeeds and
  /// the words dissolve; without one the placeholder cloud fades in.
  void _beginDissolve({required bool hadText}) {
    if (context.reduceMotion) {
      _stopShimmer();
      setState(() => _shimmering = false);
      return;
    }
    final run = ++_run;
    _inkHeld = false;
    _arrivalQueued = false;
    _done = false;
    final prepared = hadText && _capture() || _preparePlaceholder();
    if (!prepared) return;
    setState(() => _shimmering = true);
    _clock
      ..duration = context.motionNow.inkLoop
      ..repeat();
    _reveal.duration = context.motionNow.inkDissolve;
    _reveal.reverse().whenComplete(() => _holdThen(run));
  }

  /// The write-on's second half, and the arrival's whole: cloud -> text.
  void _resolveArrival() {
    if (!_shimmering) {
      // The cloud never formed (Reduce Motion, or a failed capture): the new
      // words simply render plain.
      setState(() => _done = true);
      _markStarted();
      return;
    }
    _arrivalQueued = true;
    _tryResolve(_run);
  }

  void _failBack() {
    if (!_shimmering) return;
    final run = ++_run;
    _reveal.duration = context.motionNow.crossfade;
    _reveal.forward().whenComplete(() {
      if (!mounted || run != _run) return;
      setState(() => _shimmering = false);
      _stopShimmer();
    });
  }

  void _holdThen(int run) {
    Future<void>.delayed(context.motionNow.inkHold, () {
      if (!mounted || run != _run) return;
      _inkHeld = true;
      _tryResolve(run);
    });
  }

  void _tryResolve(int run) {
    if (run != _run || !_inkHeld || !_arrivalQueued || !_shimmering) return;
    _markStarted();
    _reveal.duration = context.motionNow.inkResolve;
    _reveal.forward().whenComplete(() {
      if (!mounted || run != _run) return;
      setState(() {
        _shimmering = false;
        _done = true;
      });
      _stopShimmer();
    });
  }

  /// The write-on's first half, kicked post-frame from build once a covered
  /// frame has painted: capture the child, then shimmer its own ink.
  void _beginWrite() {
    if (!mounted || widget.phase != InkPhase.write || _done || _shimmering) return;
    final run = ++_run;
    if (!_capture()) {
      // No usable frame: arrive with a plain fade instead of a blank page.
      setState(() => _done = true);
      _markStarted();
      return;
    }
    setState(() => _shimmering = true);
    _markStarted();
    _inkHeld = false;
    _arrivalQueued = true; // the words are already here; only the hold gates
    _reveal.value = 0;
    _clock
      ..duration = context.motionNow.inkLoop
      ..repeat();
    _holdThen(run);
  }

  bool _capture() {
    final boundary = _textKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) return false;
    if (!boundary.hasSize || boundary.size.isEmpty) return false;
    try {
      final dpr = MediaQuery.devicePixelRatioOf(context);
      _releaseInk();
      _inkImage = boundary.toImageSync(pixelRatio: dpr);
      // A plain copy: RenderBox.size hands back a debug size that tracks its
      // owner, and reusing it once the boundary detaches trips debugAdoptSize.
      _inkSize = Size(boundary.size.width, boundary.size.height);
      _inkDpr = dpr;
      return true;
    } catch (_) {
      return false;
    }
  }

  bool _preparePlaceholder() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return false;
    final width = box.size.width;
    if (width <= 0) return false;
    const style = AppType.body;
    // The reader's text scale sizes the cloud like the text it stands for.
    final fontSize = MediaQuery.textScalerOf(context).scale(style.fontSize!);
    final lineHeight = fontSize * style.height!;
    _releaseInk();
    _inkPoints = placeholderInkPoints(
      width: width,
      lines: widget.placeholderLines,
      fontSize: fontSize,
      lineHeight: lineHeight,
    );
    _inkSize = Size(width, widget.placeholderLines * lineHeight);
    return true;
  }

  void _markStarted() {
    final started = widget.onWriteStarted;
    if (started == null) return;
    // Post-frame: the parent's ledger write may setState, and this can run
    // inside a build/transition callback.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) started();
    });
  }

  void _stopShimmer() {
    _clock.stop();
    _releaseInk();
  }

  void _releaseInk() {
    _inkImage?.dispose();
    _inkImage = null;
    _inkPoints = null;
    _inkSize = null;
  }

  @override
  void dispose() {
    _reveal.dispose();
    _clock.dispose();
    _releaseInk();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = context.reduceMotion;
    final boundedChild = RepaintBoundary(key: _textKey, child: widget.child);

    if (widget.phase == InkPhase.pending && !_shimmering) {
      if (reduceMotion) return _PendingSpinner(color: widget.color);
      // First pending build before didUpdateWidget ran (mounted straight into
      // pending): form the cloud once the first frame exists.
      _schedule(() => _beginDissolve(hadText: false));
      return _PendingSpinner(color: widget.color);
    }

    final inkSize = _inkSize;
    if (_shimmering && inkSize != null && (_inkImage != null || _inkPoints != null)) {
      return Stack(
        children: [
          // Opacity does not block hit testing; without the IgnorePointers a
          // tap on the glitter would land on the invisible text.
          IgnorePointer(
            child: FadeTransition(opacity: _reveal, child: boundedChild),
          ),
          IgnorePointer(
            child: FadeTransition(
              opacity: _hide,
              child: _inkImage != null
                  ? InvisibleInk(
                      image: _inkImage!,
                      size: inkSize,
                      pixelRatio: _inkDpr,
                      color: widget.color,
                      clock: _clock,
                    )
                  : InvisibleInk.points(
                      points: _inkPoints!,
                      size: inkSize,
                      color: widget.color,
                      clock: _clock,
                    ),
            ),
          ),
        ],
      );
    }

    if (widget.phase == InkPhase.write && !_done && !reduceMotion) {
      _schedule(_beginWrite);
      // Covered, not hidden: the child must PAINT for the capture, but the
      // user must never see the bare text before its ink writes it.
      return Stack(
        children: [
          boundedChild,
          Positioned.fill(child: ColoredBox(color: widget.background)),
        ],
      );
    }

    if (widget.phase == InkPhase.write && !_done && reduceMotion) {
      // Reduce Motion: the text simply is there; mark so the ledger agrees.
      _schedule(() {
        if (mounted && !_done) {
          setState(() => _done = true);
          _markStarted();
        }
      });
    }
    return boundedChild;
  }

  void _schedule(VoidCallback callback) {
    final run = _run;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && run == _run) callback();
    });
  }
}

/// The Reduce Motion (and no-cloud) stand-in while work is in flight: the
/// sanctioned dots, left-aligned like a forming paragraph.
class _PendingSpinner extends StatelessWidget {
  const _PendingSpinner({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: AppSpinner(size: 30, color: color),
      ),
    );
  }
}
