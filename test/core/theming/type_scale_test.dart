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
}
