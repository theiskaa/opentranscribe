import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/theming/app_theme_family.dart';

void main() {
  test('default leads and is the only free family', () {
    expect(AppThemeFamily.all.first.id, AppThemeFamily.defaultId);
    expect(AppThemeFamily.all.where((f) => !f.club).map((f) => f.id), [AppThemeFamily.defaultId]);
  });

  test('eight families ship', () {
    expect(AppThemeFamily.all, hasLength(8));
  });

  test('every family ships a dark variant', () {
    expect(AppThemeFamily.all.every((f) => f.hasDark), isTrue);
  });
}
