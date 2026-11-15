import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/theming/app_theme.dart';
import 'package:opentranscribe/core/theming/duo_theme.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/view/widgets/settings_kit.dart';

void main() {
  final tokens = AppTheme.defaultLight.settings;
  final ambient = AppType.body.height;

  group('selectableRowHeight (what a dropdown places its popup by)', () {
    test(
      'a flagged row is its tile plus the row padding, the tile being taller than the label',
      () {
        final height = selectableRowHeight(
          tokens,
          scaler: TextScaler.noScaling,
          ambientHeight: ambient,
          tile: true,
        );
        expect(height, tokens.iconTileSize + tokens.rowPadding.vertical);
      },
    );

    test('a plain row is its label line plus the row padding, not a tile it does not draw', () {
      final height = selectableRowHeight(
        tokens,
        scaler: TextScaler.noScaling,
        ambientHeight: ambient,
        tile: false,
      );
      expect(height, closeTo(15 * 1.45 + tokens.rowPadding.vertical, 1e-9));
    });

    test('larger text grows the label past the tile, and the row with it', () {
      final height = selectableRowHeight(
        tokens,
        scaler: const TextScaler.linear(2),
        ambientHeight: ambient,
        tile: true,
      );
      expect(height, closeTo(30 * 1.45 + tokens.rowPadding.vertical, 1e-9));
    });
  });

  test('a row hairline starts under the label, past the padding, the tile and its gap', () {
    expect(tokens.dividerInset, 60);
  });
  test('Duo dropdown placement uses the actual inner display tile size', () {
    expect(
      selectableRowHeight(
        tokens,
        scaler: TextScaler.noScaling,
        ambientHeight: ambient,
        tile: true,
        inner: true,
      ),
      DuoTheme.groupIcon + tokens.rowPadding.vertical,
    );
  });
}
