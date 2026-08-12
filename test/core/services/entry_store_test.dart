import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/services/entry_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transcriber/transcriber.dart';

void main() {
  const key = 'test-encryption-key-0123456789ab';

  late LocalService storage;
  late EntryStore store;

  Entry entry(String id, DateTime createdAt) => Entry(
    id: id,
    createdAt: createdAt,
    audioPath: '/audio/$id.m4a',
    duration: const Duration(seconds: 5),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalService();
    await storage.init(legacyKey: key);
    store = EntryStore(storage);
  });

  test('saves and reads an entry back', () async {
    final e = entry('one', DateTime.utc(2026, 3, 4));
    await store.save(e);

    expect(store.read('one'), e);
  });

  test('read returns null for a missing entry', () {
    expect(store.read('nope'), isNull);
  });

  test('all returns entries newest first', () async {
    await store.save(entry('old', DateTime.utc(2026, 2, 2)));
    await store.save(entry('new', DateTime.utc(2026, 8, 9)));
    await store.save(entry('mid', DateTime.utc(2026, 5, 6)));

    final ids = store.all().map((e) => e.id).toList();

    expect(ids, ['new', 'mid', 'old']);
  });

  test('delete removes an entry', () async {
    await store.save(entry('gone', DateTime.utc(2026, 3, 4)));
    await store.delete('gone');

    expect(store.read('gone'), isNull);
    expect(store.all(), isEmpty);
  });

  test('all() skips a corrupt record and keeps the valid ones', () async {
    await store.save(entry('good', DateTime.utc(2026, 3, 5)));
    // A value that does not decode to an Entry (missing required fields).
    await storage.writeJson('entry:bad', {'nope': 1});

    expect(store.all().map((e) => e.id).toList(), ['good']);
    expect(store.read('bad'), isNull);
  });

  test('an undecryptable raw value is skipped, not fatal', () async {
    // Raw garbage under the entry prefix (a key change or disk corruption): the
    // decrypt throws inside the store, which must skip it like corrupt JSON.
    SharedPreferences.setMockInitialValues({'entry:junk': 'not-fernet-ciphertext'});
    storage = LocalService();
    await storage.init(legacyKey: key);
    store = EntryStore(storage);
    await store.save(entry('good', DateTime.utc(2026, 3, 5)));

    expect(store.all().map((e) => e.id).toList(), ['good']);
    expect(store.read('junk'), isNull);
  });

  test('all() breaks createdAt ties by id', () async {
    final tied = DateTime.utc(2026, 5, 6);
    await store.save(entry('b', tied));
    await store.save(entry('a', tied));

    expect(store.all().map((e) => e.id).toList(), ['a', 'b']);
  });

  test('all serves the cache until a save invalidates it', () async {
    await store.save(entry('one', DateTime.utc(2026, 3, 4)));
    await store.save(entry('two', DateTime.utc(2026, 3, 5)));
    expect(store.all(), hasLength(2));

    await storage.writeJson('entry:three', entry('three', DateTime.utc(2026, 3, 6)).toJson());
    expect(store.all(), hasLength(2));

    await store.save(entry('four', DateTime.utc(2026, 3, 7)));
    expect(store.all(), hasLength(4));
  });

  test('a delete invalidates the cache', () async {
    await store.save(entry('one', DateTime.utc(2026, 3, 4)));
    await store.save(entry('two', DateTime.utc(2026, 3, 5)));
    expect(store.all(), hasLength(2));

    await store.delete('one');

    expect(store.all(), hasLength(1));
  });

  test('callers cannot mutate the cached list', () async {
    await store.save(entry('one', DateTime.utc(2026, 3, 4)));

    store.all().clear();

    expect(store.all(), hasLength(1));
  });

  test('round-trips an entry carrying a multi-segment transcript', () async {
    final transcript = Transcript(
      fullText: 'hello world',
      segments: const [
        TranscriptSegment(
          text: 'hello',
          start: Duration.zero,
          end: Duration(seconds: 1),
          confidence: 0.91,
        ),
        TranscriptSegment(text: 'world', start: Duration(seconds: 1), end: Duration(seconds: 2)),
      ],
      localeId: 'en-US',
      engineId: 'fake',
      createdAt: DateTime.utc(2026, 3, 4),
    );
    final e = entry('t', DateTime.utc(2026, 3, 4)).withTranscript(transcript);
    await store.save(e);

    expect(store.read('t'), e);
  });
}
