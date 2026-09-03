import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/view/layouts/onboarding/components/back_only_physics.dart';

FixedScrollMetrics _metrics(double pixels) => FixedScrollMetrics(
  minScrollExtent: 0,
  maxScrollExtent: 780,
  pixels: pixels,
  viewportDimension: 390,
  axisDirection: AxisDirection.right,
  devicePixelRatio: 3,
);

void main() {
  test('a scroll past the gate reports only the excess', () {
    expect(forwardOverscroll(value: 450, pixels: 390, gate: 390), 60);
  });

  test('a scroll back or within the page passes untouched', () {
    expect(forwardOverscroll(value: 200, pixels: 390, gate: 390), 0);
    expect(forwardOverscroll(value: 390, pixels: 300, gate: 390), 0);
  });

  test('the first page blocks every forward move', () {
    expect(forwardOverscroll(value: 1, pixels: 0, gate: 0), 1);
    expect(forwardOverscroll(value: -20, pixels: 0, gate: 0), 0);
  });

  test('pixels already past a closed gate move back freely and forward not at all', () {
    expect(forwardOverscroll(value: 807.7, pixels: 808.9, gate: 804), 0);
    expect(forwardOverscroll(value: 810, pixels: 808.9, gate: 804), closeTo(1.1, 1e-9));
  });

  test('a pager at rest closes the gate on its page, float noise included', () {
    expect(restingReach(pixels: 804, viewportDimension: 402), 2);
    expect(restingReach(pixels: 804.00000000001, viewportDimension: 402), 2);
    expect(restingReach(pixels: 0, viewportDimension: 402), 0);
  });

  test('a pager frozen between pages keeps the gate ahead of the pixels', () {
    expect(restingReach(pixels: 808.9, viewportDimension: 402), 3);
    expect(restingReach(pixels: 1004, viewportDimension: 402), 3);
    expect(restingReach(pixels: 1005, viewportDimension: 402), 3);
  });

  test('the physics gate the page the button unlocked, in viewport widths', () {
    var reach = 1;
    final physics = BackOnlyPagePhysics(reach: () => reach);
    expect(physics.applyBoundaryConditions(_metrics(390), 450), 60);
    expect(physics.applyBoundaryConditions(_metrics(390), 300), 0);
    reach = 2;
    expect(physics.applyBoundaryConditions(_metrics(390), 450), 0);
  });

  test('composed onto a parent, the physics keep the live gate and the parent its own bounds', () {
    final physics = BackOnlyPagePhysics(reach: () => 0).applyTo(const ClampingScrollPhysics());
    expect(physics.applyBoundaryConditions(_metrics(0), 10), 10);
    expect(physics.applyBoundaryConditions(_metrics(0), -10), -10);
  });
}
