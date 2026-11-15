import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/models_cubit.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/formatting.dart';
import 'package:opentranscribe/view/widgets/morph_control.dart';
import 'package:transcriber/transcriber.dart';

/// What a model's control means, folded in priority: a download in flight,
/// then a failure, then too heavy while absent, then present or not.
enum ModelRowFace { installing, failed, heavy, download, selected, installed }

ModelRowFace modelRowFace(ModelRowState row) {
  if (row.installing) return ModelRowFace.installing;
  if (row.failure != null) return ModelRowFace.failed;
  if (!row.installed) return row.heavy ? ModelRowFace.heavy : ModelRowFace.download;
  return row.selected ? ModelRowFace.selected : ModelRowFace.installed;
}

/// Whether a model offers its trash: never on the model in use (emptying the
/// seat runs start from is a trap), unless it would not open, when removing
/// it is the way out.
bool modelRowRemovable(ModelRowState row) => switch (modelRowFace(row)) {
  ModelRowFace.installed => true,
  ModelRowFace.failed => row.installed && row.failure == ModelInstallReason.loadFailed,
  _ => false,
};

/// What the bar reads while a download runs: how full it is, and the word in
/// it. The fill follows the shown percent rather than the raw fraction, so a
/// bar and its number never disagree.
MorphBar progressFace(
  AppLocalizations l10n, {
  required bool queued,
  required bool preparing,
  required double? fraction,
  required String localeTag,
}) {
  if (queued) return MorphBar(fill: 0, label: l10n.modelQueued);
  if (preparing) return MorphBar(fill: 1, label: l10n.modelPreparing);
  return MorphBar(fill: shownFraction(fraction), label: formatPercent(fraction, localeTag));
}

/// The [MorphControl] face for a model's fetch, in [modelRowFace]'s priority:
/// the bar while it downloads, Retry after a failure, else Download.
/// [downloadLabel] is the download's words, its size folded in where the
/// caller has room for it.
MorphFace modelControlFace(
  AppLocalizations l10n,
  ModelRowState row, {
  required String localeTag,
  String? downloadLabel,
}) {
  // One bar across the whole download, so its sweep runs from the queue
  // through the percent into the preparing tail.
  if (row.installing) {
    return progressFace(
      l10n,
      queued: row.queued,
      preparing: row.preparing,
      fraction: row.installFraction,
      localeTag: localeTag,
    );
  }
  if (row.failure != null) {
    return MorphButton(label: l10n.retry, icon: AppIcons.arrowCounterclockwise);
  }
  return MorphButton(label: downloadLabel ?? l10n.modelDownload, icon: AppIcons.icloud);
}

/// What VoiceOver calls the control, in the same priority as
/// [modelControlFace]: the download's state and percent, the retry, or the
/// download button's own words when the caller gave them.
String modelControlSemanticLabel(
  AppLocalizations l10n,
  ModelRowState row, {
  String? downloadLabel,
}) {
  final name = row.option.displayName;
  if (row.installing) {
    if (row.queued) return l10n.modelQueuedLabel(name);
    if (row.preparing) return l10n.modelPreparingLabel(name);
    return l10n.modelDownloadingLabel(name, percentOf(row.installFraction));
  }
  if (row.failure != null) return l10n.modelRetryButton(name);
  return downloadLabel ?? l10n.modelDownloadButton(name);
}

/// Whether a download can still be stopped: not once it is unpacking what it
/// fetched.
bool modelControlCancellable(ModelRowState row) => row.cancellable && !row.preparing;

/// A model's control: the [MorphControl] for its row, a button while it asks
/// (Download, Retry) and a slim progress bar while a download runs.
class ModelControl extends StatelessWidget {
  const ModelControl({
    required this.row,
    required this.onPressed,
    required this.onCancel,
    this.downloadLabel,
    super.key,
  });

  final ModelRowState row;

  /// What a tap does, or null for a face that only reports.
  final VoidCallback? onPressed;
  final VoidCallback onCancel;

  /// The download face's words, when the caller has room for more than one.
  final String? downloadLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return MorphControl(
      face: modelControlFace(
        l10n,
        row,
        localeTag: localeTag(context),
        downloadLabel: downloadLabel,
      ),
      semanticLabel: modelControlSemanticLabel(l10n, row, downloadLabel: downloadLabel),
      onPressed: onPressed,
      cancellable: modelControlCancellable(row),
      onCancel: onCancel,
      cancelSemanticLabel: l10n.modelCancelDownloadButton(row.option.displayName),
    );
  }
}
