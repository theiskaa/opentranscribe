import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/core/export/archive_codec.dart';
import 'package:opentranscribe/core/export/archive_manifest.dart';
import 'package:opentranscribe/core/reflect/reflection_period.dart';

void main() {
  group('ArchiveManifest', () {
    ArchiveManifest sample() => ArchiveManifest(
      appVersion: '0.1.0',
      createdAt: DateTime.utc(2026, 8, 7, 12),
      counts: const ArchiveCounts(entries: 3, audio: 2, reflections: 4, tombstones: 1),
      tombstones: [(period: ReflectionPeriod.weekly, start: DateTime(2026, 1, 5))],
      floors: {
        ReflectionPeriod.daily: DateTime(2026, 2),
        ReflectionPeriod.weekly: DateTime(2026, 1, 5),
      },
    );

    test('round-trips through json', () {
      final manifest = sample();
      final parsed = ArchiveManifest.fromJson(manifest.toJson());
      expect(parsed.formatVersion, manifest.formatVersion);
      expect(parsed.appVersion, manifest.appVersion);
      expect(parsed.createdAt, manifest.createdAt);
      expect(parsed.counts, manifest.counts);
      expect(parsed.tombstones, manifest.tombstones);
      expect(parsed.floors, manifest.floors);
    });

    test('ignores unknown fields', () {
      final json = sample().toJson()..['futureField'] = {'x': 1};
      expect(() => ArchiveManifest.fromJson(json), returnsNormally);
    });

    test('skips tombstones and floors with unknown period wires', () {
      final json = sample().toJson();
      (json['tombstones'] as List).add({'period': 'quarterly', 'start': '2026-01-01'});
      (json['floors'] as Map)['quarterly'] = '2026-01-01';
      final parsed = ArchiveManifest.fromJson(json);
      expect(parsed.tombstones, hasLength(1));
      expect(parsed.floors, hasLength(2));
    });

    test('a future format version reads as unsupported', () {
      final json = sample().toJson()..['formatVersion'] = ArchiveManifest.version + 1;
      expect(
        () => ArchiveManifest.fromJson(json),
        throwsA(_archiveError(ArchiveError.unsupportedVersion)),
      );
    });

    test('a wrong format id reads as malformed', () {
      final json = sample().toJson()..['format'] = 'somebody-elses-archive';
      expect(() => ArchiveManifest.fromJson(json), throwsA(_archiveError(ArchiveError.malformed)));
    });

    test('a damaged tombstone date reads as malformed', () {
      final json = sample().toJson();
      (json['tombstones'] as List).add({'period': 'weekly', 'start': 'not-a-date'});
      expect(() => ArchiveManifest.fromJson(json), throwsA(_archiveError(ArchiveError.malformed)));
    });

    test('hostile value types read as malformed, never a raw type error', () {
      final hostile = <Map<String, dynamic> Function(Map<String, dynamic>)>[
        (j) => j..['createdAt'] = 123,
        (j) => j..['appVersion'] = 9,
        (j) => j..['tombstones'] = {'a': 1},
        (j) => j..['tombstones'] = [7],
        (j) => (j
          ..['tombstones'] = [
            {'period': 7, 'start': '2026-01-01'},
          ]),
        (j) => j..['floors'] = [1, 2],
        (j) => j..['floors'] = {'weekly': 5},
        (j) => j..['counts'] = {'entries': 'five'},
      ];
      for (final mutate in hostile) {
        expect(
          () => ArchiveManifest.fromJson(mutate(sample().toJson())),
          throwsA(_archiveError(ArchiveError.malformed)),
        );
      }
    });

    test('a damaged floor date reads as malformed', () {
      final json = sample().toJson();
      (json['floors'] as Map)['weekly'] = 'not-a-date';
      expect(() => ArchiveManifest.fromJson(json), throwsA(_archiveError(ArchiveError.malformed)));
    });

    test('a missing format version reads as malformed', () {
      final json = sample().toJson()..remove('formatVersion');
      expect(() => ArchiveManifest.fromJson(json), throwsA(_archiveError(ArchiveError.malformed)));
    });

    test('missing collections read as empty', () {
      final json = sample().toJson()
        ..remove('tombstones')
        ..remove('floors')
        ..remove('counts');
      final parsed = ArchiveManifest.fromJson(json);
      expect(parsed.tombstones, isEmpty);
      expect(parsed.floors, isEmpty);
      expect(parsed.counts.entries, 0);
    });
  });
}

Matcher _archiveError(ArchiveError error) =>
    isA<ArchiveException>().having((e) => e.error, 'error', error);
