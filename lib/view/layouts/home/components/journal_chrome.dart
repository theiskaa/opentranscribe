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

bool journalRecordVisible({
  required PaneMode mode,
  required bool covered,
  required bool bottomSlotOccupied,
}) => mode == PaneMode.split && !covered && !bottomSlotOccupied;

class JournalChrome extends StatelessWidget {
  const JournalChrome({required this.observer, super.key});

  final PaneObserver observer;

  @override
  Widget build(BuildContext context) {
    final mode = PaneLayoutScope.of(context).layout.mode;
    return ListenableBuilder(
      listenable: observer,
      builder: (context, child) => Offstage(
        offstage: !journalRecordVisible(
          mode: mode,
          covered: observer.chromeCovered,
          bottomSlotOccupied: observer.bottomSlotOccupied,
        ),
        child: child,
      ),
      child: const Stack(children: [GlassFabPosition(home: true, child: JournalRecordButton())]),
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
