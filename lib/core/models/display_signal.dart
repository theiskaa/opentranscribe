import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// A UIKit size class.
enum SizeClass { compact, regular, unspecified }

/// The physical side the vertical status bar stands on, already resolved from
/// UIKit's layout direction: content mirrors, the bar does not.
enum BarSide { left, right, none }

/// What a reserved region is: [division] is the fold, [occlusion] hardware or
/// system chrome drawn over the display.
enum RegionKind { division, occlusion }

/// A part of the window the display reserves, in the Flutter view's points.
/// The [rect] already includes Apple's margins.
@immutable
final class ReservedRegion {
  const ReservedRegion({required this.kind, required this.rect, required this.active});

  final RegionKind kind;
  final Rect rect;

  /// Whether it reserves anything in this pose. A division is active only
  /// while the device is partly folded; the inactive one marks where it would be.
  final bool active;

  /// Null when [wire] is malformed; a record holding null when it is well
  /// formed but of a kind this build does not know.
  static ({ReservedRegion? region})? _fromWire(Object? wire) {
    if (wire is! Map) return null;
    final kind = wire['kind'];
    final active = wire['active'];
    final x = _coordinate(wire['x']);
    final y = _coordinate(wire['y']);
    final width = _length(wire['width']);
    final height = _length(wire['height']);
    if (kind is! String ||
        active is! bool ||
        x == null ||
        y == null ||
        width == null ||
        height == null) {
      return null;
    }
    final known = switch (kind) {
      'division' => RegionKind.division,
      'occlusion' => RegionKind.occlusion,
      _ => null,
    };
    return (
      region: known == null
          ? null
          : ReservedRegion(kind: known, rect: Rect.fromLTWH(x, y, width, height), active: active),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ReservedRegion && other.kind == kind && other.rect == rect && other.active == active;

  @override
  int get hashCode => Object.hash(kind, rect, active);

  @override
  String toString() => 'ReservedRegion(kind: ${kind.name}, rect: $rect, active: $active)';
}

/// What the display reserves around the window, as the native monitor last
/// settled it. Below iOS 27.1 it is not [supported]; when anything about the
/// answer is in doubt it is [unsupported]. Either way the layout is today's
/// single column.
@immutable
final class DisplaySignal {
  const DisplaySignal({
    required this.supported,
    this.size = Size.zero,
    this.horizontal = SizeClass.unspecified,
    this.padding = EdgeInsets.zero,
    this.fullScreen = false,
    this.barSide = BarSide.none,
    this.regions = const [],
    this.reduceTransparency = false,
  });

  static const unsupported = DisplaySignal(supported: false);

  /// Whether the OS reports regions and the bar edge at all (iOS 27.1 and later).
  final bool supported;

  final Size size;
  final SizeClass horizontal;

  /// UIKit's safe area insets for the view.
  final EdgeInsets padding;

  /// Whether the window fills its screen: false in Split View and Slide Over.
  final bool fullScreen;

  final BarSide barSide;

  /// Every division and occlusion, inactive ones included.
  final List<ReservedRegion> regions;

  /// dart:ui carries no flag for it, so the monitor reports it.
  final bool reduceTransparency;

  /// The active division, the fold that is reserving space now, or null.
  ReservedRegion? get activeDivision {
    for (final region in regions) {
      if (region.kind == RegionKind.division && region.active) return region;
    }
    return null;
  }

  /// The division active or not: where the fold sits whether or not it is bent.
  ReservedRegion? get division {
    for (final region in regions) {
      if (region.kind == RegionKind.division) return region;
    }
    return null;
  }

  /// Decodes the monitor's payload. Returns null for anything malformed, so a
  /// half-read answer is never mistaken for a layout; a kind or class this
  /// build does not know reads as absent rather than as malformed.
  static DisplaySignal? fromWire(Object? wire) {
    if (wire is! Map) return null;
    final supported = wire['supported'];
    if (supported is! bool) return null;
    final width = wire['width'] == null && !supported ? 0.0 : _length(wire['width']);
    final height = wire['height'] == null && !supported ? 0.0 : _length(wire['height']);
    final padding = _insets(wire['insets'], required: supported);
    final horizontal = _sizeClass(wire['horizontal']);
    final fullScreen = wire['fullScreen'] ?? false;
    final reduceTransparency = wire['reduceTransparency'] ?? false;
    if (width == null ||
        height == null ||
        padding == null ||
        horizontal == null ||
        fullScreen is! bool ||
        reduceTransparency is! bool) {
      return null;
    }
    if (!supported) {
      return DisplaySignal(
        supported: false,
        size: Size(width, height),
        horizontal: horizontal,
        padding: padding,
        fullScreen: fullScreen,
        reduceTransparency: reduceTransparency,
      );
    }
    final barSide = wire['barSide'];
    final regions = _regions(wire['regions']);
    if (barSide is! String? || regions == null) return null;
    return DisplaySignal(
      supported: true,
      size: Size(width, height),
      horizontal: horizontal,
      padding: padding,
      fullScreen: fullScreen,
      barSide: switch (barSide) {
        'left' => BarSide.left,
        'right' => BarSide.right,
        _ => BarSide.none,
      },
      regions: List.unmodifiable(regions),
      reduceTransparency: reduceTransparency,
    );
  }

  static SizeClass? _sizeClass(Object? value) => switch (value) {
    null || 'unspecified' => SizeClass.unspecified,
    'compact' => SizeClass.compact,
    'regular' => SizeClass.regular,
    String() => SizeClass.unspecified,
    _ => null,
  };

  static EdgeInsets? _insets(Object? value, {required bool required}) {
    if (value == null) return required ? null : EdgeInsets.zero;
    if (value is! Map) return null;
    final top = _length(value['top']);
    final left = _length(value['left']);
    final bottom = _length(value['bottom']);
    final right = _length(value['right']);
    if (top == null || left == null || bottom == null || right == null) return null;
    return EdgeInsets.fromLTRB(left, top, right, bottom);
  }

  static List<ReservedRegion>? _regions(Object? value) {
    if (value == null) return const [];
    if (value is! List) return null;
    final regions = <ReservedRegion>[];
    for (final item in value) {
      final decoded = ReservedRegion._fromWire(item);
      if (decoded == null) return null;
      if (decoded.region case final region?) regions.add(region);
    }
    return regions;
  }

  @override
  bool operator ==(Object other) =>
      other is DisplaySignal &&
      other.supported == supported &&
      other.size == size &&
      other.horizontal == horizontal &&
      other.padding == padding &&
      other.fullScreen == fullScreen &&
      other.barSide == barSide &&
      listEquals(other.regions, regions) &&
      other.reduceTransparency == reduceTransparency;

  @override
  int get hashCode => Object.hash(
    supported,
    size,
    horizontal,
    padding,
    fullScreen,
    barSide,
    Object.hashAll(regions),
    reduceTransparency,
  );

  @override
  String toString() =>
      'DisplaySignal(supported: $supported, size: $size, horizontal: ${horizontal.name}, '
      'padding: $padding, fullScreen: $fullScreen, barSide: ${barSide.name}, '
      'regions: $regions, reduceTransparency: $reduceTransparency)';
}

/// A finite, non-negative length; null when [value] is anything else.
double? _length(Object? value) {
  if (value is! num) return null;
  final length = value.toDouble();
  return length.isFinite && length >= 0 ? length : null;
}

double? _coordinate(Object? value) {
  if (value is! num) return null;
  final coordinate = value.toDouble();
  return coordinate.isFinite ? coordinate : null;
}
