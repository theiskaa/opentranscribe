import 'package:flutter/widgets.dart';
import 'package:liquid/liquid.dart';

import 'package:opentranscribe/core/models/pane_layout.dart';
import 'package:opentranscribe/core/routes/pane_stack.dart';
import 'package:opentranscribe/core/utils/duo_layout.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/view/layouts/home/components/home_menu.dart';
import 'package:opentranscribe/view/layouts/home/components/journal_chrome.dart';
import 'package:opentranscribe/view/widgets/duo_style.dart';
import 'package:opentranscribe/view/widgets/glass_fab.dart';
import 'package:opentranscribe/view/widgets/pane_frame.dart';
import 'package:opentranscribe/view/widgets/pane_glide.dart';
import 'package:opentranscribe/view/widgets/side_column.dart';

class JournalSplit extends StatelessWidget {
  const JournalSplit({required this.journal, super.key});

  final Widget journal;

  @override
  Widget build(BuildContext context) {
    final panes = PaneLayoutScope.of(context);
    final layout = PaneGlide.layoutOf(context);
    final split = layout.mode == PaneMode.split;
    final inner = duoInnerOf(context);
    return ColoredBox(
      color: context.theme.background,
      child: Stack(
        children: [
          PaneFrame(
            pane: layout.leading,
            touch: PaneTouch.journal,
            child: Offstage(
              offstage: !split,
              child: ColoredBox(
                color: context.theme.duo.surfaceGrouped,
                child: Padding(
                  padding: inner ? duoFoldInsets(layout, PaneTouch.journal) : EdgeInsets.zero,
                  child: LiquidRouteVisibility(
                    covered: panes.covered,
                    child: const SafeArea(child: HomeMenu(sidebar: true)),
                  ),
                ),
              ),
            ),
          ),
          PaneFrame(
            pane: split ? layout.detail : layout.leading,
            touch: split ? PaneTouch.detail : PaneTouch.journal,
            journalContent: true,
            child: Offstage(offstage: split && panes.detailKeys.isNotEmpty, child: journal),
          ),
          Positioned.fromRect(
            rect:
                (inner ? duoDividerRect(layout, panes.media.padding) : layout.divider) ?? Rect.zero,
            child: ColoredBox(
              color: inner ? context.theme.duo.separator : context.theme.surfaceBorder,
            ),
          ),
          GlassFabPosition(
            home: true,
            child: Offstage(
              offstage:
                  split || journalColumnEnabled(layout) || ModalRoute.isCurrentOf(context) == false,
              child: const JournalRecordButton(),
            ),
          ),
        ],
      ),
    );
  }
}
