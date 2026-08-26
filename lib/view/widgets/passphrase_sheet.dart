import 'package:flutter/services.dart' show TextInputAction;
import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/view/widgets/app_button.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/app_sheet.dart';
import 'package:opentranscribe/view/widgets/app_text_field.dart';
import 'package:opentranscribe/view/widgets/passphrase_rules.dart';
import 'package:opentranscribe/view/widgets/sheet_message.dart';

/// The strings a passphrase sheet renders, provided by the caller so the
/// widget stays l10n-free. The two constructors ARE the two flows:
/// [PassphraseSheetStrings.seal] requires everything the double-entry
/// footnotes need, [PassphraseSheetStrings.unlock] cannot carry fields it
/// would never show.
@immutable
final class PassphraseSheetStrings {
  const PassphraseSheetStrings.seal({
    required this.title,
    required this.body,
    required this.placeholder,
    required String this.repeatPlaceholder,
    required this.actionLabel,
    required String this.tooShort,
    required String this.mismatch,
  }) : confirm = true;

  const PassphraseSheetStrings.unlock({
    required this.title,
    required this.body,
    required this.placeholder,
    required this.actionLabel,
  }) : confirm = false,
       repeatPlaceholder = null,
       tooShort = null,
       mismatch = null;

  final bool confirm;
  final String title;
  final String body;
  final String placeholder;
  final String actionLabel;
  final String? repeatPlaceholder;
  final String? tooShort;
  final String? mismatch;
}

/// Asks for a passphrase at action time, so a secret never sits on a settings
/// list under an open keyboard. [PassphraseSheetStrings.seal] is the sealing
/// flow (double entry, minimum length, live footnote);
/// [PassphraseSheetStrings.unlock] is the unlock flow (single field, any
/// non-empty passphrase, optional [errorText] from a failed decrypt, shown
/// until the user starts a fresh attempt). Resolves to the passphrase, or
/// null when dismissed.
Future<String?> showPassphraseSheet(
  BuildContext context, {
  required PassphraseSheetStrings strings,
  String? errorText,
}) => showAppSheet<String>(
  context,
  builder: (context) => _PassphraseSheetBody(strings: strings, errorText: errorText),
);

class _PassphraseSheetBody extends StatefulWidget {
  const _PassphraseSheetBody({required this.strings, this.errorText});

  final PassphraseSheetStrings strings;
  final String? errorText;

  @override
  State<_PassphraseSheetBody> createState() => _PassphraseSheetBodyState();
}

class _PassphraseSheetBodyState extends State<_PassphraseSheetBody> {
  final _passphrase = TextEditingController();
  final _repeat = TextEditingController();

  bool get _confirm => widget.strings.confirm;

  @override
  void dispose() {
    _passphrase.dispose();
    _repeat.dispose();
    super.dispose();
  }

  bool get _submittable => _confirm
      ? passphraseIssue(_passphrase.text, _repeat.text) == null
      : _passphrase.text.isNotEmpty;

  /// What the notice line reserves room for while it has nothing to say. The
  /// line holds its height either way: one that comes and goes resizes the
  /// sheet, and a sheet sized to the keyboard walks up and down as it does.
  /// Null only where no notice can ever appear, so no room is owed.
  String? get _noticeSlot => _confirm ? widget.strings.mismatch : widget.errorText;

  String? get _notice {
    if (!_confirm) {
      return _passphrase.text.isEmpty ? widget.errorText : null;
    }
    final strings = widget.strings;
    return switch (passphraseNotice(_passphrase.text, _repeat.text)) {
      PassphraseIssue.tooShort => strings.tooShort,
      PassphraseIssue.mismatch => strings.mismatch,
      null => null,
    };
  }

  void _submit() {
    // The keyboard's Done arrives over the text-input channel, which the
    // exit transition's pointer guard cannot block; without the liveness
    // check a submit landing mid-dismiss would pop the screen underneath.
    if (!_submittable || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
    Navigator.of(context).pop(_passphrase.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final strings = widget.strings;
    final notice = _notice;
    final slot = _noticeSlot;
    final fade = context.reduceMotion ? Duration.zero : theme.motion.crossfade;
    return SheetMessage(
      icon: AppIcons.lock,
      title: strings.title,
      body: strings.body,
      rows: [
        AppTextField(
          controller: _passphrase,
          placeholder: strings.placeholder,
          autofocus: true,
          obscureText: true,
          onChanged: (_) => setState(() {}),
          textInputAction: _confirm ? TextInputAction.next : TextInputAction.done,
          onSubmitted: _confirm ? null : (_) => _submit(),
        ),
        if (_confirm) ...[
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _repeat,
            placeholder: strings.repeatPlaceholder!,
            obscureText: true,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
          ),
        ],
        if (slot != null) ...[
          const SizedBox(height: AppSpacing.sm),
          AnimatedOpacity(
            opacity: notice == null ? 0 : 1,
            duration: fade,
            child: Text(
              notice ?? slot,
              style: AppType.footnote.copyWith(
                color: _confirm ? theme.textSecondary : theme.danger,
              ),
            ),
          ),
        ],
      ],
      action: AppButton(label: strings.actionLabel, onPressed: _submittable ? _submit : null),
    );
  }
}
