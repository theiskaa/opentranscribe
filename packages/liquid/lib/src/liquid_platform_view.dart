import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart' show PlatformViewHitTestBehavior;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

typedef LiquidMethodCallHandler = Future<void> Function(MethodCall call);

class LiquidPlatformView extends StatefulWidget {
  const LiquidPlatformView({
    required this.viewType,
    required this.creationParams,
    this.creationOnlyParamKeys = const {},
    this.onMethodCall,
    this.onChannelReady,
    this.placeholderBuilder,
    this.hitTestBehavior = PlatformViewHitTestBehavior.opaque,
    super.key,
  });

  final String viewType;
  final Map<String, dynamic> creationParams;

  /// Pass [PlatformViewHitTestBehavior.transparent] for purely decorative
  /// views (the edge-fade material) so touches fall through to Flutter content
  /// behind them.
  final PlatformViewHitTestBehavior hitTestBehavior;

  /// Keys in [creationParams] that only matter when the native view is
  /// (re)created — e.g. an `initialIndex` the native side ignores after its
  /// first apply. A change to these keys alone does not push an `update` to
  /// the live native view, so a parent rebuild can't disturb it mid-animation,
  /// while a genuinely recreated view (a theme-change teardown) still receives
  /// the current values through [creationParams].
  final Set<String> creationOnlyParamKeys;

  final LiquidMethodCallHandler? onMethodCall;
  final ValueChanged<MethodChannel>? onChannelReady;

  /// Painted in place of the offstage native view while this route is covered
  /// by another route, and kept over it for a beat after the return re-stages
  /// it. Defaults to an empty box, which simply hides the native view during
  /// the transition. Provide a Flutter stand-in here if a blank gap looks too
  /// abrupt.
  final WidgetBuilder? placeholderBuilder;

  @override
  State<LiquidPlatformView> createState() => _LiquidPlatformViewState();
}

class _LiquidPlatformViewState extends State<LiquidPlatformView> {
  static const DeepCollectionEquality _deepEquals = DeepCollectionEquality();
  MethodChannel? _channel;

  /// Whether this view's route is currently being covered by another route.
  ///
  /// While covered the native view stays MOUNTED but offstage. Unmounting a
  /// `UiKitView` disposes the native view over an async channel, which can
  /// leave it lingering on screen for a moment after navigating; recreating
  /// one on return forces the engine to rebuild its platform-view layer
  /// split, which flashes Flutter content composited around other platform
  /// views, at the pop's first frame or its last, whichever the timing picks.
  /// Offstage merely drops the live view from the frame: the engine removes
  /// and re-adds it in step with painting, the same churn-free path as a view
  /// scrolling out of sight, and the placeholder twin carries the look
  /// meanwhile.
  bool _covered = false;

  /// True from an uncover until the re-staged native view is back in the
  /// frame. The placeholder stays painted over it for that beat, so the
  /// engine re-adding the view to the scene never flashes through.
  bool _settling = false;

  /// Bumped on every cover flip so a stale settle future cannot drop the
  /// placeholder of a later cycle.
  int _coverCycle = 0;

  /// The hosting route's [ModalRoute.secondaryAnimation], which runs whenever
  /// another route is pushed on top of this one (in the same navigator). It is
  /// the most reliable cover signal — unlike a [RouteObserver] it needs no
  /// registration and works inside nested navigators.
  Animation<double>? _secondaryAnimation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final secondary = ModalRoute.of(context)?.secondaryAnimation;
    if (secondary != _secondaryAnimation) {
      _secondaryAnimation?.removeStatusListener(_onSecondaryStatusChanged);
      _secondaryAnimation = secondary;
      _secondaryAnimation?.addStatusListener(_onSecondaryStatusChanged);
      _covered = _isCovered(secondary?.status);
    }
  }

  /// Covered from the moment another route starts animating in until it is
  /// fully gone (`dismissed`), the return transition included: staging a
  /// platform view reallocates the overlay textures the engine composites
  /// Flutter content into, and doing that while the covering route is still
  /// visible blinks ITS content (composited around its own platform views).
  /// Held to the settle, the re-stage lands in the same frame the covering
  /// route's views leave, and the placeholder rides over its first frames.
  bool _isCovered(AnimationStatus? status) => status != null && status != AnimationStatus.dismissed;

  void _onSecondaryStatusChanged(AnimationStatus status) {
    final covered = _isCovered(status);
    if (covered != _covered && mounted) {
      _coverCycle++;
      setState(() {
        _covered = covered;
        _settling = !covered && widget.placeholderBuilder != null;
      });
      if (_settling) unawaited(_dropPlaceholderWhenSettled());
    }
  }

  /// The messenger retains the handler until it is cleared; the view (and its
  /// channel) lives across covers, so only dispose releases it.
  void _releaseChannel() {
    _channel?.setMethodCallHandler(null);
    _channel = null;
  }

  @override
  void dispose() {
    _secondaryAnimation?.removeStatusListener(_onSecondaryStatusChanged);
    _releaseChannel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return const SizedBox.shrink();
    }

    final view = UiKitView(
      viewType: widget.viewType,
      creationParams: widget.creationParams,
      creationParamsCodec: const StandardMessageCodec(),
      hitTestBehavior: widget.hitTestBehavior,
      onPlatformViewCreated: _onPlatformViewCreated,
      gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{
        Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
      },
    );

    if (!_covered && !_settling) return view;
    // Riding above the live view, the placeholder must not eat the touches
    // the native view is about to own back.
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Offstage(offstage: _covered, child: view),
        IgnorePointer(child: widget.placeholderBuilder?.call(context) ?? const SizedBox.shrink()),
      ],
    );
  }

  void _onPlatformViewCreated(int id) {
    final channel = MethodChannel('liquid/${widget.viewType}_$id');
    _channel = channel;
    widget.onChannelReady?.call(channel);
    channel.setMethodCallHandler(widget.onMethodCall);
  }

  /// Two frames past the uncover: one for the engine to re-add the native
  /// view to the scene, one for its layout to land.
  Future<void> _dropPlaceholderWhenSettled() async {
    final cycle = _coverCycle;
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || cycle != _coverCycle || !_settling) return;
    setState(() => _settling = false);
  }

  @override
  void didUpdateWidget(covariant LiquidPlatformView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_deepEquals.equals(
      _updatableParams(widget.creationParams),
      _updatableParams(oldWidget.creationParams),
    )) {
      _pushUpdate(widget.creationParams);
    }
  }

  Map<String, dynamic> _updatableParams(Map<String, dynamic> params) {
    if (widget.creationOnlyParamKeys.isEmpty) return params;
    return {
      for (final MapEntry(:key, :value) in params.entries)
        if (!widget.creationOnlyParamKeys.contains(key)) key: value,
    };
  }

  /// Pushes changed [creationParams] to the native view.
  ///
  /// On a theme change the whole app subtree rebuilds and iOS platform views
  /// may be torn down and recreated. The native host can be released just as
  /// this fire-and-forget `update` is dispatched, in which case it replies with
  /// a `missing_host` [PlatformException]. That update is harmless to lose — the
  /// replacement view is created with the new [creationParams] — so swallow it
  /// rather than letting the unhandled rejection surface as a crash. Genuine
  /// errors (other codes) are still rethrown.
  Future<void> _pushUpdate(Map<String, dynamic> params) async {
    try {
      await _channel?.invokeMethod('update', params);
    } on PlatformException catch (error) {
      if (error.code != 'missing_host') rethrow;
    } on MissingPluginException {
      // The channel was torn down before the update landed — also harmless.
    }
  }
}
