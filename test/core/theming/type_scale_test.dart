import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';

void main() {
  group('AppType.boldAware', () {
    test('under Bold Text a style is set bold, the rest of it kept', () {
      final bold = AppType.boldAware(AppType.body, bold: true);
      expect(bold.fontWeight, FontWeight.bold);
      expect(bold.fontSize, AppType.body.fontSize);
      expect(bold.height, AppType.body.height);
    });

    test('without Bold Text a style is left as it is', () {
      expect(AppType.boldAware(AppType.body, bold: false), same(AppType.body));
    });
  });

  test(
    'every style splits extra line height evenly, so text centres like the glyphs beside it',
    () {
      const styles = [
        AppType.display,
        AppType.display2,
        AppType.title,
        AppType.headline,
        AppType.body,
        AppType.callout,
        AppType.subhead,
        AppType.subheadParagraph,
        AppType.footnote,
        AppType.note,
        AppType.rowNote,
        AppType.caption,
        AppType.eyebrow,
        AppType.timer,
      ];
      for (final style in styles) {
        expect(style.leadingDistribution, TextLeadingDistribution.even);
      }
    },
  );
}
