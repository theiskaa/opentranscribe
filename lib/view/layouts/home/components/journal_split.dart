import 'package:flutter/widgets.dart';
import 'package:opentranscribe/core/utils/duo_layout.dart';
import 'package:opentranscribe/view/widgets/duo_style.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/models/pane_layout.dart';
import 'package:opentranscribe/core/routes/pane_stack.dart';
import 'package:opentranscribe/core/state/home_cubit.dart';
import 'package:opentranscribe/view/layouts/entry/screens/entry_detail_screen.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/view/layouts/home/components/journal_chrome.dart';
import 'package:opentranscribe/view/widgets/app_scaffold.dart';
import 'package:opentranscribe/view/widgets/glass_fab.dart';
import 'package:opentranscribe/view/widgets/pane_frame.dart';
import 'package:opentranscribe/view/widgets/pane_glide.dart';
import 'package:opentranscribe/view/widgets/safe_sides.dart';
import 'package:opentranscribe/view/widgets/side_column.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';

class JournalSplit extends StatelessWidget {
  const JournalSplit({required this.journal, super.key});

  final Widget journal;

  @override
  Widget build(BuildContext context) {
    final panes = PaneLayoutScope.of(context);
    final layout = PaneGlide.layoutOf(context);
    final split = layout.mode == PaneMode.split;
    final selection = PaneSelectionScope.selectionOf(context);
    return BlocBuilder<HomeCubit, HomeState>(
      builder: (context, home) => PaneSelectionScope(
        selection: journalPaneSelection(
          mode: layout.mode,
          selection: selection,
          hasDetail: panes.detailKeys.isNotEmpty,
          newestEntryId: home.entries.firstOrNull?.id,
        ),
        child: ColoredBox(
          color: context.theme.background,
          child: Stack(
            children: [
              PaneFrame(
                pane: layout.leading,
                touch: PaneTouch.journal,
                child: ColoredBox(
                  color: duoInnerOf(context)
                      ? context.theme.duo.surfaceGrouped
                      : context.theme.screens.home,
                  child: Padding(
                    padding: duoInnerOf(context)
                        ? duoFoldInsets(layout, PaneTouch.journal)
                        : EdgeInsets.zero,
                    child: journal,
                  ),
                ),
              ),
              Positioned.fromRect(
                rect:
                    (duoInnerOf(context)
                        ? duoDividerRect(layout, panes.media.padding)
                        : layout.divider) ??
                    Rect.zero,
                child: ColoredBox(
                  color: duoInnerOf(context)
                      ? context.theme.duo.separator
                      : context.theme.surfaceBorder,
                ),
              ),
              PaneFrame(
                pane: layout.detail,
                detailRoot: true,
                journalSelection: true,
                touch: split && panes.detailKeys.isEmpty ? PaneTouch.detail : null,
                child: Offstage(
                  offstage: !split || panes.detailKeys.isNotEmpty,
                  child: const _ProvisionalDetail(),
                ),
              ),
              GlassFabPosition(
                home: true,
                child: Offstage(
                  offstage: split || journalColumnEnabled(layout),
                  child: const JournalRecordButton(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProvisionalDetail extends StatefulWidget {
  const _ProvisionalDetail();

  @override
  State<_ProvisionalDetail> createState() => _ProvisionalDetailState();
}

class _ProvisionalDetailState extends State<_ProvisionalDetail> {
  bool _opened = false;

  @override
  Widget build(BuildContext context) {
    final panes = PaneLayoutScope.of(context);
    _opened = _opened || panes.layout.mode == PaneMode.split;
    return BlocBuilder<HomeCubit, HomeState>(
      builder: (context, state) {
        final entry = state.entries.firstOrNull;
        if (panes.journalSelectionKey != null) return const SizedBox.shrink();
        if (entry != null && _opened) {
          return EntryDetailScreen(key: panes.entryDetailKey(entry.id), entryId: entry.id);
        }
        return AppScaffold(
          background: context.theme.screens.entryDetail,
          child: const _EmptyDetail(),
        );
      },
    );
  }
}

class _EmptyDetail extends StatelessWidget {
  const _EmptyDetail();

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    return SafeSides(
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(
                  child: AppIcon(
                    AppIcons.waveform,
                    size: AppSizes.barControl,
                    color: theme.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text(
                  l10n.homeDetailEmptyTitle,
                  textAlign: TextAlign.center,
                  style: AppType.title.copyWith(color: theme.text),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.homeDetailEmptyBody,
                  textAlign: TextAlign.center,
                  style: AppType.subhead.copyWith(color: theme.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
