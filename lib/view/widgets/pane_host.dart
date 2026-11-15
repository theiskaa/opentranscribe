import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:opentranscribe/core/models/pane_layout.dart';
import 'package:opentranscribe/core/routes/pane_page.dart';
import 'package:opentranscribe/core/routes/pane_observer.dart';
import 'package:opentranscribe/view/layouts/home/components/journal_chrome.dart';
import 'package:opentranscribe/view/widgets/pane_frame.dart';
import 'package:opentranscribe/view/widgets/pane_glide.dart';

class PaneHost extends StatefulWidget {
  const PaneHost({
    required this.layout,
    required this.media,
    required this.settled,
    required this.supported,
    required this.cover,
    required this.reduceTransparency,
    required this.regular,
    required this.router,
    required this.observer,
    required this.child,
    super.key,
  });

  final PaneLayout layout;
  final MediaQueryData media;
  final bool settled;
  final bool supported;
  final bool cover;
  final bool reduceTransparency;
  final bool regular;
  final GoRouter router;
  final PaneObserver observer;
  final Widget child;

  @override
  State<PaneHost> createState() => _PaneHostState();
}

class _PaneHostState extends State<PaneHost> {
  final PaneTouchTracker _tracker = PaneTouchTracker();
  bool _routesUpdateScheduled = false;
  late final OverlayEntry _chrome = OverlayEntry(
    maintainState: true,
    builder: (_) => JournalChrome(observer: widget.observer),
  );

  @override
  void initState() {
    super.initState();
    widget.router.routerDelegate.addListener(_routesChanged);
    widget.observer.addListener(_routesChanged);
    widget.observer.attachChrome(_chrome);
  }

  void _routesChanged() {
    if (!mounted || _routesUpdateScheduled) return;
    // Initial route restoration can notify during build even while the scheduler is idle.
    // A frame must be requested so deferred updates also run when no frame is pending.
    _routesUpdateScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _routesUpdateScheduled = false;
      if (mounted) setState(() {});
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    widget.router.routerDelegate.removeListener(_routesChanged);
    widget.observer.removeListener(_routesChanged);
    widget.observer.detachChrome();
    _chrome.dispose();
    _tracker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matches = widget.router.routerDelegate.currentConfiguration;
    final pop = _tracker.update(
      layout: widget.layout,
      media: widget.media,
      settled: widget.settled,
      supported: widget.supported,
      cover: widget.cover,
      reduceTransparency: widget.reduceTransparency,
      regular: widget.regular,
      matches: matches,
      selectionOnTop: widget.observer.selectionOnTop,
    );
    if (pop) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            widget.layout.mode != PaneMode.single ||
            !widget.settled ||
            widget.router.routerDelegate.currentConfiguration != matches) {
          return;
        }
        final navigator = widget.router.routerDelegate.navigatorKey.currentState;
        if (navigator != null && popPaneSelection(navigator)) {
          _tracker.consumeCollapse();
        }
      });
    }
    return PaneLayoutScope(
      tracker: _tracker,
      child: PaneGlide(
        child: ValueListenableBuilder<PaneSelection?>(
          valueListenable: _tracker.readingSelection,
          child: widget.child,
          builder: (context, reading, child) => PaneSelectionScope(
            selection: widget.layout.mode == PaneMode.split
                ? reading ?? paneSelection(_tracker.selection)
                : null,
            child: child!,
          ),
        ),
      ),
    );
  }
}
