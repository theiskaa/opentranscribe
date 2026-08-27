import 'package:opentranscribe/core/state/settings_cubit.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:transcriber/transcriber.dart';

/// The one wording for a language row's failure, shared by every surface that
/// shows one (the Models screen, the onboarding model step). Null when the row
/// carries no failure story.
String? modelFailureLine(AppLocalizations l10n, LanguageModelState row) {
  final failure = row.failure;
  if (failure == null) return null;
  return switch (failure.kind) {
    LanguageFailureKind.capReached => l10n.transcriptionErrorCap,
    LanguageFailureKind.removeFailed => l10n.transcriptionErrorRemove,
    LanguageFailureKind.installFailed => switch (failure.assetStatus) {
      ModelAssetStatus.unsupported => l10n.transcriptionErrorUnsupported,
      ModelAssetStatus.downloading => l10n.transcriptionErrorStuck,
      _ => l10n.transcriptionErrorGeneric,
    },
  };
}

/// The one wording for everything standing in a language's way: a standing
/// failure, an unready language (worded by whether the engine manages models,
/// or the system dictation setting is the recovery), or a system download
/// stuck from an earlier attempt. Null when nothing stands in the way.
String? modelTroubleLine(
  AppLocalizations l10n,
  LanguageModelState row, {
  required bool managesModels,
}) {
  final failure = modelFailureLine(l10n, row);
  if (failure != null) return failure;
  if (row.status == ModelAssetStatus.unsupported) {
    return managesModels ? l10n.transcriptionErrorUnsupported : l10n.languageNeedsDictation;
  }
  if (row.status == ModelAssetStatus.downloading && !row.installing) {
    return l10n.transcriptionErrorStuck;
  }
  return null;
}
