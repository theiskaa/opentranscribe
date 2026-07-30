import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/reflect/reflection_options.dart';
import 'package:opentranscribe/core/state/reflections_cubit.dart';
import 'package:opentranscribe/core/theming/app_icons.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/app_dropdown.dart';
import 'package:opentranscribe/view/widgets/app_menu.dart';

/// The user-facing labels for the reflection settings menu, passed in so the
/// item builder stays pure (testable without a BuildContext).
typedef ReflectionMenuLabels = ({
  String reflections,
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

/// Builds the nested settings menu: an on/off toggle, then Voice/Length/Specifics
/// submenus. Pure, so the ids and `selected` flags are testable directly. On
/// native glass the children answer through their ids; on the drawn fallback the
/// parent ids open a follow-up dropdown (see [ReflectionSettingsMenu]).
List<AppMenuItem> reflectionMenuItems({
  required bool enabled,
  required ReflectionStyle style,
  required ReflectionMenuLabels labels,
}) => [
  AppMenuItem(
    id: 'r:toggle',
    label: labels.reflections,
    icon: AppIcons.calendar,
    selected: enabled,
  ),
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
];

ReflectionMenuLabels _labelsOf(AppLocalizations l10n) => (
  reflections: l10n.reflectionsTitle,
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

/// The top-bar settings control for the Reflections screen: the nested menu
/// exactly like the language pickers. On native glass the submenus carry the
/// choices; on the fallback a parent tap opens the drawn dropdown for that group.
class ReflectionSettingsMenu extends StatefulWidget {
  const ReflectionSettingsMenu({this.color, super.key});

  final Color? color;

  @override
  State<ReflectionSettingsMenu> createState() => _ReflectionSettingsMenuState();
}

class _ReflectionSettingsMenuState extends State<ReflectionSettingsMenu> {
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

  void _onSelectedId(String id, ReflectionsState state, ReflectionMenuLabels labels) {
    final cubit = context.read<ReflectionsCubit>();
    final style = state.style;

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
    return AppMenuButton(
      key: _anchor,
      icon: AppIcons.gearshape,
      color: widget.color,
      items: reflectionMenuItems(enabled: state.enabled, style: state.style, labels: labels),
      onSelectedId: (id) => _onSelectedId(id, state, labels),
    );
  }
}
