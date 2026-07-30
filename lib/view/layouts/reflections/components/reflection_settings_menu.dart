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

/// Builds the nested settings menu: an on/off toggle, then Voice/Length/Specifics
/// submenus. Pure, so the ids and `selected` flags are testable directly. On
/// native glass the children answer through their ids; on the drawn fallback the
/// parent ids open a follow-up dropdown (see [ReflectionSettingsMenu]).
List<AppMenuItem> reflectionMenuItems({
  required bool enabled,
  required ReflectionStyle style,
  required ReflectionMenuLabels labels,
}) {
  AppMenuItem voice(ReflectionVoice v, String label) =>
      AppMenuItem(id: 'r:voice:${v.wire}', label: label, selected: style.voice == v);
  AppMenuItem length(ReflectionLength v, String label) =>
      AppMenuItem(id: 'r:length:${v.wire}', label: label, selected: style.length == v);
  AppMenuItem spec(ReflectionSpecificity v, String label) =>
      AppMenuItem(id: 'r:spec:${v.wire}', label: label, selected: style.specificity == v);

  return [
    AppMenuItem(
      id: 'r:toggle',
      label: labels.reflections,
      icon: AppIcons.calendar,
      selected: enabled,
    ),
    const AppMenuItem.divider(),
    AppMenuItem(
      id: 'r:voice',
      label: labels.voice,
      children: [
        voice(ReflectionVoice.literary, labels.literary),
        voice(ReflectionVoice.observational, labels.observational),
        voice(ReflectionVoice.sparse, labels.sparse),
      ],
    ),
    AppMenuItem(
      id: 'r:length',
      label: labels.length,
      children: [
        length(ReflectionLength.oneLine, labels.oneLine),
        length(ReflectionLength.sentences, labels.sentences),
        length(ReflectionLength.paragraph, labels.paragraph),
      ],
    ),
    AppMenuItem(
      id: 'r:spec',
      label: labels.specifics,
      children: [
        spec(ReflectionSpecificity.nameFreely, labels.nameFreely),
        spec(ReflectionSpecificity.abstractThemes, labels.themesOnly),
        spec(ReflectionSpecificity.letWeekDecide, labels.letWeekDecide),
      ],
    ),
  ];
}

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
    List<T> values,
    T current,
    List<String> labels,
    Future<void> Function(T) setter,
  ) async {
    final index = await showAppDropdown(
      context,
      anchor: dropdownAnchorRect(_anchor, context),
      items: [
        for (final (i, v) in values.indexed)
          AppDropdownItem(label: labels[i], selected: v == current),
      ],
    );
    if (index != null && mounted) unawaited(setter(values[index]));
  }

  /// Parent id opens the picker, a `<prefix>:<wire>` child applies the value.
  /// Returns whether [id] was this dimension's, so the caller can stop.
  bool _handleStyle<T extends Enum>(
    String id, {
    required String prefix,
    required List<T> values,
    required T current,
    required List<String> labels,
    required T? Function(String?) fromWire,
    required Future<void> Function(T) setter,
  }) {
    if (id == prefix) {
      unawaited(_pickStyle(values, current, labels, setter));
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
      values: ReflectionVoice.values,
      current: style.voice,
      labels: [labels.literary, labels.observational, labels.sparse],
      fromWire: ReflectionVoice.fromWire,
      setter: cubit.setVoice,
    )) {
      return;
    }
    if (_handleStyle(
      id,
      prefix: 'r:length',
      values: ReflectionLength.values,
      current: style.length,
      labels: [labels.oneLine, labels.sentences, labels.paragraph],
      fromWire: ReflectionLength.fromWire,
      setter: cubit.setLength,
    )) {
      return;
    }
    _handleStyle(
      id,
      prefix: 'r:spec',
      values: ReflectionSpecificity.values,
      current: style.specificity,
      labels: [labels.nameFreely, labels.themesOnly, labels.letWeekDecide],
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
      onSelected: (_) {},
      onSelectedId: (id) => _onSelectedId(id, state, labels),
    );
  }
}
