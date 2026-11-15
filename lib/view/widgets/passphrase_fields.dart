import 'package:flutter/services.dart' show TextInputAction;
import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/view/widgets/app_text_field.dart';
import 'package:opentranscribe/view/widgets/passphrase_rules.dart';

/// The words the passphrase fields render, provided by the caller so the
/// widget stays l10n-free. The two constructors ARE the two flows:
/// [PassphraseFieldStrings.seal] carries what double entry's footnotes need,
/// [PassphraseFieldStrings.unlock] cannot carry fields it would never show.
@immutable
final class PassphraseFieldStrings {
  const PassphraseFieldStrings.seal({
    required this.placeholder,
    required String this.repeatPlaceholder,
    required String this.tooShort,
    required String this.mismatch,
    required this.show,
    required this.hide,
  }) : confirm = true;

  const PassphraseFieldStrings.unlock({
    required this.placeholder,
    required this.show,
    required this.hide,
  }) : confirm = false,
       repeatPlaceholder = null,
       tooShort = null,
       mismatch = null;

  final bool confirm;
  final String placeholder;
  final String? repeatPlaceholder;
  final String? tooShort;
  final String? mismatch;

  /// The reveal toggle's two faces. Words, not a glyph: the icon subset
  /// carries no eye, and a labeled toggle needs no decoding.
  final String show;
  final String hide;
}

/// Whether what is typed may be submitted: a sealing pair must pass
/// [passphraseIssue], an unlock needs any non-empty passphrase.
bool passphraseSubmittable({required bool confirm, required String passphrase, String? repeat}) =>
    confirm ? passphraseIssue(passphrase, repeat ?? '') == null : passphrase.isNotEmpty;

/// Whether a failed unlock's words show: after a failed [attempt], until the
/// user edits the text that failed ([editedAttempt] is the attempt they last
/// typed under).
bool unlockErrorShown({required int attempt, required int? editedAttempt}) =>
    attempt > 0 && editedAttempt != attempt;

/// The passphrase entry every surface uses: one field to unlock, two to seal,
/// a reveal toggle that shows both together, and a notice line that holds its
/// height whether or not it speaks, so nothing around it walks as it does.
/// The caller owns the controllers and the action that submits; [onSubmitted]
/// is the keyboard's Done on the last field.
class PassphraseFields extends StatefulWidget {
  const PassphraseFields({
    required this.strings,
    required this.controller,
    this.repeatController,
    this.errorText,
    this.attempt = 0,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    super.key,
  });

  final PassphraseFieldStrings strings;
  final TextEditingController controller;

  /// The confirmation field's text; sealing strings must come with one.
  final TextEditingController? repeatController;

  /// A failed unlock's words. The notice line keeps their room whether or
  /// not they show; they show after a failed [attempt] until the user edits
  /// what failed.
  final String? errorText;

  /// Counts the unlocks that failed, 0 while none has (or while one is being
  /// checked). A new one brings [errorText] back, selects the text that
  /// failed so typing replaces it, and focuses [focusNode].
  final int attempt;

  /// The first field's focus, for a caller that must bring the keyboard back
  /// to fields it never unmounted.
  final FocusNode? focusNode;

  final VoidCallback? onChanged;
  final VoidCallback? onSubmitted;

  @override
  State<PassphraseFields> createState() => _PassphraseFieldsState();
}

class _PassphraseFieldsState extends State<PassphraseFields> {
  /// Both fields reveal together: half-hidden double entry helps nobody.
  bool _reveal = false;

  /// The failed attempt whose text the user has since edited, so its words
  /// stand down.
  int? _editedAttempt;

  @override
  void initState() {
    super.initState();
    if (widget.attempt > 0) _selectAll();
  }

  @override
  void didUpdateWidget(PassphraseFields old) {
    super.didUpdateWidget(old);
    if (widget.attempt != old.attempt && widget.attempt > 0) {
      _selectAll();
      widget.focusNode?.requestFocus();
    }
  }

  void _selectAll() {
    final text = widget.controller.text;
    widget.controller.selection = TextSelection(baseOffset: 0, extentOffset: text.length);
  }

  bool get _confirm => widget.strings.confirm;

  /// What the notice line reserves room for while it has nothing to say.
  /// Null only where no notice can ever appear, so no room is owed.
  String? get _noticeSlot => _confirm ? widget.strings.mismatch : widget.errorText;

  String? get _notice {
    if (!_confirm) {
      return unlockErrorShown(attempt: widget.attempt, editedAttempt: _editedAttempt)
          ? widget.errorText
          : null;
    }
    final strings = widget.strings;
    return switch (passphraseNotice(widget.controller.text, widget.repeatController!.text)) {
      PassphraseIssue.tooShort => strings.tooShort,
      PassphraseIssue.mismatch => strings.mismatch,
      null => null,
    };
  }

  void _changed() {
    setState(() => _editedAttempt = widget.attempt);
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final strings = widget.strings;
    final notice = _notice;
    final slot = _noticeSlot;
    // The control's clock: the notice comes and goes with the capsule that
    // submitted.
    final fade = context.reduceMotion ? Duration.zero : theme.motion.indicator;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppTextField(
          controller: widget.controller,
          placeholder: strings.placeholder,
          focusNode: widget.focusNode,
          autofocus: true,
          obscureText: !_reveal,
          secret: true,
          onChanged: (_) => _changed(),
          textInputAction: _confirm ? TextInputAction.next : TextInputAction.done,
          onSubmitted: _confirm ? null : (_) => widget.onSubmitted?.call(),
          trailing: _RevealToggle(
            label: _reveal ? strings.hide : strings.show,
            onTap: () => setState(() => _reveal = !_reveal),
          ),
        ),
        if (_confirm) ...[
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: widget.repeatController!,
            placeholder: strings.repeatPlaceholder!,
            obscureText: !_reveal,
            secret: true,
            onChanged: (_) => _changed(),
            onSubmitted: (_) => widget.onSubmitted?.call(),
          ),
        ],
        if (slot != null) ...[
          const SizedBox(height: AppSpacing.sm),
          AnimatedOpacity(
            opacity: notice == null ? 0 : 1,
            duration: fade,
            curve: theme.motion.indicatorCurve,
            child: Text(
              notice ?? slot,
              style: AppType.footnote.copyWith(
                color: _confirm ? theme.textSecondary : theme.danger,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _RevealToggle extends StatelessWidget {
  const _RevealToggle({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Horizontal only: vertical padding would make this the tallest child
    // and grow its field past the repeat one.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Text(label, style: AppType.footnote.copyWith(color: context.theme.textSecondary)),
      ),
    );
  }
}
