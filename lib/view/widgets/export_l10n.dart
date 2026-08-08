import 'package:opentranscribe/core/export/journal_exporter.dart';
import 'package:opentranscribe/core/reflect/reflection_period.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';

/// The one mapping from [AppLocalizations] to the exporter contract's
/// strings, so every export surface hands the same words to core and the
/// exporters themselves never touch l10n.
ExportStrings exportStringsOf(AppLocalizations l10n) => ExportStrings(
  untitledEntry: l10n.exportUntitled,
  transcriptHeading: l10n.exportTranscriptHeading,
  quietReflection: l10n.exportQuiet,
  periodLabels: {
    ReflectionPeriod.daily: l10n.reflectionDaily,
    ReflectionPeriod.weekly: l10n.reflectionWeekly,
    ReflectionPeriod.monthly: l10n.reflectionMonthly,
  },
);
