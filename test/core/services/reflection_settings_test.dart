import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/reflect/reflection_options.dart';
import 'package:opentranscribe/core/reflect/reflection_period.dart';
import 'package:opentranscribe/core/services/reflection_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const key = 'test-encryption-key-0123456789ab';

  late LocalService storage;
  late ReflectionSettings settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalService();
    await storage.init(encryptionKey: key);
    settings = ReflectionSettings(storage: storage);
  });

  test('defaults: enabled, literary-tuned style', () {
    expect(settings.enabled, isTrue);
    expect(settings.voice, ReflectionVoice.literary);
    expect(settings.length, ReflectionLength.sentences);
    expect(settings.specificity, ReflectionSpecificity.nameFreely);
  });

  test('round-trips each knob', () async {
    await settings.setEnabled(false);
    await settings.setVoice(ReflectionVoice.sparse);
    await settings.setLength(ReflectionLength.paragraph);
    await settings.setSpecificity(ReflectionSpecificity.abstractThemes);

    expect(settings.enabled, isFalse);
    expect(
      settings.style,
      const ReflectionStyle(
        voice: ReflectionVoice.sparse,
        length: ReflectionLength.paragraph,
        specificity: ReflectionSpecificity.abstractThemes,
      ),
    );
  });

  test('an unrecognized stored value falls back to the default', () async {
    await storage.write('reflect.weekly.voice', 'from_a_future_build');
    expect(settings.voice, ReflectionVoice.literary);
  });

  test('the floor is absent until recorded, then round-trips as a date', () async {
    expect(settings.floor, isNull);
    await settings.setFloor(DateTime(2026, 7, 20));
    expect(settings.floor, DateTime(2026, 7, 20));
  });

  test('floorRecorded reports the record even when it cannot be parsed', () async {
    expect(settings.floorRecorded, isFalse);
    await storage.write('reflect.weekly.floor', 'not-a-date');
    expect(settings.floorRecorded, isTrue);
  });

  test('an unreadable floor reads as absent, never throws', () async {
    await storage.write('reflect.weekly.floor', 'not-a-date');
    expect(settings.floor, isNull);
  });

  test('an undecryptable store falls back to defaults, never throws', () async {
    SharedPreferences.setMockInitialValues({'reflect.weekly.enabled': 'not-ciphertext'});
    storage = LocalService();
    await storage.init(encryptionKey: key);
    settings = ReflectionSettings(storage: storage);

    expect(settings.enabled, isTrue);
    expect(settings.voice, ReflectionVoice.literary);
  });

  test('by default weekly is on while daily and monthly are off', () {
    expect(settings.enabledFor(ReflectionPeriod.weekly), isTrue);
    expect(settings.enabledFor(ReflectionPeriod.daily), isFalse);
    expect(settings.enabledFor(ReflectionPeriod.monthly), isFalse);
    expect(settings.anyEnabled, isTrue);
  });

  test('anyEnabled is false only when every period is off', () async {
    await settings.setEnabledFor(ReflectionPeriod.weekly, false);
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
