import 'package:flutter/foundation.dart';

import 'package:opentranscribe/core/state/backup_cubit.dart';
import 'package:opentranscribe/view/widgets/settings_kit.dart';

/// A line and the ink it is told in.
typedef ToneLine = ({String text, NoteTone tone});

/// The outcome of the last finished backup or export, told where it
/// happened: a backup's in the top card's line, an export's in its row. A
/// restore tells its own through [BackupState.restore]. One at a time; the
/// next action clears it. A share's note is made only by
/// [archiveNoteOf] and [exportNoteOf], so it never holds a cancel.
@immutable
sealed class BackupNote {
  const BackupNote();
}

final class BackupArchiveNote extends BackupNote {
  const BackupArchiveNote._(this.result, {required this.sealed});

  /// Shared or one of the failures; never cancelled.
  final BackupActionResult result;

  /// Whether the backup this tells of was encrypted.
  final bool sealed;

  @override
  bool operator ==(Object other) =>
      other is BackupArchiveNote && other.result == result && other.sealed == sealed;

  @override
  int get hashCode => Object.hash(result, sealed);
}

final class BackupExportNote extends BackupNote {
  const BackupExportNote._(this.exporterId, this.result);

  final String exporterId;

  /// Shared or one of the failures; never cancelled.
  final BackupActionResult result;

  @override
  bool operator ==(Object other) =>
      other is BackupExportNote && other.exporterId == exporterId && other.result == result;

  @override
  int get hashCode => Object.hash(exporterId, result);
}

/// The note a finished backup leaves, or none for a cancel, which is the
/// user's own doing and needs no telling.
BackupNote? archiveNoteOf(BackupActionResult result, {required bool sealed}) =>
    result == BackupActionResult.cancelled ? null : BackupArchiveNote._(result, sealed: sealed);

/// The note a finished export leaves on its row, or none for a cancel.
BackupNote? exportNoteOf(String exporterId, BackupActionResult result) =>
    result == BackupActionResult.cancelled ? null : BackupExportNote._(exporterId, result);

/// The note left once encryption is flipped: the card's own outcome goes,
/// since it told of a backup under the old choice; an export's stays on its
/// row.
BackupNote? noteAfterSealFlip(BackupNote? note) => note is BackupExportNote ? note : null;

/// What a press on one of the card's two capsules does.
enum CardAction {
  none,
  startBackup,
  askPassphrase,
  submitBackup,
  closeAsk,
  pickRestore,
  unlockRestore,
  adoptRestore,
  dismissRestore,
}

/// A capsule's decision: what it stands for, and whether a press does it
/// now. A capsule that is not live shows its action disabled. A leading
/// capsule standing for [CardAction.none] is a bar that only reports; a
/// trailing one has its seat closed.
typedef Capsule = ({CardAction action, bool live});

const Capsule _inert = (action: CardAction.none, live: false);

/// The leading capsule, the card's forward action, so the capsule pressed is
/// the one that becomes the bar. At rest it backs up: disabled while a share
/// runs or the journal is empty, a submit once the passphrase fields hold an
/// acceptable pair, and with encryption on it asks first. Through a restore
/// it is the next step: unlock once something is typed, adopt a plan or
/// resume a partial one, and the way out beside a plan with nothing in it.
/// A bar while a backup or a restore step runs; Back up, disabled, while the
/// picker is up.
Capsule leadingCapsule(
  BackupState state, {
  required bool asking,
  required bool passphraseReady,
  required bool unlockReady,
}) {
  switch (state.restore) {
    case RestorePicking():
      return (action: CardAction.startBackup, live: false);
    case RestoreChecking() || RestoreRunning():
      return _inert;
    case RestoreProbed():
      return (action: CardAction.unlockRestore, live: unlockReady);
    case RestorePlanned(:final plan) when plan.isEmpty:
      return (action: CardAction.dismissRestore, live: true);
    case RestorePlanned() || RestorePartial():
      return (action: CardAction.adoptRestore, live: true);
    case RestoreIdle() || RestoreDone() || RestoreFailed():
      if (state.busy == BackupBusy.archiving) return _inert;
      final idle = !state.isBusy && state.measure?.entries != 0;
      if (asking) return (action: CardAction.submitBackup, live: idle && passphraseReady);
      return (action: state.seal ? CardAction.askPassphrase : CardAction.startBackup, live: idle);
  }
}

/// The trailing capsule, the way out of whatever the leading one carries
/// forward: it closes a backup's passphrase ask and lets go of a restore
/// waiting on the user, and at rest picks a file to restore (disabled while a
/// share runs, and while the picker it opened is up).
Capsule trailingCapsule(BackupState state, {required bool asking}) {
  if (asking) return (action: CardAction.closeAsk, live: true);
  return switch (state.restore) {
    RestorePicking() => (action: CardAction.pickRestore, live: false),
    RestoreChecking() || RestoreRunning() => _inert,
    RestoreProbed() ||
    RestorePlanned() ||
    RestorePartial() => (action: CardAction.dismissRestore, live: true),
    RestoreIdle() ||
    RestoreDone() ||
    RestoreFailed() => (action: CardAction.pickRestore, live: !state.isBusy),
  };
}

/// Which of the screen's controls besides the two capsules take input.
typedef BackupLive = ({bool seal, bool includeAudio, bool formats});

/// [BackupLive] for the screen as it stands. While any operation runs or a
/// restore is under way none takes input, so a tap never buzzes for nothing;
/// the running control reports and offers only its cancel. At rest,
/// exporting needs entries and the audio switch needs recordings; an
/// unmeasured journal counts as having both, so nothing flashes disabled
/// while it is measured.
BackupLive backupLive(BackupState state) {
  final idle = !state.isBusy && !state.restore.underWay;
  return (
    seal: idle,
    includeAudio: idle && _hasRecordings(state),
    formats: idle && (state.measure?.entries ?? 1) > 0,
  );
}

/// Whether an export carries the audio, which is what the switch shows: the
/// user's [choice] once made, else on wherever there is audio to carry. An
/// unmeasured journal reads as having audio, because a silent all-audio
/// omission is the worse wrong default; a journal without recordings never
/// carries any.
bool includeAudioOf(BackupState state, bool? choice) => _hasRecordings(state) && (choice ?? true);

bool _hasRecordings(BackupState state) => (state.measure?.recordings ?? 1) > 0;
