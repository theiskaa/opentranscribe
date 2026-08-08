import 'package:opentranscribe/core/export/journal_exporter.dart';
import 'package:opentranscribe/core/models/exporter_descriptor.dart';
import 'package:opentranscribe/core/reflect/reflection_period.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';

/// A format row's label: the product name when the format has one, the
/// localized plain-text label when it does not.
String exporterDisplayName(ExporterDescriptor descriptor, AppLocalizations l10n) =>
    descriptor.displayName ?? l10n.exportFormatPlain;

/// The one mapping from [AppLocalizations] to the exporter contract's
/// strings, so every export surface hands the same words to core and the
/// exporters themselves never touch l10n.
ExportStrings exportStringsOf(AppLocalizations l10n) => ExportStrings(
  untitledEntry: l10n.exportUntitled,
  transcriptHeading: l10n.exportTranscriptHeading,
  quietReflection: l10n.exportQuiet,
  recordedLabel: l10n.exportRecorded,
  durationLabel: l10n.exportDuration,
  languageLabel: l10n.exportLanguage,
  audioLabel: l10n.exportAudio,
  periodLabels: {
    ReflectionPeriod.daily: l10n.reflectionDaily,
    ReflectionPeriod.weekly: l10n.reflectionWeekly,
    ReflectionPeriod.monthly: l10n.reflectionMonthly,
  },
);
