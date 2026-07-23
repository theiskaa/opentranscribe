import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/transcribe/transcription_engine.dart';

void main() {
  group('Availability', () {
    test('equality is by value', () {
      const a = Availability(AvailabilityStatus.permissionDenied, detail: 'no');
      const b = Availability(AvailabilityStatus.permissionDenied, detail: 'no');
      const differsByStatus = Availability(AvailabilityStatus.onDeviceUnavailable, detail: 'no');
      const differsByDetail = Availability(AvailabilityStatus.permissionDenied);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(differsByStatus));
      expect(a, isNot(differsByDetail));
      expect(const Availability.available().isAvailable, isTrue);
      expect(a.isAvailable, isFalse);
    });
  });

  group('ModelInstallProgress', () {
    test('equality is by value', () {
      const a = ModelInstallProgress(fraction: 0.5, done: false);
      const b = ModelInstallProgress(fraction: 0.5, done: false);
      const differsByDone = ModelInstallProgress(fraction: 0.5, done: true);
      const differsByFraction = ModelInstallProgress(fraction: 0.6, done: false);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(differsByDone));
      expect(a, isNot(differsByFraction));
    });
  });
}
