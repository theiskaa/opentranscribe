import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/reflect/reflection_options.dart';
import 'package:opentranscribe/core/reflect/reflection_period.dart';
import 'package:opentranscribe/core/theming/app_icons.dart';
import 'package:opentranscribe/view/layouts/reflections/components/reflections_menu.dart';
import 'package:opentranscribe/view/widgets/app_menu.dart';

const ReflectionMenuLabels _labels = (
  periods: 'Periods',
  daily: 'Daily',
  weekly: 'Weekly',
  monthly: 'Monthly',
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
  letPeriodDecide: 'Let the week decide',
);

const _weeklyOnly = {
  ReflectionPeriod.daily: false,
  ReflectionPeriod.weekly: true,
  ReflectionPeriod.monthly: false,
};

List<AppMenuItem> build({
  Map<ReflectionPeriod, bool> enabledByPeriod = _weeklyOnly,
  bool canRegenerate = true,
  bool canDelete = true,
  bool showSettings = true,
}) => reflectionsMenuItems(
  enabledByPeriod: enabledByPeriod,
  style: ReflectionStyle.defaults,
  labels: _labels,
  canRegenerate: canRegenerate,
  canDelete: canDelete,
  showSettings: showSettings,
);

Iterable<String?> idsOf(List<AppMenuItem> items) =>
    items.where((i) => !i.isDivider).map((i) => i.id);

void main() {
  test('the base order: the periods submenu, then the knobs, then the viewed '
      'page actions, with delete the only destructive one', () {
    expect(idsOf(build()), ['r:periods', 'r:voice', 'r:length', 'r:spec', 'r:regen', 'r:delete']);
    expect(build().singleWhere((i) => i.id == 'r:delete').destructive, isTrue);
    expect(build().singleWhere((i) => i.id == 'r:regen').destructive, isFalse);
  });

  test('without settings the menu is actions only: no toggles, no knobs, no divider', () {
    final items = build(showSettings: false);
    expect(idsOf(items), ['r:regen', 'r:delete']);
    expect(items.any((i) => i.isDivider), isFalse);
  });

  test('an unreflected or erased page offers regenerate without delete: '
      'nothing stored means nothing to erase', () {
    expect(idsOf(build(canDelete: false)), [
      'r:periods',
      'r:voice',
      'r:length',
      'r:spec',
      'r:regen',
    ]);
  });

  test('while the model cannot run, only delete survives (history stays manageable)', () {
    expect(idsOf(build(canRegenerate: false, showSettings: false)), ['r:delete']);
  });

  test('nothing at all when the model cannot run and the page stores nothing, '
      'so the screen drops the ellipsis instead of opening an empty menu', () {
    expect(build(canRegenerate: false, canDelete: false, showSettings: false), isEmpty);
  });

  test('the period toggles live under the periods submenu, marked selected and '
      'keeping the menu presented', () {
    final items = build(
      enabledByPeriod: {
        ReflectionPeriod.daily: true,
        ReflectionPeriod.weekly: false,
        ReflectionPeriod.monthly: true,
      },
    );
    final periods = items.singleWhere((i) => i.id == 'r:periods');
    expect(periods.icon, AppIcons.calendar);
    expect(periods.children.map((c) => c.id), ['r:daily', 'r:weekly', 'r:monthly']);
    expect(periods.children.map((c) => c.selected), [true, false, true]);
    for (final child in periods.children) {
      expect(child.keepsPresented, isTrue);
    }
    for (final item in items.where((i) => !i.isDivider)) {
      expect(item.icon, isNotNull);
    }
  });

  test('the current voice, length, and specificity children are marked selected', () {
    final items = reflectionsMenuItems(
      enabledByPeriod: _weeklyOnly,
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
