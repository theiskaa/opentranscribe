import 'package:opentranscribe/core/export/journal_exporter.dart';
import 'package:opentranscribe/core/models/exporter_descriptor.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:reflections/reflections.dart';

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
  html: HtmlChromeStrings(
    // localeName joins subtags with underscores; the lang attribute wants
    // BCP-47 hyphens.
    languageTag: l10n.localeName.replaceAll('_', '-'),
    search: l10n.exportHtmlSearch,
    schemeLabel: l10n.exportHtmlSchemeLabel,
    schemeAuto: l10n.exportHtmlSchemeAuto,
    schemeLight: l10n.exportHtmlSchemeLight,
    schemeDark: l10n.exportHtmlSchemeDark,
    emptyTitle: l10n.exportHtmlEmptyTitle,
    emptyBody: l10n.exportHtmlEmptyBody,
    noMatchesTitle: l10n.exportHtmlNoMatchesTitle,
    noMatches: l10n.exportHtmlNoMatches(HtmlChromeStrings.termSlot),
    play: l10n.exportHtmlPlay,
    pause: l10n.exportHtmlPause,
    back: l10n.exportHtmlBack,
    speed: l10n.exportHtmlSpeed,
    seek: l10n.exportHtmlSeek,
  ),
);

/// How a format row reads: its name and the line under it saying what the
/// files actually are. Markdown and Obsidian are named by their makers and
/// stay verbatim in every locale; a format the app names itself is translated.
({String name, String note}) exportFormatCopy(
  AppLocalizations l10n,
  ExportFormat format,
) => switch (format) {
  ExportFormat.markdown => (name: l10n.exportFormatMarkdown, note: l10n.exportFormatMarkdownNote),
  ExportFormat.obsidian => (name: l10n.exportFormatObsidian, note: l10n.exportFormatObsidianNote),
  ExportFormat.web => (name: l10n.exportFormatWeb, note: l10n.exportFormatWebNote),
};
