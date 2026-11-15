import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/core/models/display_signal.dart';
import 'package:opentranscribe/core/utils/display_regions.dart';

import 'display_fixtures.dart';

/// Payloads as DisplayRegions.swift sends them, measured on the iPhone Duo
/// simulator, iOS 27.2.
abstract final class DisplayWire {
  static Map<String, Object?> region(
    String kind,
    double x,
    double y,
    double width,
    double height, {
    bool active = true,
  }) => {'kind': kind, 'active': active, 'x': x, 'y': y, 'width': width, 'height': height};

  static Map<String, Object?> insets(double top, double left, double bottom, double right) => {
    'top': top,
    'left': left,
    'bottom': bottom,
    'right': right,
  };

  static Map<String, Object?> insetsOf(EdgeInsets padding) =>
      insets(padding.top, padding.left, padding.bottom, padding.right);

  static Map<String, Object?> signal({
    required double width,
    required double height,
    required String horizontal,
    required Map<String, Object?> insets,
    bool fullScreen = true,
    String barSide = 'none',
    List<Map<String, Object?>> regions = const [],
    bool supported = true,
    bool reduceTransparency = false,
  }) => {
    'supported': supported,
    'width': width,
    'height': height,
    'horizontal': horizontal,
    'insets': insets,
    'fullScreen': fullScreen,
    'barSide': barSide,
    'regions': regions,
    'reduceTransparency': reduceTransparency,
  };

  static final cover = signal(
    width: coverSize.width,
    height: coverSize.height,
    horizontal: 'compact',
    insets: insetsOf(coverPadding),
    barSide: 'right',
    regions: [
      region('occlusion', 400, 29, 37, 37),
      region('occlusion', coverSize.width - coverPadding.right, 0, coverPadding.right, 174),
    ],
  );

  static Map<String, Object?> _wide({required bool folded}) => signal(
    width: wideSize.width,
    height: wideSize.height,
    horizontal: 'regular',
    insets: insetsOf(widePadding),
    barSide: 'right',
    regions: [
      region('division', foldStart, 0, foldDepth, wideSize.height, active: folded),
      region('occlusion', wideSize.width - widePadding.right, 0, widePadding.right, 124),
      region('occlusion', 677, 21, 58, 37, active: false),
    ],
  );

  static final bookWide = _wide(folded: true);
  static final flatWide = _wide(folded: false);

  static Map<String, Object?> _tall({required bool folded}) => signal(
    width: tallSize.width,
    height: tallSize.height,
    horizontal: 'regular',
    insets: insetsOf(tallPadding),
    regions: [
      region('division', 0, foldStart, tallSize.width, foldDepth, active: folded),
      region('occlusion', 525, 0, 144, tallPadding.top),
      region('occlusion', 611, 677, 37, 58, active: false),
    ],
  );

  static final flatTall = _tall(folded: false);

  /// The tall pose with its division bent active.
  static final laptop = _tall(folded: true);

  static final iphone = signal(
    width: iphoneSize.width,
    height: iphoneSize.height,
    horizontal: 'compact',
    insets: insetsOf(iphonePadding),
  );

  /// What Swift's plain reading sends below iOS 27.1.
  static final unsupported = signal(
    supported: false,
    width: iphoneSize.width,
    height: iphoneSize.height,
    horizontal: 'compact',
    insets: insetsOf(iphonePadding),
  );

  /// A Split View window on the open device: compact, not filling its
  /// screen, holding [division], the part of the fold inside it.
  static Map<String, Object?> splitHalf({
    required double width,
    required double height,
    required Map<String, Object?> insets,
    required Map<String, Object?> division,
    String barSide = 'none',
  }) => signal(
    width: width,
    height: height,
    horizontal: 'compact',
    insets: insets,
    fullScreen: false,
    barSide: barSide,
    regions: [division],
  );

  static DisplaySignal decode(Map<String, Object?> wire) => DisplaySignal.fromWire(wire)!;
}

/// The two display channels under unique names, answered by the test
/// binding's messenger so nothing reaches a platform.
class FakeDisplayChannels {
  FakeDisplayChannels({this.current, this.pushes = const [], this.broken = false}) {
    _messenger.setMockMethodCallHandler(methods, (call) async {
      probes++;
      if (broken) throw PlatformException(code: _gone);
      return current;
    });
    _messenger.setMockStreamHandler(
      events,
      MockStreamHandler.inline(
        onListen: (arguments, sink) {
          listens++;
          _sink = sink;
          if (broken) return sink.error(code: _gone);
          pushes.forEach(sink.success);
        },
      ),
    );
  }

  static const _gone = 'gone';
  static int _count = 0;

  static TestDefaultBinaryMessenger get _messenger =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  final int _id = _count++;
  late final methods = MethodChannel('test/display/$_id');
  late final events = EventChannel('test/display/$_id/events');

  /// What the `current` probe answers, what the stream pushes on listen, and
  /// whether both fail instead; read on each probe and listen.
  Object? current;
  List<Object?> pushes;
  bool broken;

  int probes = 0;
  int listens = 0;
  MockStreamHandlerEventSink? _sink;

  DisplayRegionsMonitor monitor() => DisplayRegionsMonitor(methods: methods, events: events);

  void push(Object? wire) => _sink!.success(wire);

  void fail() => _sink!.error(code: _gone);

  void dispose() {
    _messenger.setMockMethodCallHandler(methods, null);
    _messenger.setMockStreamHandler(events, null);
  }
}
