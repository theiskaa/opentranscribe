import 'package:opentranscribe/core/state/settings_cubit.dart';
import 'package:opentranscribe/core/transcribe/transcription_engine.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';

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
