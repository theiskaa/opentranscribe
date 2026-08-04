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
  /// while a recreated view (after being covered) still receives the current
  /// values through [creationParams].
  final Set<String> creationOnlyParamKeys;

  final LiquidMethodCallHandler? onMethodCall;
  final ValueChanged<MethodChannel>? onChannelReady;

  /// Built in place of the native view while this route is being covered by
  /// another route. Defaults to an empty box, which simply hides the native
  /// view during the transition. Provide a Flutter stand-in here if a blank gap
  /// looks too abrupt.
  final WidgetBuilder? placeholderBuilder;

  @override
  State<LiquidPlatformView> createState() => _LiquidPlatformViewState();
}

class _LiquidPlatformViewState extends State<LiquidPlatformView> {
  static const DeepCollectionEquality _deepEquals = DeepCollectionEquality();
  MethodChannel? _channel;

  /// Whether this view's route is currently being covered by another route.
  ///
  /// iOS platform views (`UiKitView`) are composited above the Flutter layer and
  /// are not reliably torn down while they sit behind a route pushed on top.
  /// This leaves visual "ghosts" (e.g. a lingering button shadow) on screen for
  /// a moment after navigating. While covered we drop the native view from the
  /// tree so nothing can linger, then bring it back on return.
  bool _covered = false;

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
  /// fully gone (`dismissed`), the return transition included: re-creating
  /// every dropped native view at the first frame of a pop forces the engine
  /// to rebuild its platform-view layer split mid-transition, which drops
  /// frames of Flutter content composited above other platform views. The
  /// placeholder carries the look until the route settles.
  bool _isCovered(AnimationStatus? status) => status != null && status != AnimationStatus.dismissed;

  void _onSecondaryStatusChanged(AnimationStatus status) {
    final covered = _isCovered(status);
    if (covered != _covered && mounted) {
      if (covered) _releaseChannel();
      setState(() => _covered = covered);
    }
  }

  /// The messenger retains a handler until it is cleared, and every recreation
  /// after a cover mints a new channel, so a stale registration would leak per
  /// navigation.
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

    if (_covered) {
      return widget.placeholderBuilder?.call(context) ?? const SizedBox.shrink();
    }

    return UiKitView(
      viewType: widget.viewType,
      creationParams: widget.creationParams,
      creationParamsCodec: const StandardMessageCodec(),
      hitTestBehavior: widget.hitTestBehavior,
      onPlatformViewCreated: _onPlatformViewCreated,
      gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{
        Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
      },
    );
  }

  void _onPlatformViewCreated(int id) {
    final channel = MethodChannel('liquid/${widget.viewType}_$id');
    _channel = channel;
    widget.onChannelReady?.call(channel);
    channel.setMethodCallHandler(widget.onMethodCall);
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
