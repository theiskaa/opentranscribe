import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/utils/duo_layout.dart';
import 'package:opentranscribe/core/theming/duo_theme.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/models/pane_layout.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/view/widgets/pane_frame.dart';

bool duoInnerOf(BuildContext context) {
  final panes = PaneLayoutScope.maybeOf(context);
  return duoPolishEnabled(
    layout: panes?.layout,
    supported: panes?.supported ?? false,
    cover: panes?.cover ?? true,
    regular: panes?.regular ?? false,
    window: panes?.media.size ?? Size.zero,
  );
}

bool duoJournalOf(BuildContext context) =>
    duoInnerOf(context) && PaneScope.maybeOf(context)?.journalContent == true;

({double header, double detailTop}) duoHeaderOf(BuildContext context) {
  final scaler = MediaQuery.textScalerOf(context);
  final title = DuoTheme.journalTitle;
  final detail = DuoTheme.detailTitle;
  final journalMetrics = duoTextMetrics(style: AppType.digits(title), scaler: scaler);
  final detailMetrics = duoTextMetrics(style: detail, scaler: scaler);
  return duoHeaderMetrics(
    minimum: context.theme.topBar.largeHeight,
    titleLine: journalMetrics.height,
    titleSize: scaler.scale(title.fontSize!),
    subtitleLine: scaler.scale(AppType.rowNote.fontSize!) * AppType.rowNote.height!,
    detailLine: detailMetrics.height,
    titleBaseline: journalMetrics.baseline,
    detailBaseline: detailMetrics.baseline,
    detailSize: scaler.scale(detail.fontSize!),
  );
}

double duoHeadingTopOf(BuildContext context, TextStyle heading, {double offset = 0}) {
  final scaler = MediaQuery.textScalerOf(context);
  final navigation = duoTextMetrics(
    style: AppType.body.copyWith(fontWeight: FontWeight.w600),
    scaler: scaler,
  );
  return duoHeadingTop(
    navigationLine: navigation.height,
    navigationBaseline: navigation.baseline,
    headingBaseline: offset + duoTextMetrics(style: heading, scaler: scaler).baseline,
  );
}

double duoJournalTopInsetOf(BuildContext context) =>
    PaneLayoutScope.of(context).layout.mode == PaneMode.split
    ? duoHeadingTopOf(
        context,
        AppType.digits(DuoTheme.journalTitle),
        offset: duoReadingGridOf(context).journalTop,
      )
    : 0;

bool duoInnerNow(BuildContext context) {
  final panes = context.getInheritedWidgetOfExactType<PaneLayoutScope>()?.tracker;
  return duoPolishEnabled(
    layout: panes?.layout,
    supported: panes?.supported ?? false,
    cover: panes?.cover ?? true,
    regular: panes?.regular ?? false,
    window: panes?.media.size ?? Size.zero,
  );
}

DuoReadingGrid duoReadingGridOf(BuildContext context) {
  final scaler = MediaQuery.textScalerOf(context);
  final journal = duoTextMetrics(style: AppType.digits(DuoTheme.journalTitle), scaler: scaler);
  final detail = duoTextMetrics(style: DuoTheme.detailTitle, scaler: scaler);
  final meta = duoTextMetrics(style: AppType.digits(DuoTheme.metadata), scaler: scaler);
  return duoReadingGrid(
    journalLine: journal.height,
    journalBaseline: journal.baseline,
    detailBaseline: detail.baseline,
    metadataLine: meta.height,
    metadataBaseline: meta.baseline,
    playerHeight: duoPlayerHeight(
      duoTextMetrics(style: AppType.digits(DuoTheme.rowMetadata), scaler: scaler).height,
    ),
    dayHeight: duoDayHeight(
      letterLine:
          scaler.scale(AppType.caption.fontSize!) *
          AppType.lineHeightOf(AppType.caption, DefaultTextStyle.of(context).style),
      numberLine: scaler.scale(AppType.body.fontSize!) * AppType.body.height!,
    ),
  );
}
