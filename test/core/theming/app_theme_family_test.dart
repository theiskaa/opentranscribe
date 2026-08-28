import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/theming/app_theme_family.dart';

void main() {
  test('the free families come first and every club family is marked', () {
    final ids = AppThemeFamily.all.map((f) => f.id).toList();
    expect(ids.take(4), [
      AppThemeFamily.defaultId,
      AppThemeFamily.gruvboxId,
      AppThemeFamily.solarizedId,
      AppThemeFamily.sepiaId,
    ]);
    expect(AppThemeFamily.freeFamilies.any((f) => f.club), isFalse);
    expect(AppThemeFamily.clubFamilies.every((f) => f.club), isTrue);
    expect(AppThemeFamily.clubFamilies, isNotEmpty);
  });

  test('every club family ships a dark variant', () {
    expect(AppThemeFamily.clubFamilies.every((f) => f.hasDark), isTrue);
  });
}
