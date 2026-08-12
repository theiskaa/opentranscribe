import 'package:flutter_test/flutter_test.dart';
import 'package:reflections/reflections.dart';

void main() {
  test('fromWire resolves each period and falls back to null on the unknown', () {
    expect(ReflectionPeriod.fromWire('daily'), ReflectionPeriod.daily);
    expect(ReflectionPeriod.fromWire('weekly'), ReflectionPeriod.weekly);
    expect(ReflectionPeriod.fromWire('monthly'), ReflectionPeriod.monthly);
    expect(ReflectionPeriod.fromWire('from_a_future_build'), isNull);
    expect(ReflectionPeriod.fromWire(null), isNull);
  });
}
