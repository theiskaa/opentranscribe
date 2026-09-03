import 'package:flutter/services.dart' show TextInputAction;
import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/superellipse.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/view/widgets/editable_prose.dart';

/// A single-line text input: a framed [EditableProse] with a placeholder and
/// an optional trailing control. [obscureText] turns it into a secret field:
/// dots for glyphs, and autocorrect and suggestions forced off so a
/// passphrase never reaches the keyboard's learning. Autofill is off for
/// every field, for the reasons [EditableProse] gives.
class AppTextField extends StatefulWidget {
  const AppTextField({
    required this.controller,
    this.placeholder,
    this.focusNode,
    this.autofocus = false,
    this.obscureText = false,
    this.secret,
    this.onChanged,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
    this.trailing,
    super.key,
  });

  final TextEditingController controller;
  final String? placeholder;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool obscureText;

  /// Keeps autocorrect and suggestions off even while the text is shown;
  /// null follows [obscureText]. A revealed secret must not feed the
  /// keyboard's learning.
  final bool? secret;

  final ValueChanged<String>? onChanged;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  /// Seated at the field's end, inside the frame (a reveal toggle, a clear
  /// affordance); its own taps win over the field's focus tap.
  final Widget? trailing;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  final GlobalKey<EditableProseState> _proseKey = GlobalKey<EditableProseState>();
  FocusNode? _ownedNode;

  FocusNode get _focusNode => widget.focusNode ?? (_ownedNode ??= FocusNode());

  @override
  void dispose() {
    _ownedNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final textStyle = AppType.body.copyWith(color: theme.text);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // A tap on the frame outside the text; the text's own taps place the
      // caret through the field.
      onTap: () {
        _focusNode.requestFocus();
        _proseKey.currentState?.requestKeyboard();
      },
      child: DecoratedBox(
        decoration: SuperellipseDecoration(
          borderRadius: AppRadius.card,
          color: theme.surface,
          border: BorderSide(color: theme.surfaceBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    if (widget.placeholder != null)
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: widget.controller,
                        builder: (context, value, _) => value.text.isEmpty
                            ? Text(
                                widget.placeholder!,
                                style: AppType.body.copyWith(color: theme.textSecondary),
                              )
                            : const SizedBox.shrink(),
                      ),
                    EditableProse(
                      key: _proseKey,
                      controller: widget.controller,
                      focusNode: _focusNode,
                      autofocus: widget.autofocus,
                      obscureText: widget.obscureText,
                      secret: widget.secret ?? widget.obscureText,
                      // No caret-into-view scroll. The default 20 makes every focus
                      // gain nudge the enclosing scrollable, so moving between two
                      // fields in one sheet ticks the content up and back down.
                      // Surfaces here seat their fields clear of the keyboard
                      // themselves, so there is nothing left for it to reveal.
                      scrollPadding: EdgeInsets.zero,
                      style: textStyle,
                      cursorColor: theme.accent,
                      backgroundCursorColor: theme.textSecondary,
                      selectionColor: theme.accent.withValues(alpha: 0.25),
                      keyboardAppearance: theme.brightness,
                      textInputAction: widget.textInputAction,
                      onChanged: widget.onChanged,
                      onSubmitted: widget.onSubmitted,
                    ),
                  ],
                ),
              ),
              if (widget.trailing != null) ...[
                const SizedBox(width: AppSpacing.md),
                widget.trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
