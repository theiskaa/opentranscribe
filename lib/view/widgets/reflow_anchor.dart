import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/view/widgets/app_top_bar.dart';
import 'package:opentranscribe/view/widgets/pane_frame.dart';

typedef ReflowLine = ({int start, int end, double top, double height});
typedef ReadingAnchor = ({int character, double fraction});

({ReadingAnchor? pending, ReadingAnchor? restore}) reflowAnchorFor({
  required bool supported,
  required bool settled,
  required ReadingAnchor? pending,
}) {
  if (!supported) return (pending: null, restore: null);
  if (!settled) return (pending: pending, restore: null);
  return (pending: null, restore: pending);
}

ReadingAnchor? anchorAt(List<ReflowLine> lines, double top) {
  if (lines.isEmpty || top < lines.first.top || top >= lines.last.top + lines.last.height) {
    return null;
  }
  final line = lines.firstWhere((line) => top < line.top + line.height);
  return (character: line.start, fraction: ((top - line.top) / line.height).clamp(0, 1));
}

double? offsetFor(List<ReflowLine> lines, ReadingAnchor anchor) {
  if (lines.isEmpty) return null;
  final line = lines.firstWhere(
    (line) =>
        anchor.character < line.end || (line.start == line.end && anchor.character == line.start),
    orElse: () => lines.last,
  );
  return line.top + line.height * anchor.fraction.clamp(0, 1);
}

class ReflowAnchor extends StatelessWidget {
  const ReflowAnchor({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => _AnchorRenderWidget(
    position: Scrollable.maybeOf(context)?.position,
    enabled: PaneLayoutScope.maybeOf(context)?.supported == true,
    settled: PaneLayoutScope.maybeOf(context)?.settled == true,
    readingInset: AppTopBar.heightOf(context) + context.theme.topBar.fadeTail,
    child: child,
  );
}

class _AnchorRenderWidget extends SingleChildRenderObjectWidget {
  const _AnchorRenderWidget({
    required this.position,
    required this.enabled,
    required this.settled,
    required this.readingInset,
    required super.child,
  });

  final ScrollPosition? position;
  final bool enabled;
  final bool settled;
  final double readingInset;

  @override
  _RenderAnchor createRenderObject(BuildContext context) => _RenderAnchor()
    ..position = position
    ..enabled = enabled
    ..settled = settled
    ..readingInset = readingInset;

  @override
  void updateRenderObject(BuildContext context, _RenderAnchor renderObject) {
    renderObject
      ..position = position
      ..enabled = enabled
      ..settled = settled
      ..readingInset = readingInset;
  }
}

class _RenderAnchor extends RenderProxyBox {
  ScrollPosition? position;
  bool enabled = false;
  bool _settled = false;

  set settled(bool value) {
    if (_settled == value) return;
    _settled = value;
    markNeedsLayout();
  }

  double readingInset = 0;
  double? _width;
  double? _laidOutInset;
  ReadingAnchor? _pending;
  bool _scheduled = false;

  RenderParagraph? _paragraph(RenderObject root) {
    if (root is RenderParagraph) return root;
    RenderParagraph? found;
    root.visitChildren((child) => found ??= _paragraph(child));
    return found;
  }

  List<ReflowLine> _lines(RenderParagraph paragraph) {
    final painter = TextPainter(
      text: paragraph.text,
      textDirection: paragraph.textDirection,
      textScaler: paragraph.textScaler,
      locale: paragraph.locale,
      strutStyle: paragraph.strutStyle,
      textHeightBehavior: paragraph.textHeightBehavior,
      textWidthBasis: paragraph.textWidthBasis,
    )..layout(minWidth: paragraph.size.width, maxWidth: paragraph.size.width);
    final lines = <ReflowLine>[];
    for (final line in painter.computeLineMetrics()) {
      final top = line.baseline - line.ascent;
      final range = painter.getLineBoundary(
        painter.getPositionForOffset(Offset(line.left, top + line.height / 2)),
      );
      lines.add((start: range.start, end: range.end, top: top, height: line.height));
    }
    painter.dispose();
    return lines;
  }

  double _paragraphTop(RenderParagraph paragraph) =>
      RenderAbstractViewport.of(paragraph).getOffsetToReveal(paragraph, 0).offset;

  @override
  void performLayout() {
    final scroll = position;
    final before = child == null ? null : _paragraph(child!);
    final changed = _width != null && _width != constraints.maxWidth;
    if (enabled && changed && scroll != null && before?.hasSize == true && _pending == null) {
      _pending = anchorAt(
        _lines(before!),
        scroll.pixels + (_laidOutInset ?? readingInset) - _paragraphTop(before),
      );
    }
    super.performLayout();
    _width = constraints.maxWidth;
    _laidOutInset = readingInset;
    if (_pending == null || _scheduled) return;
    _scheduled = true;
    // The paragraph's new position is final only once its ancestors finish layout.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!attached || scroll == null || position != scroll) {
        _pending = null;
        return;
      }
      final decision = reflowAnchorFor(supported: enabled, settled: _settled, pending: _pending);
      _pending = decision.pending;
      final anchor = decision.restore;
      if (anchor == null) return;
      final paragraph = child == null ? null : _paragraph(child!);
      if (paragraph == null || !scroll.hasContentDimensions) return;
      final offset = offsetFor(_lines(paragraph), anchor);
      if (offset == null) return;
      scroll.jumpTo(
        (_paragraphTop(paragraph) + offset - readingInset).clamp(
          scroll.minScrollExtent,
          scroll.maxScrollExtent,
        ),
      );
    });
  }
}
