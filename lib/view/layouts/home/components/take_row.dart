import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/models/take_forecast.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/layouts/home/components/entry_row.dart';
import 'package:opentranscribe/view/widgets/formatting.dart';
import 'package:opentranscribe/view/widgets/ink_forecast.dart';
import 'package:opentranscribe/view/widgets/ink_reveal.dart';
import 'package:opentranscribe/view/widgets/invisible_ink.dart';

/// The rows of a waiting take's cloud, in the shape of the row it becomes
/// ([EntryRowBody] without a title): about [characters] of [sample]'s words
/// set as its excerpt at [width], at most [excerptLines] and ellipsized as the
/// excerpt is, then [meta] as its time line(s) after the row's gap, in
/// [bold] and [locale] as the row's text will be. A right forecast lands with
/// no change in height.
List<InkRow> takeCloudRows({
  required int characters,
  required String sample,
  required String meta,
  required double width,
  required TextScaler scaler,
  required int excerptLines,
  required bool bold,
  required Locale? locale,
}) {
  final bodySize = scaler.scale(EntryRowBody.excerptStyle.fontSize!);
  final excerpt = TextPainter(
    text: TextSpan(
      text: forecastFiller(
        sample: sample,
        characters: characters,
        width: width,
        fontSize: bodySize,
        lines: excerptLines,
      ),
      style: AppType.boldAware(EntryRowBody.excerptStyle, bold: bold),
    ),
    textDirection: TextDirection.ltr,
    textScaler: scaler,
    maxLines: excerptLines,
    ellipsis: '…',
    locale: locale,
  )..layout(maxWidth: width);
  // Unbounded like the row's own time line, which wraps at large text sizes.
  final time = TextPainter(
    text: TextSpan(
      text: meta,
      style: AppType.boldAware(EntryRowBody.metaStyle, bold: bold),
    ),
    textDirection: TextDirection.ltr,
    textScaler: scaler,
    locale: locale,
  )..layout(maxWidth: width);
  final rows = <InkRow>[];
  var top = 0.0;
  for (final line in excerpt.computeLineMetrics()) {
    rows.add((top: top, fontSize: bodySize, lineHeight: line.height, measure: line.width));
    top += line.height;
  }
  top = excerpt.height + EntryRowBody.metaGap;
  final timeSize = scaler.scale(EntryRowBody.metaStyle.fontSize!);
  for (final line in time.computeLineMetrics()) {
    rows.add((top: top, fontSize: timeSize, lineHeight: line.height, measure: line.width));
    top += line.height;
  }
  excerpt.dispose();
  time.dispose();
  return rows;
}

/// The take's place in the list while it is being transcribed: a record's rail
/// and node with a cloud of ink where its words will be. The cloud is not a
/// stand-in that gets swapped out; when the record lands it resolves INTO the
/// row, so the wait and the arrival are one movement.
///
/// [entry] is null until the record lands. The row is not tappable either way:
/// while the cloud is up there is nothing to open, and a tap landing mid-write
/// on a row that is still assembling would open a screen the reader did not
/// aim at. The settled row takes over from [EntryRow] on [onWritten].
class TakeRow extends StatelessWidget {
  const TakeRow({
    required this.entry,
    required this.forecast,
    required this.sample,
    required this.last,
    required this.onWritten,
    super.key,
  });

  final Entry? entry;

  /// What the take is expected to read as; the cloud takes its shape. Every
  /// fresh take's pass carries one; null holds a few lines, defensively.
  final TakeForecast? forecast;

  /// Words in the take's language to lay the forecast out in ([fillerSample]).
  final String sample;

  /// The day's last living record; see [EntryRow.last].
  final bool last;

  /// The words are written and the row renders plain: the list can take it
  /// back as an ordinary record.
  final VoidCallback onWritten;

  /// How tall the waiting cloud stands without a forecast, in body lines: a
  /// short record's excerpt and the meta line under it.
  static const int _placeholderLines = 3;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final entry = this.entry;
    final forecast = this.forecast;
    final excerptLines = theme.entryList.excerptLines;
    final tag = localeTag(context);
    final bold = MediaQuery.boldTextOf(context);
    final locale = Localizations.maybeLocaleOf(context);
    return EntryRail(
      last: last,
      leadStyle: entry == null ? AppType.body : EntryRowBody.leadStyleOf(entry),
      child: Semantics(
        // The cloud says nothing on its own; the settled row reads itself out.
        label: entry == null ? l10n.takeTranscribing : null,
        child: InkReveal(
          phase: entry == null ? InkPhase.pending : InkPhase.write,
          color: theme.entryList.excerptColor,
          background: theme.screens.home,
          placeholderLines: _placeholderLines,
          placeholderRows: forecast == null
              ? null
              : (width, scaler) => takeCloudRows(
                  characters: forecast.characters,
                  sample: sample,
                  // The record's own time is stamped when it lands; tabular
                  // digits make this minute's as wide.
                  meta: EntryRowBody.metaLine(DateTime.now(), forecast.audio, tag),
                  width: width,
                  scaler: scaler,
                  excerptLines: excerptLines,
                  bold: bold,
                  locale: locale,
                ),
          onWriteFinished: onWritten,
          child: entry == null
              ? const SizedBox(width: double.infinity)
              : EntryRowBody(entry: entry),
        ),
      ),
    );
  }
}
