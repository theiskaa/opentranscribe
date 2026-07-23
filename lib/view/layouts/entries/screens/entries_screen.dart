import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:opentranscribe/core/routes/routes.dart';
import 'package:opentranscribe/core/state/entries_cubit.dart';
import 'package:opentranscribe/core/state/recorder_cubit.dart';
import 'package:opentranscribe/core/theming/app_theme.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/layouts/entries/components/entry_tile.dart';
import 'package:opentranscribe/view/layouts/entries/components/record_bar.dart';
import 'package:opentranscribe/view/widgets/app_scaffold.dart';

/// The journal: a list of entries with a record control at the bottom.
class EntriesScreen extends StatefulWidget {
  const EntriesScreen({super.key});

  @override
  State<EntriesScreen> createState() => _EntriesScreenState();
}

class _EntriesScreenState extends State<EntriesScreen> {
  @override
  void initState() {
    super.initState();
    context.read<EntriesCubit>().load();
  }

  Future<void> _stop() async {
    await context.read<RecorderCubit>().stop();
    if (mounted) context.read<EntriesCubit>().load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = AppColors.of(context);

    return AppScaffold(
      title: l10n.appTitle,
      trailing: CupertinoButton(
        padding: const EdgeInsets.all(AppSpacing.sm),
        minimumSize: Size.zero,
        onPressed: () => context.pushNamed(Routes.settingsName),
        child: Icon(CupertinoIcons.settings, color: colors.text, size: 24),
      ),
      child: Column(
        children: [
          Expanded(
            child: BlocBuilder<EntriesCubit, EntriesState>(
              builder: (context, state) {
                if (state.entries.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Text(
                        l10n.entriesEmpty,
                        textAlign: TextAlign.center,
                        style: AppText.body(context).copyWith(color: colors.muted),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: state.entries.length,
                  itemBuilder: (context, i) {
                    final entry = state.entries[i];
                    return EntryTile(
                      entry: entry,
                      busy: state.busyId == entry.id,
                      onTap: () =>
                          context.pushNamed(Routes.entryName, pathParameters: {'id': entry.id}),
                    );
                  },
                );
              },
            ),
          ),
          BlocConsumer<RecorderCubit, RecorderState>(
            listenWhen: (previous, current) => current.error != null && previous.error == null,
            listener: (context, state) {
              final message = state.error;
              context.read<RecorderCubit>().clearError();
              if (message != null) _showError(context, message);
            },
            builder: (context, state) => RecordBar(
              state: state,
              onStart: context.read<RecorderCubit>().start,
              onStop: _stop,
            ),
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
        title: Text(l10n.recordErrorTitle),
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
