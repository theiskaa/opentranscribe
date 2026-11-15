import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/view/widgets/app_menu.dart';

void main() {
  const row = AppMenuItem(label: 'Row');
  const divider = AppMenuItem.divider();
  const padding = AppSpacing.sm * 2;

  test('a menu without dividers is its rows and its padding', () {
    final layout = appMenuLayout(const [row, row, row]);
    expect(layout.dividers, isEmpty);
    expect(layout.height, 3 * AppSizes.minTarget + padding);
  });

  test('a divider between two groups draws and adds its band', () {
    final layout = appMenuLayout(const [row, row, divider, row]);
    expect(layout.dividers, {2});
    expect(layout.height, 3 * AppSizes.minTarget + AppSpacing.sm + padding);
  });

  test('a leading or trailing divider has no group on one side and draws nothing', () {
    final layout = appMenuLayout(const [divider, row, row, divider]);
    expect(layout.dividers, isEmpty);
    expect(layout.height, 2 * AppSizes.minTarget + padding);
  });

  test('doubled dividers between two groups draw once, at the first', () {
    final layout = appMenuLayout(const [row, divider, divider, row]);
    expect(layout.dividers, {1});
    expect(layout.height, 2 * AppSizes.minTarget + AppSpacing.sm + padding);
  });

  test('every boundary between groups draws its own divider', () {
    expect(appMenuLayout(const [row, divider, row, divider, row]).dividers, {1, 3});
  });
}
