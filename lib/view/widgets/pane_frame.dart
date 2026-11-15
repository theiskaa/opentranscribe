import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:opentranscribe/core/models/pane_layout.dart';
import 'package:opentranscribe/core/routes/pane_stack.dart';
import 'package:opentranscribe/core/routes/routes.dart';

class PaneTouchTracker extends ChangeNotifier {
  late PaneLayout layout;
  late MediaQueryData media;
  List<LocalKey> detailKeys = const [];
  Uri? selection;
  final readingSelection = ValueNotifier<PaneSelection?>(null);
  bool covered = false;
  bool supported = false;
  bool settled = false;
  bool cover = false;
  PaneStack _stack = const PaneStack();
  bool _initialized = false;

  bool update({
    required PaneLayout layout,
    required MediaQueryData media,
    required bool settled,
    required bool supported,
    required bool cover,
    required RouteMatchList matches,
    required bool selectionOnTop,
  }) {
    final oldLayout = supported == this.supported && cover == this.cover && _initialized
        ? this.layout
        : null;
    final oldMedia = _initialized ? this.media : null;
    final oldKeys = detailKeys;
    final oldSelection = selection;
    final oldCovered = covered;
    final oldSettled = this.settled;
    final details = matches.matches.where(
      (match) =>
          match.route is GoRoute && Routes.detailNames.contains((match.route as GoRoute).name),
    );
    detailKeys = details.map((match) => match.pageKey).toList();
    final root = details.firstOrNull;
    selection = root == null
        ? null
        : root is ImperativeRouteMatch
        ? root.matches.uri
        : matches.uri;
    if (oldSelection != selection) readingSelection.value = null;
    covered = matches.matches.any(
      (match) =>
          match.route is GoRoute &&
          {Routes.recordName, Routes.onboardingName}.contains((match.route as GoRoute).name),
    );
    _stack = _stack.select(root == null ? null : (root.pageKey, selection.toString()));
    final result = _stack.layout(
      mode: layout.mode,
      settled: settled,
      detailDepth: detailKeys.length,
      covered: covered,
      selectionOnTop: selectionOnTop,
    );
    _stack = result.stack;
    this.supported = supported;
    this.settled = settled;
    this.cover = cover;
    this.layout = layout;
    this.media = media;
    _initialized = true;
    if (oldLayout != layout ||
        oldMedia != media ||
        !listEquals(oldKeys, detailKeys) ||
        oldSelection != selection ||
        oldCovered != covered ||
        oldSettled != settled) {
      notifyListeners();
    }
    return result.popSelection;
  }

  void consumeCollapse() => _stack = _stack.consumeCollapse();

  void touch(PaneTouch pane) => _stack = _stack.touch(pane);

  @override
  void dispose() {
    readingSelection.dispose();
    super.dispose();
  }
}

class PaneLayoutScope extends InheritedWidget {
  PaneLayoutScope({required this.tracker, required super.child, super.key})
    : layout = tracker.layout,
      media = tracker.media,
      supported = tracker.supported,
      settled = tracker.settled,
      cover = tracker.cover,
      detailKeys = List.unmodifiable(tracker.detailKeys);

  final PaneTouchTracker tracker;
  final PaneLayout layout;
  final MediaQueryData media;
  final bool supported;
  final bool settled;
  final bool cover;
  final List<LocalKey> detailKeys;

  static PaneTouchTracker of(BuildContext context) => maybeOf(context)!;

  static PaneTouchTracker? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PaneLayoutScope>()?.tracker;

  @override
  bool updateShouldNotify(PaneLayoutScope oldWidget) =>
      layout != oldWidget.layout ||
      media != oldWidget.media ||
      supported != oldWidget.supported ||
      settled != oldWidget.settled ||
      cover != oldWidget.cover ||
      !listEquals(detailKeys, oldWidget.detailKeys);
}

typedef PaneSelection = ({String path, String? period, String? week});

PaneSelection? paneSelection(Uri? uri) => uri == null
    ? null
    : (path: uri.path, period: uri.queryParameters['period'], week: uri.queryParameters['week']);

class PaneSelectionScope extends InheritedModel<PaneSelection> {
  const PaneSelectionScope({required this.selection, required super.child, super.key});

  final PaneSelection? selection;

  static bool isSelected(BuildContext context, Uri uri) {
    final aspect = paneSelection(uri)!;
    return InheritedModel.inheritFrom<PaneSelectionScope>(context, aspect: aspect)?.selection ==
        aspect;
  }

  @override
  bool updateShouldNotify(PaneSelectionScope oldWidget) => selection != oldWidget.selection;

  @override
  bool updateShouldNotifyDependent(PaneSelectionScope oldWidget, Set<PaneSelection> dependencies) =>
      dependencies.any((key) => (selection == key) != (oldWidget.selection == key));
}

class PaneScope extends InheritedWidget {
  const PaneScope({required this.pane, required this.detailRoot, required super.child, super.key});

  final Pane pane;
  final bool detailRoot;

  static PaneScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PaneScope>();

  @override
  bool updateShouldNotify(PaneScope oldWidget) =>
      pane != oldWidget.pane || detailRoot != oldWidget.detailRoot;
}

EdgeInsets paneInsets(EdgeInsets insets, Rect pane, Size window) => EdgeInsets.fromLTRB(
  math.max(0, insets.left - pane.left),
  math.max(0, insets.top - pane.top),
  math.max(0, insets.right - (window.width - pane.right)),
  math.max(0, insets.bottom - (window.height - pane.bottom)),
);

MediaQueryData paneMediaData(MediaQueryData media, Pane pane) => media.copyWith(
  size: pane.rect.size,
  padding: pane.padding,
  viewPadding: paneInsets(media.viewPadding, pane.rect, media.size),
  viewInsets: paneInsets(media.viewInsets, pane.rect, media.size),
  displayFeatures: const [],
);

class PaneFrame extends StatelessWidget {
  const PaneFrame({
    required this.pane,
    required this.child,
    this.touch,
    this.detailRoot = false,
    super.key,
  });

  final Pane pane;
  final Widget child;
  final PaneTouch? touch;
  final bool detailRoot;

  @override
  Widget build(BuildContext context) {
    final tracker = PaneLayoutScope.of(context);
    return Positioned.fromRect(
      rect: pane.rect,
      child: ClipRect(
        child: MediaQuery(
          data: paneMediaData(tracker.media, pane),
          child: PaneScope(
            pane: pane,
            detailRoot: detailRoot,
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: touch == null ? null : (_) => tracker.touch(touch!),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

Rect modalRectOf(BuildContext context) =>
    PaneLayoutScope.maybeOf(context)?.layout.modal ?? Offset.zero & MediaQuery.sizeOf(context);

class ModalFrame extends StatelessWidget {
  const ModalFrame({required this.child, this.capWidth, super.key});

  final Widget child;
  final double? capWidth;

  @override
  Widget build(BuildContext context) {
    final tracker = PaneLayoutScope.maybeOf(context);
    final media = tracker?.media ?? MediaQuery.of(context);
    final rect = modalFrameRect(
      tracker?.cover == true
          ? Offset.zero & media.size
          : tracker?.layout.modal ?? Offset.zero & media.size,
      capWidth: modalWidthCap(tracker?.layout, capWidth),
    );
    return Stack(
      children: [
        Positioned.fromRect(
          rect: rect,
          child: MediaQuery(
            data: paneMediaData(
              media,
              Pane(rect: rect, padding: paneInsets(media.padding, rect, media.size)),
            ),
            child: child,
          ),
        ),
      ],
    );
  }
}

double? modalWidthCap(PaneLayout? layout, double? capWidth) =>
    layout?.mode == PaneMode.split ? capWidth : null;

Rect modalFrameRect(Rect modal, {double? capWidth}) => capWidth != null && modal.width > capWidth
    ? Rect.fromCenter(center: modal.center, width: capWidth, height: modal.height)
    : modal;
