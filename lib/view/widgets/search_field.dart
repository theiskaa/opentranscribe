import 'package:flutter/services.dart' show TextInputAction;
import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/superellipse.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/app_text_field.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';

/// A drawn search input: the magnifier, a bare [AppTextField], and a clear
/// mark that appears with text and empties the field without dropping focus.
/// One shell, drawn here (the field runs bare inside it), on the settings
/// cards' surface and border so it sits level with the lists it filters; a
/// tap anywhere on the pill focuses the field.
class SearchField extends StatefulWidget {
  const SearchField({required this.controller, this.placeholder, this.onChanged, super.key});

  final TextEditingController controller;
  final String? placeholder;
  final ValueChanged<String>? onChanged;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final tokens = theme.settings;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _focusNode.requestFocus,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        decoration: SuperellipseDecoration(
          borderRadius: AppRadius.chip,
          color: tokens.cardBackground,
          border: BorderSide(color: theme.surfaceBorder),
        ),
        child: Row(
          children: [
            AppIcon(AppIcons.magnifyingglass, size: 16, color: theme.textSecondary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: AppTextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  placeholder: widget.placeholder,
                  bare: true,
                  onChanged: widget.onChanged,
                  textInputAction: TextInputAction.search,
                ),
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: widget.controller,
              builder: (context, value, _) => value.text.isEmpty
                  ? const SizedBox.shrink()
                  : Touchable(
                      onTap: () {
                        widget.controller.clear();
                        widget.onChanged?.call('');
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.md,
                        ),
                        child: AppIcon(AppIcons.xmark, size: 13, color: theme.textSecondary),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
