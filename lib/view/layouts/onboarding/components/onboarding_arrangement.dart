import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/models/pane_layout.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';

typedef OnboardingRegions = ({Rect safe, Rect pages, Rect controls, Rect words, Rect scene});

OnboardingRegions onboardingRegions(PaneLayout layout, double controlsHeight) {
  final leading = layout.leading;
  final detail = layout.detail;
  final safe = Rect.fromLTRB(
    leading.rect.left + leading.padding.left,
    leading.rect.top + leading.padding.top,
    detail.rect.right - detail.padding.right,
    detail.rect.bottom - detail.padding.bottom,
  );
  final split = layout.mode == PaneMode.split;
  final controls = Rect.fromLTRB(
    safe.left,
    math.max(safe.top, safe.bottom - controlsHeight),
    split ? leading.rect.right - leading.padding.right : safe.right,
    safe.bottom,
  );
  final laptop = layout.fold?.axis == FoldAxis.horizontal;
  final pages = Rect.fromLTRB(
    safe.left,
    safe.top,
    safe.right,
    laptop ? math.min(controls.top, layout.fold!.rect.top) : controls.top,
  );
  return (
    safe: safe,
    pages: pages,
    controls: controls,
    words: split ? Rect.fromLTRB(safe.left, pages.top, controls.right, pages.bottom) : pages,
    scene: split
        ? Rect.fromLTRB(detail.rect.left + detail.padding.left, pages.top, safe.right, pages.bottom)
        : pages,
  );
}

class OnboardingColumns extends InheritedWidget {
  const OnboardingColumns({required this.layout, required super.child, super.key});

  final PaneLayout? layout;

  static PaneLayout? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OnboardingColumns>()?.layout;

  @override
  bool updateShouldNotify(OnboardingColumns oldWidget) => layout != oldWidget.layout;
}

class OnboardingFrameLayout extends MultiChildLayoutDelegate {
  OnboardingFrameLayout({required this.layout});

  final PaneLayout? layout;

  @override
  void performLayout(Size size) {
    final panes = layout;
    final regions = panes == null ? null : onboardingRegions(panes, 0);
    final width = regions?.controls.width ?? size.width;
    final controls = layoutChild('controls', BoxConstraints(maxWidth: width));
    final placed = panes == null ? null : onboardingRegions(panes, controls.height);
    final origin = placed?.safe.topLeft ?? Offset.zero;
    final pages =
        placed?.pages.shift(-origin) ??
        Rect.fromLTWH(0, 0, size.width, math.max(0, size.height - controls.height));
    layoutChild('pages', BoxConstraints.tight(pages.size));
    positionChild('pages', pages.topLeft);
    positionChild(
      'controls',
      placed == null ? Offset(0, pages.bottom) : placed.controls.topLeft - origin,
    );
  }

  @override
  bool shouldRelayout(OnboardingFrameLayout oldDelegate) => layout != oldDelegate.layout;
}

class OnboardingContent extends MultiChildRenderObjectWidget {
  OnboardingContent({
    required Widget words,
    required Widget scene,
    required this.layout,
    required this.viewportHeight,
    super.key,
  }) : super(children: [words, scene]);

  final PaneLayout? layout;
  final double viewportHeight;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderContent(layout, viewportHeight);

  @override
  void updateRenderObject(BuildContext context, covariant RenderBox renderObject) {
    (renderObject as _RenderContent)
      ..paneLayout = layout
      ..viewportHeight = viewportHeight;
  }
}

class _ContentData extends ContainerBoxParentData<RenderBox> {}

class _RenderContent extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ContentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _ContentData> {
  _RenderContent(this._layout, this._viewportHeight);

  PaneLayout? _layout;
  double _viewportHeight;

  set viewportHeight(double value) {
    if (_viewportHeight == value) return;
    _viewportHeight = value;
    markNeedsLayout();
  }

  set paneLayout(PaneLayout? value) {
    if (_layout == value) return;
    _layout = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ContentData) child.parentData = _ContentData();
  }

  @override
  void performLayout() {
    final words = firstChild!;
    final scene = lastChild!;
    final panes = _layout;
    final wide = panes?.mode == PaneMode.split;
    final regions = panes == null ? null : onboardingRegions(panes, 0);
    final wordsWidth = wide ? regions!.words.width - AppSpacing.xxl * 2 : constraints.maxWidth;
    final sceneWidth = wide ? regions!.scene.width - AppSpacing.xxl * 2 : constraints.maxWidth;
    // Wide halves scroll independently; unbounded single-column halves let the outer scroll own it.
    words.layout(
      BoxConstraints.tightFor(
        width: math.max(0, wordsWidth),
        height: wide ? _viewportHeight : null,
      ),
      parentUsesSize: true,
    );
    scene.layout(
      BoxConstraints.tightFor(
        width: math.max(0, sceneWidth),
        height: wide ? _viewportHeight : null,
      ),
      parentUsesSize: true,
    );
    final offset = wide
        ? Offset(regions!.scene.left - regions.safe.left, 0)
        : Offset(0, words.size.height + AppSpacing.xxxl);
    (scene.parentData! as _ContentData).offset = offset;
    size = constraints.constrain(
      Size(constraints.maxWidth, math.max(words.size.height, offset.dy + scene.size.height)),
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
