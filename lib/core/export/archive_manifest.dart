import 'package:flutter/foundation.dart';

import 'package:opentranscribe/core/export/archive_codec.dart';
import 'package:opentranscribe/core/models/reflection.dart';
import 'package:opentranscribe/core/reflect/reflection_period.dart';
import 'package:opentranscribe/core/utils/week.dart';

/// Entry and reflection totals, informational: display and sanity, never a
/// substitute for parsing the payload strictly.
@immutable
final class ArchiveCounts {
  const ArchiveCounts({
    required this.entries,
    required this.audio,
    required this.reflections,
    required this.tombstones,
  });

  final int entries;
  final int audio;
  final int reflections;
  final int tombstones;

  Map<String, dynamic> toJson() => {
    'entries': entries,
    'audio': audio,
    'reflections': reflections,
    'tombstones': tombstones,
  };

  factory ArchiveCounts.fromJson(Map<String, dynamic> json) => ArchiveCounts(
    entries: (json['entries'] as num?)?.toInt() ?? 0,
    audio: (json['audio'] as num?)?.toInt() ?? 0,
    reflections: (json['reflections'] as num?)?.toInt() ?? 0,
    tombstones: (json['tombstones'] as num?)?.toInt() ?? 0,
  );

  @override
  bool operator ==(Object other) =>
      other is ArchiveCounts &&
      other.entries == entries &&
      other.audio == audio &&
      other.reflections == reflections &&
      other.tombstones == tombstones;

  @override
  int get hashCode => Object.hash(entries, audio, reflections, tombstones);
}

typedef ReflectionRef = ({ReflectionPeriod period, DateTime start});

/// The payload zip's manifest.json. Tombstones and per-period no-backfill
/// floors ride here rather than as files because they are what make restore
/// honest: without tombstones the catch-up re-reflects erased periods, and
/// without floors it either backfills nothing or churns pre-feature history.
/// Unknown JSON fields are ignored and unknown period wires are skipped, so
/// a newer minor writer stays readable; a [formatVersion] above ours is a
/// hard [ArchiveError.unsupportedVersion] refusal instead.
@immutable
final class ArchiveManifest {
  ArchiveManifest({
    required this.appVersion,
    required DateTime createdAt,
    required this.counts,
    required List<ReflectionRef> tombstones,
    required Map<ReflectionPeriod, DateTime> floors,
    this.formatVersion = version,
  }) : createdAt = createdAt.toUtc(),
       tombstones = List.unmodifiable(tombstones),
       floors = Map.unmodifiable(floors);

  static const format = 'opentranscribe-archive';
  static const version = 1;

  final int formatVersion;
  final String appVersion;
  final DateTime createdAt;
  final ArchiveCounts counts;
  final List<ReflectionRef> tombstones;
  final Map<ReflectionPeriod, DateTime> floors;

  Map<String, dynamic> toJson() => {
    'format': format,
    'formatVersion': formatVersion,
    'appVersion': appVersion,
    'createdAt': createdAt.toIso8601String(),
    'counts': counts.toJson(),
    'tombstones': [
      for (final t in tombstones) {'period': t.period.wire, 'start': Reflection.keyFor(t.start)},
    ],
    'floors': {for (final f in floors.entries) f.key.wire: Reflection.keyFor(f.value)},
  };

  /// Strict, and strict about being strict: a plain zip's manifest is
  /// attacker-controlled with no tag protecting it, so a hostile value TYPE
  /// must surface as the contract's malformed error, never a raw TypeError.
  factory ArchiveManifest.fromJson(Map<String, dynamic> json) {
    try {
      return ArchiveManifest._parse(json);
    } on TypeError {
      throw const ArchiveException(ArchiveError.malformed, 'manifest fields damaged');
    }
  }

  factory ArchiveManifest._parse(Map<String, dynamic> json) {
    if (json['format'] != format) {
      throw const ArchiveException(ArchiveError.malformed, 'not an archive manifest');
    }
    final formatVersion = json['formatVersion'];
    if (formatVersion is! int) {
      throw const ArchiveException(ArchiveError.malformed, 'manifest version missing');
    }
    if (formatVersion > version) {
      throw const ArchiveException(
        ArchiveError.unsupportedVersion,
        'written by a newer version of the app',
      );
    }
    final appVersion = json['appVersion'];
    final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '');
    if (appVersion is! String || createdAt == null) {
      throw const ArchiveException(ArchiveError.malformed, 'manifest fields missing');
    }
    final tombstones = <ReflectionRef>[];
    for (final raw in json['tombstones'] as List? ?? const []) {
      if (raw is! Map) {
        throw const ArchiveException(ArchiveError.malformed, 'manifest tombstone damaged');
      }
      final period = ReflectionPeriod.fromWire(raw['period'] as String?);
      final start = DateTime.tryParse(raw['start'] as String? ?? '');
      if (start == null) {
        throw const ArchiveException(ArchiveError.malformed, 'manifest tombstone damaged');
      }
      if (period == null) continue;
      tombstones.add((period: period, start: dateOnly(start)));
    }
    final floors = <ReflectionPeriod, DateTime>{};
    for (final raw in (json['floors'] as Map? ?? const {}).entries) {
      final period = ReflectionPeriod.fromWire(raw.key as String?);
      final date = DateTime.tryParse(raw.value as String? ?? '');
      if (date == null) {
        throw const ArchiveException(ArchiveError.malformed, 'manifest floor damaged');
      }
      if (period == null) continue;
      floors[period] = dateOnly(date);
    }
    return ArchiveManifest(
      formatVersion: formatVersion,
      appVersion: appVersion,
      createdAt: createdAt,
      counts: ArchiveCounts.fromJson((json['counts'] as Map?)?.cast<String, dynamic>() ?? const {}),
      tombstones: tombstones,
      floors: floors,
    );
  }
}
