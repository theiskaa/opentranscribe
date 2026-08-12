import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/services/reflection_settings.dart';
import 'package:reflections/reflections.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const key = 'test-encryption-key-0123456789ab';

  late LocalService storage;
  late ReflectionSettings settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalService();
    await storage.init(legacyKey: key);
    settings = ReflectionSettings(storage: storage);
  });

  test('defaults: enabled, literary-tuned style', () {
    expect(settings.enabledFor(ReflectionPeriod.weekly), isTrue);
    expect(settings.voiceFor(ReflectionPeriod.weekly), ReflectionVoice.literary);
    expect(settings.lengthFor(ReflectionPeriod.weekly), ReflectionLength.sentences);
    expect(settings.specificityFor(ReflectionPeriod.weekly), ReflectionSpecificity.nameFreely);
  });

  test('round-trips each knob', () async {
    await settings.setEnabledFor(ReflectionPeriod.weekly, false);
    await settings.setVoiceFor(ReflectionPeriod.weekly, ReflectionVoice.sparse);
    await settings.setLengthFor(ReflectionPeriod.weekly, ReflectionLength.paragraph);
    await settings.setSpecificityFor(ReflectionPeriod.weekly, ReflectionSpecificity.abstractThemes);

    expect(settings.enabledFor(ReflectionPeriod.weekly), isFalse);
    expect(
      settings.styleFor(ReflectionPeriod.weekly),
      const ReflectionStyle(
        voice: ReflectionVoice.sparse,
        length: ReflectionLength.paragraph,
        specificity: ReflectionSpecificity.abstractThemes,
      ),
    );
  });

  test('an unrecognized stored value falls back to the default', () async {
    await storage.write('reflect.weekly.voice', 'from_a_future_build');
    expect(settings.voiceFor(ReflectionPeriod.weekly), ReflectionVoice.literary);
  });

  test('the floor is absent until recorded, then round-trips as a date', () async {
    expect(settings.floorFor(ReflectionPeriod.weekly), isNull);
    await settings.setFloorFor(ReflectionPeriod.weekly, DateTime(2026, 7, 20));
    expect(settings.floorFor(ReflectionPeriod.weekly), DateTime(2026, 7, 20));
  });

  test('floorRecorded reports the record even when it cannot be parsed', () async {
    expect(settings.floorRecordedFor(ReflectionPeriod.weekly), isFalse);
    await storage.write('reflect.weekly.floor', 'not-a-date');
    expect(settings.floorRecordedFor(ReflectionPeriod.weekly), isTrue);
  });

  test('an unreadable floor reads as absent, never throws', () async {
    await storage.write('reflect.weekly.floor', 'not-a-date');
    expect(settings.floorFor(ReflectionPeriod.weekly), isNull);
  });

  test('an undecryptable store falls back to defaults, never throws', () async {
    SharedPreferences.setMockInitialValues({'reflect.weekly.enabled': 'not-ciphertext'});
    storage = LocalService();
    await storage.init(legacyKey: key);
    settings = ReflectionSettings(storage: storage);

    expect(settings.enabledFor(ReflectionPeriod.weekly), isTrue);
    expect(settings.voiceFor(ReflectionPeriod.weekly), ReflectionVoice.literary);
  });

  test('by default every period is on', () {
    expect(settings.enabledFor(ReflectionPeriod.daily), isTrue);
    expect(settings.enabledFor(ReflectionPeriod.weekly), isTrue);
    expect(settings.enabledFor(ReflectionPeriod.monthly), isTrue);
    expect(settings.anyEnabled, isTrue);
  });

  test('anyEnabled is false only when every period is off', () async {
    await settings.setEnabledFor(ReflectionPeriod.weekly, false);
    await settings.setEnabledFor(ReflectionPeriod.daily, false);
    expect(settings.anyEnabled, isTrue);
    await settings.setEnabledFor(ReflectionPeriod.monthly, false);
    expect(settings.anyEnabled, isFalse);
    await settings.setEnabledFor(ReflectionPeriod.daily, true);
    expect(settings.anyEnabled, isTrue);
  });

  test('length defaults fit the period: one line for a day, a paragraph for a month', () {
    expect(settings.lengthFor(ReflectionPeriod.daily), ReflectionLength.oneLine);
    expect(settings.lengthFor(ReflectionPeriod.weekly), ReflectionLength.sentences);
    expect(settings.lengthFor(ReflectionPeriod.monthly), ReflectionLength.paragraph);
  });

  test('each period keeps its own style, independent of the others', () async {
    await settings.setVoiceFor(ReflectionPeriod.daily, ReflectionVoice.sparse);
    await settings.setVoiceFor(ReflectionPeriod.monthly, ReflectionVoice.observational);

    expect(settings.voiceFor(ReflectionPeriod.daily), ReflectionVoice.sparse);
    expect(settings.voiceFor(ReflectionPeriod.monthly), ReflectionVoice.observational);
    expect(settings.voiceFor(ReflectionPeriod.weekly), ReflectionVoice.literary);
  });

  test('each period keeps its own floor', () async {
    await settings.setFloorFor(ReflectionPeriod.daily, DateTime(2026, 8, 3));
    await settings.setFloorFor(ReflectionPeriod.monthly, DateTime(2026, 8));

    expect(settings.floorFor(ReflectionPeriod.daily), DateTime(2026, 8, 3));
    expect(settings.floorFor(ReflectionPeriod.monthly), DateTime(2026, 8));
    expect(settings.floorFor(ReflectionPeriod.weekly), isNull);
  });
}
