import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/reflect/reflection_options.dart';
import 'package:opentranscribe/view/layouts/reflections/components/reflection_settings_menu.dart';
import 'package:opentranscribe/view/widgets/app_menu.dart';

/// The nested menu's structure (ids + selected flags) is pure and testable; the
/// AppMenuButton it feeds is not pumped.
const ReflectionMenuLabels _labels = (
  reflections: 'Weekly reflections',
  voice: 'Voice',
  length: 'Length',
  specifics: 'Specifics',
  literary: 'Literary',
  observational: 'Observational',
  sparse: 'Sparse',
  oneLine: 'One line',
  sentences: 'A few sentences',
  paragraph: 'Short paragraph',
  nameFreely: 'Name specifics',
  themesOnly: 'Themes only',
  letWeekDecide: 'Let the week decide',
);

void main() {
  test('the toggle row reflects enabled and carries the toggle id', () {
    final on = reflectionMenuItems(enabled: true, style: ReflectionStyle.defaults, labels: _labels);
    expect(on.first.id, 'r:toggle');
    expect(on.first.selected, isTrue);

    final off = reflectionMenuItems(
      enabled: false,
      style: ReflectionStyle.defaults,
      labels: _labels,
    );
    expect(off.first.selected, isFalse);
  });

  test('the current voice, length, and specificity children are marked selected', () {
    final items = reflectionMenuItems(
      enabled: true,
      style: const ReflectionStyle(
        voice: ReflectionVoice.sparse,
        length: ReflectionLength.oneLine,
        specificity: ReflectionSpecificity.abstractThemes,
      ),
      labels: _labels,
    );

    AppMenuItem parent(String id) => items.firstWhere((i) => i.id == id);
    expect(parent('r:voice').children.singleWhere((c) => c.selected).id, 'r:voice:sparse');
    expect(parent('r:length').children.singleWhere((c) => c.selected).id, 'r:length:one_line');
    expect(parent('r:spec').children.singleWhere((c) => c.selected).id, 'r:spec:abstract');
  });

  test('every submenu child carries a stable id (the native submenu needs it)', () {
    final items = reflectionMenuItems(
      enabled: true,
      style: ReflectionStyle.defaults,
      labels: _labels,
    );
    for (final parent in items.where((i) => i.children.isNotEmpty)) {
      for (final child in parent.children) {
        expect(child.id, isNotNull);
      }
    }
  });
}
