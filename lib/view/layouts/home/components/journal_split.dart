import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/models/pane_layout.dart';
import 'package:opentranscribe/core/routes/pane_stack.dart';
import 'package:opentranscribe/core/routes/routes.dart';
import 'package:opentranscribe/core/state/entries_cubit.dart';
import 'package:opentranscribe/core/state/home_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/view/layouts/home/components/journal_chrome.dart';
import 'package:opentranscribe/view/widgets/app_scaffold.dart';
import 'package:opentranscribe/view/widgets/formatting.dart';
import 'package:opentranscribe/view/widgets/glass_fab.dart';
import 'package:opentranscribe/view/widgets/pane_frame.dart';
import 'package:opentranscribe/view/widgets/pane_glide.dart';
import 'package:opentranscribe/view/widgets/safe_sides.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';
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
    return ColoredBox(
      color: context.theme.background,
      child: Stack(
        children: [
          PaneFrame(pane: layout.leading, touch: PaneTouch.journal, child: journal),
          Positioned.fromRect(
            rect: layout.divider ?? Rect.zero,
            child: ColoredBox(color: context.theme.surfaceBorder),
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
              offstage: split || journalColumnEnabled(layout: layout, cover: panes.cover),
              child: const JournalRecordButton(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProvisionalDetail extends StatelessWidget {
  const _ProvisionalDetail();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeCubit, HomeState>(
      builder: (context, state) {
        final entry = state.entries.firstOrNull;
        return AppScaffold(
          background: context.theme.screens.entryDetail,
          child: entry == null ? const _EmptyDetail() : _EntryPreview(entry: entry),
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

class _EntryPreview extends StatelessWidget {
  const _EntryPreview({required this.entry});

  final Entry entry;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return SafeSides(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppScaffold.topPaddingOf(context),
          AppSpacing.xl,
          MediaQuery.paddingOf(context).bottom + AppSpacing.xxxl,
        ),
        child: Touchable(
          onTap: () {
            context.read<EntriesCubit>().load();
            context.goNamed(Routes.entryName, pathParameters: {'id': entry.id});
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                entryDisplayTitle(entry, localeTag(context)),
                style: AppType.display2.copyWith(color: theme.text),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                formatTime(entry.createdAt, localeTag(context)),
                style: AppType.footnote.copyWith(color: theme.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text(entry.readableText ?? '', style: AppType.body.copyWith(color: theme.text)),
            ],
          ),
        ),
      ),
    );
  }
}
