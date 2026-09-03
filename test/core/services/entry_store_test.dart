import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/services/entry_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transcriber/transcriber.dart';

class _FailsWhenArmed extends LocalService {
  bool failWrites = false;
  bool failDeletes = false;

  @override
  Future<void> writeJson(String key, Object value) {
    if (failWrites) throw StateError('no disk');
    return super.writeJson(key, value);
  }

  @override
  Future<bool> delete(String key) {
    if (failDeletes) throw StateError('no disk');
    return super.delete(key);
  }
}

class _CountingReads extends LocalService {
  int readJsonCalls = 0;

  @override
  T? readJson<T>(String key, T Function(Map<String, dynamic>) fromJson) {
    readJsonCalls++;
    return super.readJson(key, fromJson);
  }
}

class _GatedReads extends LocalService {
  final Completer<void> gate = Completer<void>();

  @override
  Future<List<T>?> readAllOnIsolate<T>(
    String prefix,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final result = await super.readAllOnIsolate(prefix, fromJson);
    await gate.future;
    return result;
  }
}

class _SlowAcks extends LocalService {
  final List<Completer<void>> acks = [];

  @override
  Future<void> writeJson(String key, Object value) async {
    await super.writeJson(key, value);
    final ack = Completer<void>();
    acks.add(ack);
    await ack.future;
  }
}

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

  test('a save lands in the cache without a rescan of the backing store', () async {
    await store.save(entry('one', DateTime.utc(2026, 3, 4)));
    await store.save(entry('two', DateTime.utc(2026, 3, 5)));
    expect(store.all(), hasLength(2));

    await storage.writeJson('entry:three', entry('three', DateTime.utc(2026, 3, 6)).toJson());
    await store.save(entry('four', DateTime.utc(2026, 3, 7)));

    expect(store.all().map((e) => e.id).toList(), ['four', 'two', 'one']);
  });

  test('a save lands at its sorted position among the existing entries', () async {
    await store.save(entry('old', DateTime.utc(2026, 2, 2)));
    await store.save(entry('new', DateTime.utc(2026, 8, 9)));
    expect(store.all(), hasLength(2));

    await store.save(entry('mid', DateTime.utc(2026, 5, 6)));

    expect(store.all().map((e) => e.id).toList(), ['new', 'mid', 'old']);
  });

  test('saving an existing id replaces it without duplicating', () async {
    await store.save(entry('one', DateTime.utc(2026, 3, 4)));
    await store.save(entry('two', DateTime.utc(2026, 3, 5)));
    expect(store.all(), hasLength(2));

    await store.save(entry('one', DateTime.utc(2026, 3, 4)).withTitle('renamed'));

    final all = store.all();
    expect(all.map((e) => e.id).toList(), ['two', 'one']);
    expect(all.last.title, 'renamed');
  });

  test('unchanged entries keep their identity across reads and saves', () async {
    await store.save(entry('one', DateTime.utc(2026, 3, 4)));
    final before = store.all().single;

    await store.save(entry('two', DateTime.utc(2026, 3, 5)));

    expect(identical(store.all().last, before), isTrue);
  });

  test('a delete removes the entry from the list', () async {
    await store.save(entry('one', DateTime.utc(2026, 3, 4)));
    await store.save(entry('two', DateTime.utc(2026, 3, 5)));
    expect(store.all(), hasLength(2));

    await store.delete('one');

    expect(store.all().map((e) => e.id).toList(), ['two']);
  });

  test('a failed write falls back to re-reading the backing store', () async {
    final failing = _FailsWhenArmed();
    await failing.init(legacyKey: key);
    final failingStore = EntryStore(failing);
    await failingStore.save(entry('one', DateTime.utc(2026, 3, 4)));
    expect(failingStore.all(), hasLength(1));

    failing.failWrites = true;
    await expectLater(failingStore.save(entry('two', DateTime.utc(2026, 3, 5))), throwsStateError);

    expect(failingStore.all().map((e) => e.id).toList(), ['one']);
  });

  test('a failed delete falls back to re-reading the backing store', () async {
    final failing = _FailsWhenArmed();
    await failing.init(legacyKey: key);
    final failingStore = EntryStore(failing);
    await failingStore.save(entry('one', DateTime.utc(2026, 3, 4)));
    expect(failingStore.all(), hasLength(1));

    failing.failDeletes = true;
    await expectLater(failingStore.delete('one'), throwsStateError);

    expect(failingStore.all().map((e) => e.id).toList(), ['one']);
  });

  test('overlapping saves of one entry keep the later, whatever order the disk answers', () async {
    final slow = _SlowAcks();
    await slow.init(legacyKey: key);
    final slowStore = EntryStore(slow);
    final seed = slowStore.save(entry('one', DateTime.utc(2026, 3, 4)));
    await Future<void>.delayed(Duration.zero);
    slow.acks.single.complete();
    await seed;
    slow.acks.clear();

    final first = slowStore.save(entry('one', DateTime.utc(2026, 3, 4)).withTitle('first'));
    final second = slowStore.save(entry('one', DateTime.utc(2026, 3, 4)).withTitle('second'));
    await Future<void>.delayed(Duration.zero);
    slow.acks[1].complete();
    slow.acks[0].complete();
    await first;
    await second;

    expect(slowStore.all().single.title, 'second');
  });

  test('callers cannot mutate the cached list', () async {
    await store.save(entry('one', DateTime.utc(2026, 3, 4)));

    store.all().clear();

    expect(store.all(), hasLength(1));
  });

  test('warm builds the cache off-thread so the first read decrypts nothing', () async {
    final counting = _CountingReads();
    await counting.init(legacyKey: key, deviceKey: Uint8List(32));
    await EntryStore(counting).save(entry('one', DateTime.utc(2026, 3, 4)));
    final cold = EntryStore(counting);

    await cold.warm();
    counting.readJsonCalls = 0;

    expect(cold.all().map((e) => e.id).toList(), ['one']);
    expect(counting.readJsonCalls, 0);
  });

  test('warm without a device key leaves the read on the synchronous path', () async {
    await store.save(entry('one', DateTime.utc(2026, 3, 4)));
    final cold = EntryStore(storage);

    await cold.warm();

    expect(cold.all().map((e) => e.id).toList(), ['one']);
  });

  test('a save landing mid-warm wins over the warmed snapshot', () async {
    final gated = _GatedReads();
    await gated.init(legacyKey: key, deviceKey: Uint8List(32));
    await EntryStore(gated).save(entry('one', DateTime.utc(2026, 3, 4)));
    final cold = EntryStore(gated);

    final warming = cold.warm();
    await cold.save(entry('two', DateTime.utc(2026, 3, 5)));
    gated.gate.complete();
    await warming;

    expect(cold.all().map((e) => e.id).toSet(), {'one', 'two'});
  });

  test('warm never replaces a cache a read already built', () async {
    final gated = _GatedReads();
    await gated.init(legacyKey: key, deviceKey: Uint8List(32));
    await EntryStore(gated).save(entry('one', DateTime.utc(2026, 3, 4)));
    final cold = EntryStore(gated);

    final warming = cold.warm();
    final before = cold.all().single;
    gated.gate.complete();
    await warming;

    expect(identical(cold.all().single, before), isTrue);
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
