import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/state/entry_export_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/layouts/entry/components/entry_export_menu.dart';
import 'package:opentranscribe/view/widgets/app_notice.dart';
import 'package:opentranscribe/view/widgets/batch_progress_label.dart';

/// The entry bar's one quiet line: a pass's progress, or the export's wait,
/// and a failed export as a notice that clears itself. The notice takes the
/// seat while it stands, so the two never print over each other.
class EntryBarLine extends StatelessWidget {
  const EntryBarLine({required this.entryId, super.key});

  final String entryId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = context.theme;
    final cubit = context.read<EntryExportCubit>();
    final export = context.watch<EntryExportCubit>().state;
    final line = entryExportLineOf(export);
    final failure = export.failure;
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedOpacity(
          opacity: line == EntryExportLine.failed ? 0 : 1,
          duration: context.reduceMotion ? Duration.zero : theme.motion.crossfade,
          // Shrunk to fit: under a long cloud a pass's line would run wide.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: BatchProgressLine(
              select: (passes) => passes.forEntry(entryId),
              fallback: line == EntryExportLine.preparing ? l10n.exportEntryPreparing : null,
            ),
          ),
        ),
        AppNotice(
          message: line == EntryExportLine.failed && failure != null
              ? entryExportFailureLabel(l10n, failure)
              : null,
          onDismiss: cubit.dismissFailure,
          oneLine: true,
        ),
      ],
    );
  }
}
