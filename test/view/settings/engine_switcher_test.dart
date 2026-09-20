import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/view/layouts/settings/components/engine_switcher.dart';

void main() {
  group('pagerHeight', () {
    test('a pager resting on a pane is exactly that pane tall', () {
      expect(pagerHeight([120, 300, 80], 1), 300);
    });

    test('halfway between two panes the height is halfway between theirs', () {
      expect(pagerHeight([120, 300, 80], 0.5), 210);
      expect(pagerHeight([120, 300, 80], 1.25), closeTo(245, 1e-9));
    });

    test('a rubber band past either end keeps the end pane height', () {
      expect(pagerHeight([120, 300, 80], -0.3), 120);
      expect(pagerHeight([120, 300, 80], 2.4), 80);
    });

    test('a pager with no panes has no height', () {
      expect(pagerHeight([], 0.5), 0);
    });
  });

  group('rubberBand', () {
    test('a drag past the bound moves less than the finger did', () {
      final moved = rubberBand(100, 400);
      expect(moved, greaterThan(0));
      expect(moved, lessThan(100));
    });

    test('the further past the bound, the less of each extra point it follows', () {
      final first = rubberBand(50, 400);
      final second = rubberBand(100, 400) - first;
      expect(second, lessThan(first));
    });

    test('it gives in both directions alike', () {
      expect(rubberBand(-80, 400), -rubberBand(80, 400));
    });

    test('it never reaches the whole dimension however far the drag goes', () {
      expect(rubberBand(1e9, 400), lessThan(400));
    });
  });

  group('projectedTravel', () {
    test("a flick carries on the way Apple's scroll deceleration projects it", () {
      expect(projectedTravel(1000, rate: 0.998), closeTo(499, 1e-9));
    });

    test('a slower deceleration rate carries a flick less far', () {
      expect(projectedTravel(1000, rate: 0.99), lessThan(projectedTravel(1000, rate: 0.998)));
    });

    test('a release at rest carries nowhere', () {
      expect(projectedTravel(0, rate: 0.998), 0);
    });
  });

  group('settlePane', () {
    test('a slow release settles on the nearer pane', () {
      expect(settlePane(position: 1.4, travel: 0, from: 1, first: 0, last: 2), 1);
      expect(settlePane(position: 1.6, travel: 0, from: 1, first: 0, last: 2), 2);
    });

    test('a flick past the halfway point lands on the next pane even from a short drag', () {
      expect(settlePane(position: 1.1, travel: 0.6, from: 1, first: 0, last: 2), 2);
    });

    test('however hard the flick, it moves at most one pane from where the drag began', () {
      expect(settlePane(position: 0.2, travel: 5, from: 0, first: 0, last: 2), 1);
      expect(settlePane(position: 1.8, travel: -5, from: 2, first: 0, last: 2), 1);
    });

    test('a flick off either end stays on the end pane', () {
      expect(settlePane(position: -0.2, travel: -3, from: 0, first: 0, last: 2), 0);
      expect(settlePane(position: 2.2, travel: 3, from: 2, first: 0, last: 2), 2);
    });

    test('a thumb dragged across the whole control lands where it was put', () {
      expect(settlePane(position: 2, travel: 0, from: 0, first: 0, last: 2, reach: 3), 2);
    });

    test('a pager held to a run of panes settles inside it however it is flicked', () {
      expect(settlePane(position: 0.9, travel: 2, from: 1, first: 0, last: 1), 1);
    });

    test('a locked pager, first and last the same pane, always returns to it', () {
      expect(settlePane(position: 1.3, travel: 2, from: 1, first: 1, last: 1), 1);
    });
  });
}
