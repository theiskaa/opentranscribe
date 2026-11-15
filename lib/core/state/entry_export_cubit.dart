import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/export/journal_exporter.dart';
import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/models/exporter_descriptor.dart';
import 'package:opentranscribe/core/services/export_service.dart';
import 'package:opentranscribe/core/state/backup_cubit.dart';

/// What the entry screen's bar says about an export: nothing, that the files
/// are being prepared, or that the last one failed.
enum EntryExportLine { none, preparing, failed }

@immutable
final class EntryExportState {
  const EntryExportState({
    this.includeAudio = true,
    this.running = false,
    this.preparing = false,
    this.failure,
  });

  /// The menu's Include audio check. On by default and held for the screen's
  /// visit; honored only while the entry has a recording.
  final bool includeAudio;

  /// An export is under way, from the tap until the share sheet closes.
  final bool running;

  /// The files are still being built past the grace: long enough to say so.
  final bool preparing;

  /// How the last export failed; null when it did not, and once it is let go.
  /// Only the failed outcomes land here: a cancel says nothing.
  final BackupActionResult? failure;

  EntryExportState copyWith({
    bool? includeAudio,
    bool? running,
    bool? preparing,
    BackupActionResult? Function()? failure,
  }) => EntryExportState(
    includeAudio: includeAudio ?? this.includeAudio,
    running: running ?? this.running,
    preparing: preparing ?? this.preparing,
    failure: failure == null ? this.failure : failure(),
  );

  @override
  bool operator ==(Object other) =>
      other is EntryExportState &&
      other.includeAudio == includeAudio &&
      other.running == running &&
      other.preparing == preparing &&
      other.failure == failure;

  @override
  int get hashCode => Object.hash(includeAudio, running, preparing, failure);
}

/// The bar's line for [state]: a failure outranks the wait, so a run that
/// failed never reads as still preparing.
EntryExportLine entryExportLineOf(EntryExportState state) {
  if (state.failure != null) return EntryExportLine.failed;
  if (state.running && state.preparing) return EntryExportLine.preparing;
  return EntryExportLine.none;
}

/// Exports one entry from its screen's menu, one run at a time, straight to
/// the share sheet. Holds the Include audio check for the visit and the last
/// failure until the screen lets it go. Never rethrows: every escape is read
/// by [shareFailureResult], so a share that never presented stays quiet.
class EntryExportCubit extends Cubit<EntryExportState> {
  EntryExportCubit({
    required this._export,
    required this._descriptors,
    this._preparingGrace = const Duration(milliseconds: 600),
  }) : super(const EntryExportState());

  final ExportService _export;
  final List<ExporterDescriptor> _descriptors;

  /// How long the pack must run before the bar says so: an entry that packs
  /// in a blink never flashes a line nobody could read.
  final Duration _preparingGrace;
  Timer? _grace;

  /// The formats this build ships, in the order the menu lists them.
  List<ExporterDescriptor> get descriptors => _descriptors;

  /// Flips the live check, not a menu's snapshot: a held-open native menu
  /// can fire twice inside one rebuild.
  void toggleAudio() => emit(state.copyWith(includeAudio: !state.includeAudio));

  void dismissFailure() {
    if (state.failure != null) emit(state.copyWith(failure: () => null));
  }

  /// Packs [entry] in [exporterId]'s format and hands it to the share sheet.
  /// A second tap while one runs is a quiet cancel.
  Future<BackupActionResult> export(
    Entry entry, {
    required String exporterId,
    required ExportStrings strings,
  }) async {
    if (state.running) return BackupActionResult.cancelled;
    emit(state.copyWith(running: true, preparing: false, failure: () => null));
    _grace?.cancel();
    _grace = Timer(_preparingGrace, () {
      if (!isClosed && state.running) emit(state.copyWith(preparing: true));
    });
    BackupActionResult result;
    try {
      final shared = await _export.shareEntry(
        entry.id,
        exporterId: exporterId,
        includeAudio: state.includeAudio && entry.hasAudio,
        strings: strings,
        onSharing: _onSharing,
      );
      result = shared ? BackupActionResult.shared : BackupActionResult.cancelled;
    } catch (e) {
      result = shareFailureResult(e);
      if (kDebugMode && result != BackupActionResult.cancelled) {
        debugPrint('EntryExportCubit.export failed: $e');
      }
    }
    _grace?.cancel();
    if (!isClosed) {
      final failed = result != BackupActionResult.shared && result != BackupActionResult.cancelled;
      emit(state.copyWith(running: false, preparing: false, failure: () => failed ? result : null));
    }
    return result;
  }

  void _onSharing() {
    _grace?.cancel();
    if (!isClosed && state.preparing) emit(state.copyWith(preparing: false));
  }

  @override
  Future<void> close() {
    _grace?.cancel();
    return super.close();
  }
}
