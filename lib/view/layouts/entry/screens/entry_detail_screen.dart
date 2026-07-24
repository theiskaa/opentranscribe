import 'package:flutter/services.dart' show TextInputAction;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:opentranscribe/core/app/deps.dart';
import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/state/entries_cubit.dart';
import 'package:opentranscribe/core/state/player_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/layouts/entry/components/wave_player.dart';
import 'package:opentranscribe/view/layouts/entry/components/transcript_view.dart';
import 'package:opentranscribe/view/widgets/app_menu.dart';
import 'package:opentranscribe/view/widgets/app_notice.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/app_top_bar.dart';
import 'package:opentranscribe/view/widgets/formatting.dart';

/// One entry as a document: its title, when it was made, the recording drawn as
/// a wave you can scrub, then what was said. Reads [EntriesCubit] so
/// re-transcription and rename reflect live; owns a [PlayerCubit] so playback
/// dies with the screen.
class EntryDetailScreen extends StatelessWidget {
  const EntryDetailScreen({required this.entryId, super.key});

  final String entryId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PlayerCubit(player: Deps.i.audioPlayer, service: Deps.i.transcriptionService),
      child: _DetailView(entryId: entryId),
    );
  }
}

class _DetailView extends StatefulWidget {
  const _DetailView({required this.entryId});

  final String entryId;

  @override
  State<_DetailView> createState() => _DetailViewState();
}

class _DetailViewState extends State<_DetailView> {
  final FocusNode _titleFocus = FocusNode();
  PlayerCubit? _player;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Captured here because dispose() must not look the cubit up via context.
    _player = context.read<PlayerCubit>();
  }

  @override
  void dispose() {
    // Leaving the screen silences playback; the cubit closes with the provider.
    _player?.stopAndDetach();
    _titleFocus.dispose();
    super.dispose();
  }

  void _onAction(int index, Entry entry, AppLocalizations l10n) {
    switch (index) {
      case 0:
        _titleFocus.requestFocus();
      case 1:
        context.read<EntriesCubit>().retranscribe(entry);
      case 2:
        // Straight through, no confirm. The menu already took a deliberate tap
        // to open and a second one to land on a row marked destructive; a sheet
        // asking the same question again is a tax on every deliberate delete to
        // catch the accidental one.
        context.read<EntriesCubit>().delete(entry);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;

    return BlocBuilder<EntriesCubit, EntriesState>(
      builder: (context, state) {
        final matches = state.entries.where((e) => e.id == widget.entryId);
        final entry = matches.isEmpty ? null : matches.first;
        // Deleted from under us: leave the screen.
        if (entry == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted && context.canPop()) context.pop();
          });
          return ColoredBox(color: theme.screens.entryDetail, child: const SizedBox.expand());
        }

        final busy = state.busyId == entry.id;
        return ColoredBox(
          color: theme.screens.entryDetail,
          child: Stack(
            children: [
              // ONE document: title, what it is, how it sounds, what it says -
              // in that order, on one scroll. The player goes with it rather
              // than pinning to the floor, so the transcript reads as a page
              // and not as text squeezed between two bars.
              Positioned.fill(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    // Past the bar AND its fade tail: the material is opaque
                    // through the row and only melts across the tail, so
                    // content starting inside it would sit under the wash.
                    AppTopBar.heightOf(context) + theme.topBar.fadeTail,
                    AppSpacing.xl,
                    MediaQuery.paddingOf(context).bottom + AppSpacing.xxxl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // A failure the screen could not prevent (a delete or
                      // rename that did not take), inline at the top and gone on
                      // its own - no dialog.
                      AppNotice(
                        message: state.error,
                        onDismiss: () => context.read<EntriesCubit>().clearError(),
                      ),
                      _TitleField(entry: entry, focusNode: _titleFocus),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '${DateFormat.yMMMMd().format(entry.createdAt.toLocal())}'
                        ' \u00b7 ${formatTime(entry.createdAt)}'
                        ' \u00b7 ${formatClock(entry.duration)}',
                        style: AppType.digits(
                          AppType.footnote,
                        ).copyWith(color: theme.textSecondary),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      WavePlayer(entry: entry),
                      const SizedBox(height: AppSpacing.xxl),
                      TranscriptView(entry: entry, busy: busy),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AppTopBar(
                  actions: [
                    AppMenuButton(
                      icon: AppIcons.ellipsis,
                      color: theme.topBar.iconColor,
                      items: [
                        AppMenuItem(label: l10n.rename, icon: AppIcons.textformat),
                        AppMenuItem(label: l10n.retranscribe, icon: AppIcons.arrowCounterclockwise),
                        AppMenuItem(label: l10n.delete, icon: AppIcons.trash, destructive: true),
                      ],
                      onSelected: (index) => _onAction(index, entry, l10n),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The reeed-style inline rename: the title IS a borderless text field in the
/// title's own type, always editable in place. Focus to edit; losing focus
/// commits, and clearing it (or typing the date default back) resets to
/// untitled.
class _TitleField extends StatefulWidget {
  const _TitleField({required this.entry, required this.focusNode});

  final Entry entry;
  final FocusNode focusNode;

  @override
  State<_TitleField> createState() => _TitleFieldState();
}

class _TitleFieldState extends State<_TitleField> {
  late final TextEditingController _controller = TextEditingController(
    text: entryDisplayTitle(widget.entry),
  );
  EntriesCubit? _entries;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Captured for the unmount commit path, where context lookups are illegal.
    _entries = context.read<EntriesCubit>();
  }

  @override
  void deactivate() {
    // A pop while the field is focused never delivers the blur notification;
    // without this, the typed title would silently vanish with the screen.
    if (widget.focusNode.hasFocus) _commit();
    super.deactivate();
  }

  @override
  void didUpdateWidget(_TitleField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reflect an external change (a commit round-trip) unless mid-edit.
    if (!widget.focusNode.hasFocus && oldWidget.entry != widget.entry) {
      _controller.text = entryDisplayTitle(widget.entry);
    }
  }

  void _onFocusChange() {
    if (!widget.focusNode.hasFocus) _commit();
  }

  void _commit() {
    final trimmed = _controller.text.trim();
    final untitledDefault = entryDisplayTitle(widget.entry.withTitle(null));
    final cleared = trimmed.isEmpty || trimmed == untitledDefault;
    if (cleared && widget.entry.title == null) {
      // Nothing changed; just restore the default text.
      _controller.text = untitledDefault;
      return;
    }
    if (!cleared && trimmed == widget.entry.title) return;
    _entries?.rename(widget.entry, cleared ? null : trimmed);
    if (cleared) _controller.text = untitledDefault;
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return EditableText(
      controller: _controller,
      focusNode: widget.focusNode,
      style: AppType.display2.copyWith(color: theme.text),
      cursorColor: theme.accent,
      backgroundCursorColor: theme.textSecondary,
      selectionColor: theme.accent.withValues(alpha: 0.25),
      keyboardAppearance: theme.brightness,
      textInputAction: TextInputAction.done,
      maxLines: null,
      onSubmitted: (_) => widget.focusNode.unfocus(),
    );
  }
}
