import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/core/routes/home_destination.dart';
import 'package:opentranscribe/core/routes/routes.dart';

void main() {
  test('Home stays selected while browsing the journal or an opened record', () {
    expect(HomeDestination.home.selectedBy(null), isTrue);
    expect(HomeDestination.home.selectedBy(Uri.parse(Routes.home)), isTrue);
    expect(HomeDestination.home.selectedBy(Uri.parse('/entry/a')), isTrue);
    for (final destination in HomeDestination.values.where((d) => d != HomeDestination.home)) {
      expect(destination.selectedBy(null), isFalse);
      expect(HomeDestination.home.selectedBy(Uri.parse(destination.path)), isFalse);
    }
  });

  test('routed menu actions resolve to the same destinations as sidebar rows', () {
    for (final destination in HomeDestination.values) {
      expect(HomeDestination.forAction(destination.actionId), destination);
      expect(destination.routeName, isNotEmpty);
      expect(destination.path, startsWith('/'));
    }
  });

  test('sheets and source actions do not become selected destinations', () {
    for (final id in ['act:applang', 'act:support', 'act:source', 'app:en']) {
      expect(HomeDestination.forAction(id), isNull);
    }
  });

  test('reflection navigation stays selected while its period changes', () {
    expect(
      HomeDestination.reflections.selectedBy(
        Uri.parse('${Routes.reflections}?period=weekly&week=2026-11-09'),
      ),
      isTrue,
    );
  });

  test('selecting the same location does not create another route', () {
    final current = Uri.parse('/entry/a');
    expect(
      canChangeHomeSelection(covered: false, blocked: false, current: current, target: current),
      isFalse,
    );
  });

  test('a protected detail or covering route refuses sidebar navigation', () {
    for (final covered in [false, true]) {
      for (final blocked in [false, true]) {
        expect(
          canChangeHomeSelection(
            covered: covered,
            blocked: blocked,
            current: Uri.parse('/entry/a'),
            target: Uri.parse(Routes.home),
          ),
          !covered && !blocked,
        );
      }
    }
  });

  test('a different entry is a new selection', () {
    expect(
      canChangeHomeSelection(
        covered: false,
        blocked: false,
        current: Uri.parse('/entry/a'),
        target: Uri.parse('/entry/b'),
      ),
      isTrue,
    );
  });
}
