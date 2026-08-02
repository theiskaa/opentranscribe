import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/models/reflection_timeline.dart';
import 'package:opentranscribe/core/reflect/reflection_options.dart';
import 'package:opentranscribe/core/state/reflections_cubit.dart';
import 'package:opentranscribe/core/theming/app_icons.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/app_dropdown.dart';
import 'package:opentranscribe/view/widgets/app_menu.dart';

/// The user-facing labels for the reflections menu, passed in so the item
/// builder stays pure (testable without a BuildContext).
typedef ReflectionMenuLabels = ({
  String reflections,
  String regenerate,
  String delete,
  String voice,
  String length,
  String specifics,
  String literary,
  String observational,
  String sparse,
  String oneLine,
  String sentences,
  String paragraph,
  String nameFreely,
  String themesOnly,
  String letWeekDecide,
});

/// One value/label pairing per dimension, the single source both the submenu
/// items and the fallback dropdown draw from, so neither can drift out of step
/// with the other (or with a reordered enum).
List<(ReflectionVoice, String)> _voiceChoices(ReflectionMenuLabels labels) => [
  (ReflectionVoice.literary, labels.literary),
  (ReflectionVoice.observational, labels.observational),
  (ReflectionVoice.sparse, labels.sparse),
];

List<(ReflectionLength, String)> _lengthChoices(ReflectionMenuLabels labels) => [
  (ReflectionLength.oneLine, labels.oneLine),
  (ReflectionLength.sentences, labels.sentences),
  (ReflectionLength.paragraph, labels.paragraph),
];

List<(ReflectionSpecificity, String)> _specChoices(ReflectionMenuLabels labels) => [
  (ReflectionSpecificity.nameFreely, labels.nameFreely),
  (ReflectionSpecificity.abstractThemes, labels.themesOnly),
  (ReflectionSpecificity.letWeekDecide, labels.letWeekDecide),
];

AppMenuItem _group<T extends Enum>({
  required String id,
  required String label,
  required List<(T, String)> choices,
  required T current,
  required String Function(T) wireOf,
}) => AppMenuItem(
  id: id,
  label: label,
  children: [
    for (final (value, text) in choices)
      AppMenuItem(id: '$id:${wireOf(value)}', label: text, selected: value == current),
  ],
);

/// Builds the reflections menu in the locked navigation order: the on/off
/// toggle first, then the Voice/Length/Specifics knobs, a divider, then
/// Regenerate and Delete for the viewed week. [showSettings] is false when
/// the model cannot run (the knobs would set nothing; Delete survives). Pure,
/// so the ids, order, gating, and `selected` flags are testable directly. On
/// native glass the submenu children answer through their ids; on the drawn
/// fallback the parent ids open a follow-up dropdown.
List<AppMenuItem> reflectionsMenuItems({
  required bool enabled,
  required ReflectionStyle style,
  required ReflectionMenuLabels labels,
  required bool canRegenerate,
  required bool canDelete,
  required bool showSettings,
}) => [
  if (showSettings) ...[
    AppMenuItem(
      id: 'r:toggle',
      label: labels.reflections,
      icon: AppIcons.calendar,
      selected: enabled,
    ),
    // Its own section: the toggle's checkmark column would otherwise indent
    // every knob row beneath it on the native menu.
    const AppMenuItem.divider(),
    _group(
      id: 'r:voice',
      label: labels.voice,
      choices: _voiceChoices(labels),
      current: style.voice,
      wireOf: (ReflectionVoice v) => v.wire,
    ),
    _group(
      id: 'r:length',
      label: labels.length,
      choices: _lengthChoices(labels),
      current: style.length,
      wireOf: (ReflectionLength v) => v.wire,
    ),
    _group(
      id: 'r:spec',
      label: labels.specifics,
      choices: _specChoices(labels),
      current: style.specificity,
      wireOf: (ReflectionSpecificity v) => v.wire,
    ),
  ],
  if (showSettings && (canRegenerate || canDelete)) const AppMenuItem.divider(),
  if (canRegenerate)
    AppMenuItem(id: 'r:regen', label: labels.regenerate, icon: AppIcons.arrowCounterclockwise),
  if (canDelete)
    AppMenuItem(id: 'r:delete', label: labels.delete, icon: AppIcons.trash, destructive: true),
];

ReflectionMenuLabels _labelsOf(AppLocalizations l10n) => (
  reflections: l10n.reflectionsTitle,
  regenerate: l10n.reflectionRegenerate,
  delete: l10n.reflectionDelete,
  voice: l10n.reflectionVoice,
  length: l10n.reflectionLength,
  specifics: l10n.reflectionSpecifics,
  literary: l10n.reflectionVoiceLiterary,
  observational: l10n.reflectionVoiceObservational,
  sparse: l10n.reflectionVoiceSparse,
  oneLine: l10n.reflectionLengthOneLine,
  sentences: l10n.reflectionLengthSentences,
  paragraph: l10n.reflectionLengthParagraph,
  nameFreely: l10n.reflectionSpecificsNameFreely,
  themesOnly: l10n.reflectionSpecificsThemes,
  letWeekDecide: l10n.reflectionSpecificsLetWeek,
);

/// THE reflections menu - the surface has exactly one: the settings knobs
/// over the VIEWED week's actions, gated by what the week holds and whether
/// the model can run. Regenerate covers every status (an unreflected or
/// erased week is "write it now"); Delete only what is stored, but even while
/// the model is unavailable, so history stays manageable.
class ReflectionsMenu extends StatefulWidget {
  const ReflectionsMenu({required this.viewed, this.color, super.key});

  /// The week the menu acts on; null renders a settings-only menu.
  final ReflectionWeek? viewed;

  final Color? color;

  @override
  State<ReflectionsMenu> createState() => _ReflectionsMenuState();
}

class _ReflectionsMenuState extends State<ReflectionsMenu> {
  /// The menu button, which the fallback dropdowns anchor to.
  final GlobalKey _anchor = GlobalKey();

  /// The drawn fallback picker; native glass uses the real submenu instead.
  Future<void> _pickStyle<T extends Enum>(
    List<(T, String)> choices,
    T current,
    Future<void> Function(T) setter,
  ) async {
    final index = await showAppDropdown(
      context,
      anchor: dropdownAnchorRect(_anchor, context),
      items: [
        for (final (value, label) in choices)
          AppDropdownItem(label: label, selected: value == current),
      ],
    );
    if (index != null && mounted) unawaited(setter(choices[index].$1));
  }

  /// Parent id opens the picker, a `<prefix>:<wire>` child applies the value.
  /// Returns whether [id] was this dimension's, so the caller can stop.
  bool _handleStyle<T extends Enum>(
    String id, {
    required String prefix,
    required List<(T, String)> choices,
    required T current,
    required T? Function(String?) fromWire,
    required Future<void> Function(T) setter,
  }) {
    if (id == prefix) {
      unawaited(_pickStyle(choices, current, setter));
      return true;
    }
    if (id.startsWith('$prefix:')) {
      final value = fromWire(id.substring(prefix.length + 1));
      if (value != null) unawaited(setter(value));
      return true;
    }
    return false;
  }

  /// Drops any live text selection, then regenerates one frame later so the
  /// cleared page paints before the ink reveal captures its last frame: a
  /// selection left standing would bake its highlight wash into the dissolving
  /// ink. The page owns its own SelectableRegion, so the active selection holds
  /// the primary focus; unfocusing it is what clears it. Mirrors the entry
  /// screen's re-transcribe.
  void _startRegenerate(ReflectionsCubit cubit, DateTime weekStart) {
    FocusManager.instance.primaryFocus?.unfocus();
    WidgetsBinding.instance.endOfFrame.then((_) {
      if (mounted) unawaited(cubit.regenerate(weekStart));
    });
  }

  void _onSelectedId(String id, ReflectionsState state, ReflectionMenuLabels labels) {
    final cubit = context.read<ReflectionsCubit>();
    final style = state.style;
    final viewed = widget.viewed;

    if (id == 'r:regen') {
      if (viewed != null) _startRegenerate(cubit, viewed.weekStart);
      return;
    }
    if (id == 'r:delete') {
      // Straight through, no confirm: the menu already took a deliberate tap to
      // open and a second on a row marked destructive, the same bar the entry
      // delete holds itself to.
      if (viewed != null) unawaited(cubit.delete(viewed.weekStart));
      return;
    }
    if (id == 'r:toggle') {
      unawaited(cubit.setEnabled(!state.enabled));
      return;
    }
    if (_handleStyle(
      id,
      prefix: 'r:voice',
      choices: _voiceChoices(labels),
      current: style.voice,
      fromWire: ReflectionVoice.fromWire,
      setter: cubit.setVoice,
    )) {
      return;
    }
    if (_handleStyle(
      id,
      prefix: 'r:length',
      choices: _lengthChoices(labels),
      current: style.length,
      fromWire: ReflectionLength.fromWire,
      setter: cubit.setLength,
    )) {
      return;
    }
    _handleStyle(
      id,
      prefix: 'r:spec',
      choices: _specChoices(labels),
      current: style.specificity,
      fromWire: ReflectionSpecificity.fromWire,
      setter: cubit.setSpecificity,
    );
  }

  @override
  Widget build(BuildContext context) {
    final labels = _labelsOf(AppLocalizations.of(context)!);
    final state = context.watch<ReflectionsCubit>().state;
    final viewed = widget.viewed;
    final items = reflectionsMenuItems(
      enabled: state.enabled,
      style: state.style,
      labels: labels,
      canRegenerate: viewed != null && state.available,
      canDelete: viewed?.reflection != null,
      showSettings: state.available,
    );
    // No applicable item (the model cannot run and the week stores nothing):
    // no button, rather than an ellipsis that opens an empty menu.
    if (items.isEmpty) return const SizedBox.shrink();
    return AppMenuButton(
      key: _anchor,
      icon: AppIcons.ellipsis,
      color: widget.color,
      items: items,
      onSelectedId: (id) => _onSelectedId(id, state, labels),
    );
  }
}
