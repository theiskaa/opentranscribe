import 'package:flutter/services.dart' show TextInputAction;
import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/superellipse.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';

/// A minimal text input built directly on [EditableText]: typing, cursor, and
/// tap-to-focus. Deliberately no selection handles or toolbar; the single-line
/// inputs here do not need them. [obscureText] turns it into a secret field:
/// dots for glyphs, and autocorrect and suggestions forced off so a
/// passphrase never reaches the keyboard's learning.
///
/// Autofill is off for every field. A secret offered to autofill is a secret
/// offered to iCloud Keychain, which is off-device; and the accessory strip
/// autofill hangs over the keyboard changes the inset as focus moves between
/// fields, which walks a keyboard-sized sheet up and down the screen.
class AppTextField extends StatefulWidget {
  const AppTextField({
    required this.controller,
    this.placeholder,
    this.focusNode,
    this.autofocus = false,
    this.obscureText = false,
    this.onChanged,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final String? placeholder;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool obscureText;
  final ValueChanged<String>? onChanged;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  final GlobalKey<EditableTextState> _editableKey = GlobalKey<EditableTextState>();
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
      onTap: () {
        _focusNode.requestFocus();
        _editableKey.currentState?.requestKeyboard();
      },
      child: DecoratedBox(
        decoration: SuperellipseDecoration(
          borderRadius: AppRadius.card,
          color: theme.surface,
          border: BorderSide(color: theme.surfaceBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
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
              EditableText(
                key: _editableKey,
                controller: widget.controller,
                focusNode: _focusNode,
                autofocus: widget.autofocus,
                obscureText: widget.obscureText,
                autocorrect: !widget.obscureText,
                enableSuggestions: !widget.obscureText,
                // Null, not the empty-list default: an empty list still opts
                // the field into autofill and lets the platform guess.
                autofillHints: null,
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
      ),
    );
  }
}
