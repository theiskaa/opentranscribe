import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/state/entries_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/formatting.dart';

/// Which entry this take extends, named live from the journal so a rename
/// mid-take shows.
class ContinuingLine extends StatelessWidget {
  const ContinuingLine({required this.entryId, super.key});

  final String entryId;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    return BlocSelector<EntriesCubit, EntriesState, Entry?>(
      selector: (state) => state.entries.where((e) => e.id == entryId).firstOrNull,
      builder: (context, entry) {
        if (entry == null) return const SizedBox.shrink();
        return Text(
          l10n.continuingEntry(entryDisplayTitle(entry, localeTag(context))),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppType.footnote.copyWith(color: theme.textSecondary),
        );
      },
    );
  }
}
