import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/reflect/reflection_options.dart';
import 'package:opentranscribe/view/layouts/reflections/components/reflections_menu.dart';
import 'package:opentranscribe/view/widgets/app_menu.dart';

const ReflectionMenuLabels _labels = (
  reflections: 'Reflections',
  regenerate: 'Regenerate',
  delete: 'Delete',
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

List<AppMenuItem> build({
  bool enabled = true,
  bool canRegenerate = true,
  bool canDelete = true,
  bool showSettings = true,
}) => reflectionsMenuItems(
  enabled: enabled,
  style: ReflectionStyle.defaults,
  labels: _labels,
  canRegenerate: canRegenerate,
  canDelete: canDelete,
  showSettings: showSettings,
);

Iterable<String?> idsOf(List<AppMenuItem> items) =>
    items.where((i) => !i.isDivider).map((i) => i.id);

void main() {
  test('the base order: toggle, then the knobs, then the viewed week\'s actions, '
      'with delete the only destructive one', () {
    expect(idsOf(build()), ['r:toggle', 'r:voice', 'r:length', 'r:spec', 'r:regen', 'r:delete']);
    expect(build().singleWhere((i) => i.id == 'r:delete').destructive, isTrue);
    expect(build().singleWhere((i) => i.id == 'r:regen').destructive, isFalse);
  });

  test('without settings the menu is actions only: no toggle, no knobs, no divider', () {
    final items = build(showSettings: false);
    expect(idsOf(items), ['r:regen', 'r:delete']);
    expect(items.any((i) => i.isDivider), isFalse);
  });

  test('an unreflected or erased week offers regenerate without delete: '
      'nothing stored means nothing to erase', () {
    expect(idsOf(build(canDelete: false)), [
      'r:toggle',
      'r:voice',
      'r:length',
      'r:spec',
      'r:regen',
    ]);
  });

  test('while the model cannot run, only delete survives (history stays manageable)', () {
    expect(idsOf(build(canRegenerate: false, showSettings: false)), ['r:delete']);
  });

  test('nothing at all when the model cannot run and the week stores nothing, '
      'so the screen drops the ellipsis instead of opening an empty menu', () {
    expect(build(canRegenerate: false, canDelete: false, showSettings: false), isEmpty);
  });

  test('the toggle row reflects enabled and carries the toggle id', () {
    final on = build().singleWhere((i) => i.id == 'r:toggle');
    expect(on.selected, isTrue);
    final off = build(enabled: false).singleWhere((i) => i.id == 'r:toggle');
    expect(off.selected, isFalse);
  });

  test('the current voice, length, and specificity children are marked selected', () {
    final items = reflectionsMenuItems(
      enabled: true,
      style: const ReflectionStyle(
        voice: ReflectionVoice.sparse,
        length: ReflectionLength.oneLine,
        specificity: ReflectionSpecificity.abstractThemes,
      ),
      labels: _labels,
      canRegenerate: true,
      canDelete: true,
      showSettings: true,
    );

    AppMenuItem parent(String id) => items.firstWhere((i) => i.id == id);
    expect(parent('r:voice').children.singleWhere((c) => c.selected).id, 'r:voice:sparse');
    expect(parent('r:length').children.singleWhere((c) => c.selected).id, 'r:length:one_line');
    expect(parent('r:spec').children.singleWhere((c) => c.selected).id, 'r:spec:abstract');
  });

  test('every submenu child carries a stable id (the native submenu needs it)', () {
    for (final parent in build().where((i) => i.children.isNotEmpty)) {
      for (final child in parent.children) {
        expect(child.id, isNotNull);
      }
    }
  });
}
