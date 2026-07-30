import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/reflect/foundation_models_engine.dart';
import 'package:opentranscribe/core/reflect/reflection_engine.dart';
import 'package:opentranscribe/core/reflect/reflection_exception.dart';
import 'package:opentranscribe/core/reflect/reflection_options.dart';

/// Pins the channel contract with ReflectionEngine.swift: the availability
/// status strings, the reflect payload shape, and the silence-vs-failure split.
/// This is where native/Dart drift would surface.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel('opentranscribe/reflect');

  late FoundationModelsEngine engine;

  setUp(() {
    engine = FoundationModelsEngine();
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  void mock(Future<Object?> Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(channel, handler);
  }

  group('availability', () {
    Future<void> expectStatus(String? wire, ReflectionAvailabilityStatus expected) async {
      mock((call) async {
        expect(call.method, 'availability');
        return {'status': wire};
      });
      expect((await engine.availability()).status, expected);
    }

    test('maps every native status string to its enum', () async {
      await expectStatus('available', ReflectionAvailabilityStatus.available);
      await expectStatus('not_enabled', ReflectionAvailabilityStatus.notEnabled);
      await expectStatus('model_not_ready', ReflectionAvailabilityStatus.modelNotReady);
      await expectStatus('device_not_eligible', ReflectionAvailabilityStatus.deviceNotEligible);
      await expectStatus('unsupported', ReflectionAvailabilityStatus.unsupported);
    });

    test('an unknown status reads as unsupported, not a throw', () async {
      await expectStatus('something_new', ReflectionAvailabilityStatus.unsupported);
    });

    test('a channel error is swallowed to unsupported (preflight never throws)', () async {
      mock((call) async => throw PlatformException(code: 'boom', message: 'x'));
      expect((await engine.availability()).status, ReflectionAvailabilityStatus.unsupported);
    });

    test('a missing plugin reads as unsupported', () async {
      // No handler registered: the messenger reports MissingPluginException.
      expect((await engine.availability()).status, ReflectionAvailabilityStatus.unsupported);
    });
  });

  group('reflect', () {
    final entries = [
      const ReflectionEntryInput(weekday: 1, text: 'monday thoughts', title: 'standup'),
      const ReflectionEntryInput(weekday: 7, text: 'sunday walk'),
    ];

    test('serializes entries, style, and locale under the agreed keys', () async {
      Map<String, Object?>? sent;
      mock((call) async {
        expect(call.method, 'reflect');
        sent = (call.arguments as Map).cast<String, Object?>();
        return {'text': 'a reflection'};
      });

      await engine.reflect(
        entries: entries,
        style: const ReflectionStyle(
          voice: ReflectionVoice.sparse,
          length: ReflectionLength.oneLine,
          specificity: ReflectionSpecificity.abstractThemes,
        ),
        localeId: 'en-US',
      );

      expect(sent!['localeId'], 'en-US');
      expect(sent!['style'], {'voice': 'sparse', 'length': 'one_line', 'specificity': 'abstract'});
      expect(sent!['entries'], [
        {'weekday': 1, 'text': 'monday thoughts', 'title': 'standup'},
        {'weekday': 7, 'text': 'sunday walk'},
      ]);
    });

    test('returns trimmed text', () async {
      mock((call) async => {'text': '  a reflection  '});
      expect(
        await engine.reflect(entries: entries, style: ReflectionStyle.defaults, localeId: 'en-US'),
        'a reflection',
      );
    });

    test('empty text is silence (null), not a failure', () async {
      mock((call) async => {'text': '   '});
      expect(
        await engine.reflect(entries: entries, style: ReflectionStyle.defaults, localeId: 'en-US'),
        isNull,
      );
    });

    test('a missing text key is silence (null)', () async {
      mock((call) async => <String, Object?>{});
      expect(
        await engine.reflect(entries: entries, style: ReflectionStyle.defaults, localeId: 'en-US'),
        isNull,
      );
    });

    test('the native "unavailable" code throws ReflectionUnavailable', () async {
      mock((call) async => throw PlatformException(code: 'unavailable', message: 'model busy'));
      await expectLater(
        engine.reflect(entries: entries, style: ReflectionStyle.defaults, localeId: 'en-US'),
        throwsA(isA<ReflectionUnavailable>()),
      );
    });

    test('a missing plugin throws ReflectionUnavailable (retry, not false silence)', () async {
      // No handler: could-not-run, which must be distinguishable from silence.
      await expectLater(
        engine.reflect(entries: entries, style: ReflectionStyle.defaults, localeId: 'en-US'),
        throwsA(isA<ReflectionUnavailable>()),
      );
    });
  });
}
