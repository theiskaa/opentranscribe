import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/state/entries_cubit.dart';
import 'package:opentranscribe/core/theming/app_theme.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/app_button.dart';
import 'package:opentranscribe/view/widgets/app_scaffold.dart';

/// A single entry: its transcript (or an untranscribed hint), with re-transcribe
/// and delete. Reads from [EntriesCubit] so it reflects re-transcription live.
class EntryDetailScreen extends StatelessWidget {
  const EntryDetailScreen({required this.entryId, super.key});

  final String entryId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);

    return BlocConsumer<EntriesCubit, EntriesState>(
      listenWhen: (previous, current) => current.error != null && previous.error != current.error,
      listener: (context, state) {
        final message = state.error;
        context.read<EntriesCubit>().clearError();
        if (message != null) _showError(context, message);
      },
      builder: (context, state) {
        final matches = state.entries.where((e) => e.id == entryId);
        final entry = matches.isEmpty ? null : matches.first;
        // Deleted from under us: leave the screen.
        if (entry == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted && context.canPop()) context.pop();
          });
          return AppScaffold(
            title: l10n.entryTitle,
            onBack: () => context.pop(),
            child: const SizedBox.shrink(),
          );
        }

        final busy = state.busyId == entry.id;
        final transcript = entry.transcript?.fullText.trim() ?? '';
        final hasText = transcript.isNotEmpty;

        return AppScaffold(
          title: l10n.entryTitle,
          onBack: () => context.pop(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Text(_formatDate(entry.createdAt), style: AppText.caption(context)),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: busy
                      ? const Center(child: CupertinoActivityIndicator())
                      : Text(
                          hasText ? transcript : l10n.entryUntranscribed,
                          style: hasText
                              ? AppText.body(context)
                              : AppText.body(context).copyWith(color: colors.muted),
                        ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: colors.hairline)),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        AppButton(
                          label: l10n.delete,
                          variant: AppButtonVariant.danger,
                          onPressed: busy ? null : () => _confirmDelete(context, entry),
                        ),
                        AppButton(
                          label: l10n.retranscribe,
                          icon: CupertinoIcons.arrow_2_circlepath,
                          onPressed: busy
                              ? null
                              : () => context.read<EntriesCubit>().retranscribe(entry),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, Entry entry) {
    final l10n = AppLocalizations.of(context)!;
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(l10n.deleteConfirmTitle),
        content: Text(l10n.deleteConfirmMessage),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(dialogContext).pop();
              context.read<EntriesCubit>().delete(entry);
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  void _showError(BuildContext context, String message) {
    final l10n = AppLocalizations.of(context)!;
    showCupertinoDialog<void>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(l10n.retranscribe),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime utc) => DateFormat.yMMMMd().add_jm().format(utc.toLocal());
