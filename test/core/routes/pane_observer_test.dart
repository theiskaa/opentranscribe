import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/core/routes/pane_observer.dart';
import 'package:opentranscribe/core/routes/pane_page.dart';

void main() {
  test('a live protected detail blocks replacement until its exit guard releases', () {
    final observer = PaneObserver();
    final route = _ProtectedRoute();
    observer.didPush(route, null);
    expect(observer.detailNavigationBlocked, isTrue);
    route.blocked = false;
    expect(observer.detailNavigationBlocked, isFalse);
    observer.didRemove(route, null);
    observer.dispose();
  });

  test('a removed protected detail cannot block Home', () {
    final observer = PaneObserver();
    final route = _ProtectedRoute();
    observer.didPush(route, null);
    route.active = false;
    expect(observer.detailNavigationBlocked, isFalse);
    observer.didRemove(route, null);
    observer.dispose();
  });

  test('the active editor owns the bottom slot until it releases it', () {
    final observer = PaneObserver();
    final route = _TestRoute();
    final editor = Object();
    var notifications = 0;
    observer.addListener(() => notifications++);
    observer.didChangeTop(route, null);
    expect(observer.bottomSlotOccupied, isFalse);
    observer.setBottomSlotOwner(editor, route);
    expect(observer.bottomSlotOccupied, isTrue);
    observer.setBottomSlotOwner(editor, route);
    expect(notifications, 2);
    observer.setBottomSlotOwner(editor, null);
    expect(observer.bottomSlotOccupied, isFalse);
    expect(notifications, 3);
    observer.dispose();
  });

  test('a covered editor keeps its slot when its route returns to the top', () {
    final observer = PaneObserver();
    final entry = _TestRoute();
    final settings = _TestRoute();
    observer.didChangeTop(entry, null);
    observer.setBottomSlotOwner(Object(), entry);
    observer.didChangeTop(settings, entry);
    expect(observer.bottomSlotOccupied, isFalse);
    observer.didChangeTop(entry, settings);
    expect(observer.bottomSlotOccupied, isTrue);
    observer.didRemove(entry, null);
    expect(observer.bottomSlotOccupied, isFalse);
    observer.dispose();
  });

  test('releasing an old editor does not release another editor on the same route', () {
    final observer = PaneObserver();
    final route = _TestRoute();
    final oldEditor = Object();
    final newEditor = Object();
    observer.didChangeTop(route, null);
    observer.setBottomSlotOwner(oldEditor, route);
    observer.setBottomSlotOwner(newEditor, route);
    observer.setBottomSlotOwner(oldEditor, null);
    expect(observer.bottomSlotOccupied, isTrue);
    observer.setBottomSlotOwner(newEditor, null);
    expect(observer.bottomSlotOccupied, isFalse);
    observer.dispose();
  });

  test('persistent chrome paints above every detail page', () {
    expect(
      paneChromeAnchor([_overlayRoute('home'), _overlayRoute('entry'), _overlayRoute('settings')]),
      isNull,
    );
  });

  test('recorder and onboarding cover persistent chrome', () {
    for (final cover in ['recorder', 'onboarding']) {
      expect(
        paneChromeAnchor([
          _overlayRoute('home'),
          _overlayRoute('entry'),
          _overlayRoute(cover, coversChrome: true),
        ]),
        '$cover-barrier',
      );
    }
  });

  test('a dismissing dialog stays above chrome until its entries leave', () {
    expect(
      paneChromeAnchor([
        _overlayRoute('home'),
        _overlayRoute('entry'),
        _overlayRoute(
          'dialog',
          coversChrome: true,
          active: false,
          transition: AnimationStatus.reverse,
        ),
      ]),
      'dialog-barrier',
    );
  });

  test('a finalized dialog is ignored before its completion future resolves', () {
    expect(
      paneChromeAnchor([
        _overlayRoute('home'),
        _overlayRoute(
          'dialog',
          coversChrome: true,
          active: false,
          transition: AnimationStatus.dismissed,
        ),
      ]),
      isNull,
    );
  });

  test('a removed route with a completed entrance cannot anchor chrome', () {
    expect(
      paneChromeAnchor([
        _overlayRoute('home'),
        _overlayRoute('old-dialog', coversChrome: true, active: false),
        _overlayRoute('new-dialog', coversChrome: true),
      ]),
      'new-dialog-barrier',
    );
  });

  test('a removed route still entering cannot anchor chrome', () {
    expect(
      paneChromeAnchor([
        _overlayRoute(
          'dialog',
          coversChrome: true,
          active: false,
          transition: AnimationStatus.forward,
        ),
      ]),
      isNull,
    );
  });

  test('the lowest covering route keeps chrome below stacked dialogs', () {
    expect(
      paneChromeAnchor([
        _overlayRoute('home'),
        _overlayRoute('first-dialog', coversChrome: true),
        _overlayRoute('second-dialog', coversChrome: true),
      ]),
      'first-dialog-barrier',
    );
  });

  test('a disposed route with no entries cannot anchor chrome', () {
    expect(
      paneChromeAnchor(const [
        (coversChrome: true, active: false, transition: null, entries: <String>[]),
      ]),
      isNull,
    );
  });
}

class _TestRoute extends Route<void> {}

class _ProtectedRoute extends Route<void> {
  _ProtectedRoute() : super(settings: const PanePage<void>(child: SizedBox.shrink()));

  bool blocked = true;
  bool active = true;

  @override
  bool get isActive => active;

  @override
  RoutePopDisposition get popDisposition =>
      blocked ? RoutePopDisposition.doNotPop : RoutePopDisposition.pop;
}

({bool coversChrome, bool active, AnimationStatus? transition, Iterable<String> entries})
_overlayRoute(
  String name, {
  bool coversChrome = false,
  bool active = true,
  AnimationStatus? transition = AnimationStatus.completed,
}) => (
  coversChrome: coversChrome,
  active: active,
  transition: transition,
  entries: ['$name-barrier', name],
);
