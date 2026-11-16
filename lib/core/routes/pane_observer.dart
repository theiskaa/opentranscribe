import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:opentranscribe/core/routes/app_pages.dart';
import 'package:opentranscribe/core/routes/pane_page.dart';

class PaneObserver extends NavigatorObserver with ChangeNotifier {
  final List<Route<dynamic>> _routes = [];
  final Map<Object, Route<dynamic>> _bottomSlotOwners = {};
  Route<dynamic>? _top;
  OverlayEntry? _chrome;
  bool _scheduled = false;
  bool _chromeInserted = false;

  bool get selectionOnTop => _top?.settings is PanePage;

  bool get detailNavigationBlocked => _routes.any(
    (route) =>
        route.isActive &&
        route.settings is PanePage &&
        route.popDisposition == RoutePopDisposition.doNotPop,
  );

  bool get chromeCovered =>
      _routes.any((route) => route.settings is SlideUpPage || route.settings is NoTransitionPage);

  bool get bottomSlotOccupied => _top != null && _bottomSlotOwners.containsValue(_top);

  void setBottomSlotOwner(Object owner, Route<dynamic>? route) {
    final previous = _bottomSlotOwners[owner];
    if (previous == route) return;
    if (route == null) {
      _bottomSlotOwners.remove(owner);
    } else {
      _bottomSlotOwners[owner] = route;
    }
    notifyListeners();
  }

  void attachChrome(OverlayEntry entry) {
    _chrome = entry;
    _scheduleChrome();
  }

  void detachChrome() {
    if (_chromeInserted) _chrome?.remove();
    _chromeInserted = false;
    _chrome = null;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    if (route is TransitionRoute<dynamic>) {
      // Navigator rearranges its entries at both ends of a transition,
      // so the persistent chrome must keep its seat through both passes.
      route.animation?.addStatusListener((_) => _scheduleChrome());
      route.completed.then((_) {
        _routes.remove(route);
        _bottomSlotOwners.removeWhere((_, ownedRoute) => ownedRoute == route);
        notifyListeners();
        _scheduleChrome();
      });
    }
    _scheduleChrome();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? _routes.length : _routes.indexOf(oldRoute);
    _routes.remove(oldRoute);
    _bottomSlotOwners.removeWhere((_, ownedRoute) => ownedRoute == oldRoute);
    if (newRoute != null) {
      didPush(newRoute, null);
      _routes.remove(newRoute);
      _routes.insert(index.clamp(0, _routes.length), newRoute);
    }
    _scheduleChrome();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
    _bottomSlotOwners.removeWhere((_, ownedRoute) => ownedRoute == route);
    _scheduleChrome();
  }

  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    _top = topRoute;
    notifyListeners();
    _scheduleChrome();
  }

  void _scheduleChrome() {
    if (_scheduled || _chrome == null) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      final chrome = _chrome;
      final overlay = navigator?.overlay;
      if (chrome == null || overlay == null) return;
      final below = paneChromeAnchor(
        _routes.map(
          (route) => (
            coversChrome: route.settings is! ArrivalPage && route.settings is! PanePage,
            active: route.isActive,
            transition: route is TransitionRoute ? route.animation?.status : null,
            entries: route.overlayEntries,
          ),
        ),
      );
      // Route completion follows overlay removal, so the observer's route list
      // can still contain removed entries. Only Navigator may insert those.
      if (_chromeInserted) chrome.remove();
      overlay.insert(chrome, below: below);
      _chromeInserted = true;
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }
}

T? paneChromeAnchor<T>(
  Iterable<({bool coversChrome, bool active, AnimationStatus? transition, Iterable<T> entries})>
  routes,
) {
  for (final route in routes) {
    final present = route.active || route.transition == AnimationStatus.reverse;
    if (present && route.coversChrome && route.entries.isNotEmpty) {
      return route.entries.first;
    }
  }
  return null;
}
