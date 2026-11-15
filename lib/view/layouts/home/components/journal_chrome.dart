import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:opentranscribe/core/models/pane_layout.dart';
import 'package:opentranscribe/core/routes/routes.dart';
import 'package:opentranscribe/core/routes/pane_observer.dart';
import 'package:opentranscribe/core/state/entries_cubit.dart';
import 'package:opentranscribe/core/state/home_cubit.dart';
import 'package:opentranscribe/core/utils/haptics.dart';
import 'package:opentranscribe/view/layouts/home/components/record_fab.dart';
import 'package:opentranscribe/view/widgets/glass_fab.dart';
import 'package:opentranscribe/view/widgets/pane_frame.dart';
import 'package:opentranscribe/view/widgets/side_column.dart';

bool journalRecordVisible({
  required PaneMode mode,
  required bool covered,
  required bool bottomSlotOccupied,
  bool column = false,
  bool cover = false,
  bool detail = false,
}) => (mode == PaneMode.split || column) && !covered && !bottomSlotOccupied && !(cover && detail);

class JournalChrome extends StatelessWidget {
  const JournalChrome({required this.observer, super.key});

  final PaneObserver observer;

  @override
  Widget build(BuildContext context) {
    final panes = PaneLayoutScope.of(context);
    final layout = panes.layout;
    final column = journalColumnEnabled(layout);
    return ListenableBuilder(
      listenable: observer,
      builder: (context, child) => Stack(
        children: [
          GlassFabPosition(
            home: true,
            child: Offstage(
              offstage: !journalRecordVisible(
                mode: layout.mode,
                column: column,
                covered: observer.chromeCovered,
                cover: panes.cover,
                detail: observer.selectionOnTop,
                bottomSlotOccupied: observer.bottomSlotOccupied,
              ),
              child: const JournalRecordButton(),
            ),
          ),
        ],
      ),
    );
  }
}

class JournalRecordButton extends StatelessWidget {
  const JournalRecordButton({super.key});

  @override
  Widget build(BuildContext context) => RecordFab(
    onTap: () {
      Haptics.medium();
      final home = context.read<HomeCubit>();
      final entries = context.read<EntriesCubit>();
      context.pushNamed(Routes.recordName).then((_) {
        entries.load();
        home.load();
      });
    },
  );
}
