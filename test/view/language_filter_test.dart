import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/state/settings_cubit.dart';
import 'package:opentranscribe/view/layouts/settings/components/language_filter.dart';
import 'package:transcriber/transcriber.dart';

void main() {
  LanguageModelState row(String tag) => LanguageModelState(
    tag: tag,
    status: ModelAssetStatus.supported,
    reserved: true,
    isDefault: false,
  );

  final rows = [row('en-US'), row('de-DE'), row('fr-FR'), row('pt-BR'), row('vi-VN')];

  test('an empty query keeps every row', () {
    expect(filterLanguageRows('', rows), rows);
    expect(filterLanguageRows('   ', rows), rows);
  });

  test('matches the display name case-insensitively', () {
    expect(filterLanguageRows('deutsch', rows).map((r) => r.tag), ['de-DE']);
  });

  test('matches without the accents the name carries', () {
    expect(filterLanguageRows('francais', rows).map((r) => r.tag), ['fr-FR']);
  });

  test('matches the tag itself', () {
    expect(filterLanguageRows('pt-br', rows).map((r) => r.tag), ['pt-BR']);
  });

  test('a partial needle keeps every language it appears in', () {
    expect(filterLanguageRows('deut', rows).map((r) => r.tag), ['de-DE']);
    expect(filterLanguageRows('e', rows).map((r) => r.tag), ['en-US', 'de-DE', 'pt-BR', 'vi-VN']);
  });

  test('an accented query matches the same as its plain spelling', () {
    expect(filterLanguageRows('français', rows).map((r) => r.tag), ['fr-FR']);
  });

  test('folds the accents vietnamese carries', () {
    expect(filterLanguageRows('tieng', rows).map((r) => r.tag), ['vi-VN']);
  });

  test('nothing matching answers an empty list', () {
    expect(filterLanguageRows('klingon', rows), isEmpty);
  });
}
