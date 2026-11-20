import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/core/models/pane_layout.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/component_themes.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/utils/duo_layout.dart';
import 'package:opentranscribe/view/widgets/app_top_bar.dart';

void main() {
  const bar = TopBarTheme(
    background: Color(0x00000000),
    titleColor: Color(0x00000000),
    iconColor: Color(0x00000000),
  );

  test('the phone title row keeps its original height at default text size', () {
    expect(
      phoneLargeTitleHeight(minimum: bar.largeHeight, scaler: TextScaler.noScaling),
      bar.largeHeight,
    );
  });

  test('the phone title row fits both lines and their padding at the largest iOS text size', () {
    const scaler = TextScaler.linear(53 / 17);
    final height = phoneLargeTitleHeight(minimum: bar.largeHeight, scaler: scaler);
    expect(height, greaterThan(bar.largeHeight));
    expect(
      height,
      AppSpacing.md +
          duoTextMetrics(style: AppType.digits(AppType.display2), scaler: scaler).height +
          AppSpacing.xxs +
          duoTextMetrics(style: AppType.digits(AppType.footnote), scaler: scaler).height,
    );
  });

  test('an opened record has a split back button because it replaces the journal', () {
    expect(
      panePageShowsBack(
        mode: PaneMode.split,
        journalSelection: true,
        detailRoot: true,
        canPop: true,
      ),
      isTrue,
    );
  });

  test('a sidebar destination has no redundant split back button', () {
    expect(
      panePageShowsBack(
        mode: PaneMode.split,
        journalSelection: false,
        detailRoot: true,
        canPop: true,
      ),
      isFalse,
    );
  });

  test('a page pushed above a selected entry shows back in the detail pane', () {
    expect(panePageShowsBack(mode: PaneMode.split, journalSelection: false, canPop: true), isTrue);
  });

  test('a phone and cover keep back for journal selections and menu pages', () {
    for (final mode in [null, PaneMode.single]) {
      for (final selected in [false, true]) {
        for (final root in [false, true]) {
          expect(
            panePageShowsBack(
              mode: mode,
              journalSelection: selected,
              detailRoot: root,
              canPop: true,
            ),
            isTrue,
          );
        }
      }
    }
  });

  test('a route with nothing to return to never grows an automatic back button', () {
    for (final mode in [null, ...PaneMode.values]) {
      for (final selected in [false, true]) {
        expect(panePageShowsBack(mode: mode, journalSelection: selected, canPop: false), isFalse);
      }
    }
  });
}
