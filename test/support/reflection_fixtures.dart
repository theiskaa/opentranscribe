import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/services/reflection_settings.dart';
import 'package:opentranscribe/core/services/reflection_store.dart';
import 'package:opentranscribe/core/transcribe/transcript.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A Monday-first week boundary, injected so the reflection suites never
/// depend on the ambient Intl locale (utils/week has its own coverage).
DateTime mondayStart(DateTime d) {
  final day = DateTime(d.year, d.month, d.day);
  return day.subtract(Duration(days: day.weekday - 1));
}

/// An entry carrying transcribed [text] (or none when null), the reflection
/// suites' standard material.
Entry withText(String id, DateTime createdAt, {String? text, String? title}) => Entry(
  id: id,
  createdAt: createdAt,
  audioPath: null,
  duration: const Duration(seconds: 1),
  title: title,
  transcript: text == null
      ? null
      : Transcript(
          fullText: text,
          segments: [
            TranscriptSegment(text: text, start: Duration.zero, end: const Duration(seconds: 1)),
          ],
          localeId: 'en-US',
          engineId: 'fake',
          createdAt: createdAt,
        ),
);

/// Fresh mock-backed encrypted storage with the reflection store and settings
/// over it.
Future<({LocalService storage, ReflectionStore store, ReflectionSettings settings})>
reflectionStorage() async {
  SharedPreferences.setMockInitialValues({});
  final storage = LocalService();
  await storage.init(legacyKey: 'test-encryption-key-0123456789ab');
  return (
    storage: storage,
    store: ReflectionStore(storage),
    settings: ReflectionSettings(storage: storage),
  );
}
