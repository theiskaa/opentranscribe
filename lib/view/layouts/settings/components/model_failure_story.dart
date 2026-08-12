import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/settings_cubit.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:transcriber/transcriber.dart';

/// The failure cases the model-failure sheet words, folded from a row's
/// failure kind and the asset's pre-install status. One surface, one honest
/// story per case.
enum ModelFailureCase { cap, unsupported, stuck, removeFailed, generic }

/// The story [row] tells. Pure, so the fold is testable off the widget.
ModelFailureCase modelFailureCase(LanguageModelState row) {
  final failure = row.failure;
  if (failure != null) {
    return switch (failure.kind) {
      LanguageFailureKind.capReached => ModelFailureCase.cap,
      LanguageFailureKind.removeFailed => ModelFailureCase.removeFailed,
      LanguageFailureKind.installFailed => switch (failure.assetStatus) {
        ModelAssetStatus.unsupported => ModelFailureCase.unsupported,
        ModelAssetStatus.downloading => ModelFailureCase.stuck,
        _ => ModelFailureCase.generic,
      },
    };
  }
  if (row.status == ModelAssetStatus.unsupported) return ModelFailureCase.unsupported;
  return ModelFailureCase.stuck;
}

/// Whether [row] carries a story the sheet can tell: a standing failure, an
/// unsupported language, or a system download stuck from an earlier attempt.
bool rowHasFailureStory(LanguageModelState row) =>
    row.failure != null ||
    row.status == ModelAssetStatus.unsupported ||
    (row.status == ModelAssetStatus.downloading && !row.installing);

/// The words each case wears: its icon, the sheet's title, and the body,
/// beside the fold so a case and its wording stay one surface.
(IconData, String, String) modelFailureStory(
  AppLocalizations l10n,
  ModelFailureCase kind,
  String language,
) => switch (kind) {
  ModelFailureCase.cap => (AppIcons.globe, l10n.modelFailCapTitle, l10n.modelFailCapBody(language)),
  ModelFailureCase.unsupported => (
    AppIcons.globe,
    l10n.modelFailUnsupportedTitle,
    l10n.modelFailUnsupportedBody(language),
  ),
  ModelFailureCase.stuck => (
    AppIcons.icloud,
    l10n.modelFailStuckTitle,
    l10n.modelFailStuckBody(language),
  ),
  ModelFailureCase.removeFailed => (
    AppIcons.trash,
    l10n.modelFailRemoveTitle,
    l10n.modelFailRemoveBody(language),
  ),
  ModelFailureCase.generic => (
    AppIcons.icloud,
    l10n.modelFailGenericTitle,
    l10n.modelFailGenericBody(language),
  ),
};
