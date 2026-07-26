import 'dart:async';

import 'package:flutter/services.dart' show TextInputAction;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:opentranscribe/core/app/deps.dart';
import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/state/entries_cubit.dart';
import 'package:opentranscribe/core/state/player_cubit.dart';
import 'package:opentranscribe/core/state/settings_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/layouts/entry/components/wave_player.dart';
import 'package:opentranscribe/view/layouts/entry/components/transcript_view.dart';
import 'package:opentranscribe/view/widgets/app_button.dart';
import 'package:opentranscribe/view/widgets/app_menu.dart';
import 'package:opentranscribe/view/widgets/app_notice.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/app_dropdown.dart';
import 'package:opentranscribe/view/widgets/app_top_bar.dart';
import 'package:opentranscribe/view/widgets/formatting.dart';
import 'package:opentranscribe/view/widgets/locale_names.dart';

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

  /// The bar's menu button, which the Transcribe-in dropdown anchors to (the
  /// menu that offered the action grew from the same spot).
  final GlobalKey _menuAnchor = GlobalKey();
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
        // Runs in the entry's OWN language (the service resolves it); the
        // picker below is the explicit override.
        context.read<EntriesCubit>().retranscribe(entry);
      case 2:
        _transcribeIn(entry);
      case 3:
        // Straight through, no confirm. The menu already took a deliberate tap
        // to open and a second one to land on a row marked destructive; a sheet
        // asking the same question again is a tax on every deliberate delete to
        // catch the accidental one.
        context.read<EntriesCubit>().delete(entry);
    }
  }

  /// The languages an entry may be (re-)transcribed in: the entry's own, the
  /// app default, and every ready language (without a reservation concept,
  /// pre-26, every supported language works with no install). The service
  /// default closes the cold-start hole where settings state is still empty.
  List<String> _transcribeTags(Entry entry, SettingsState settings) {
    final tags = <String>[
      // The entry's own language leads, even when its model is gone.
      if (entry.effectiveLocaleId != null) entry.effectiveLocaleId!,
      ...settings.selectableLanguageTags(),
      // Cold start (settings state still empty): the service default still
      // names one language to offer rather than a menu that does nothing.
      Deps.i.transcriptionService.localeId,
    ];
    final unique = <String>[];
    for (final tag in tags) {
      if (tag.isNotEmpty && !unique.contains(tag)) unique.add(tag);
    }
    return unique;
  }

  /// The wrong-language correction on the FALLBACK path: the app's anchored
  /// dropdown out of the menu button. On native glass the menu itself carries
  /// the languages as a real submenu, and this is never called.
  Future<void> _transcribeIn(Entry entry) async {
    final settings = context.read<SettingsCubit>().state;
    final entries = context.read<EntriesCubit>();
    final tags = _transcribeTags(entry, settings);

    // Anchor to the menu button that offered the action; if it is somehow
    // gone (a rebuilt bar), a top-right stand-in keeps the growth corner.
    final box = _menuAnchor.currentContext?.findRenderObject();
    final screen = MediaQuery.sizeOf(context);
    final anchor = box is RenderBox && box.attached
        ? box.localToGlobal(Offset.zero) & box.size
        : Rect.fromLTWH(screen.width - 60, MediaQuery.paddingOf(context).top, 44, 44);

    final preselected = entry.effectiveLocaleId ?? settings.localeId;
    final index = await showAppDropdown(
      context,
      anchor: anchor,
      items: [
        for (final tag in tags)
          AppDropdownItem(
            label: localeDisplayName(tag),
            flag: localeFlag(tag),
            selected: tag == preselected,
          ),
      ],
    );
    if (index == null) return;
    unawaited(entries.retranscribe(entry, localeId: tags[index]));
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
        // The entry's own language, once known: the quiet answer to "what
        // will Re-transcribe run in".
        final language = entry.effectiveLocaleId;
        // For the Transcribe-in choices: a real submenu on the native menu,
        // the anchored dropdown on the fallback (see _transcribeIn).
        final settings = context.watch<SettingsCubit>().state;
        final transcribeTags = _transcribeTags(entry, settings);
        final preselected = entry.effectiveLocaleId ?? settings.localeId;
        // The bottom CTA only exists for a never-transcribed entry, and not
        // while a run is in flight (the body shows the spinner then).
        final showCta = entry.transcript == null && !busy;
        final bottomInset = MediaQuery.paddingOf(context).bottom;
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
                    // Clear the pinned CTA when it shows, so the last line can
                    // never hide behind it; otherwise just the home indicator.
                    showCta
                        ? bottomInset + AppSpacing.xl + theme.button.height + AppSpacing.xxxl
                        : bottomInset + AppSpacing.xxxl,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // A failure the screen could not prevent (a transcribe or
                      // rename that did not take), inline at the top and gone on
                      // its own - no dialog. Scoped: only THIS entry's failure
                      // renders here, never another entry's leftover.
                      AppNotice(
                        message: _errorMessage(state.errorFor(entry.id), l10n),
                        onDismiss: () => context.read<EntriesCubit>().clearError(),
                      ),
                      _TitleField(entry: entry, focusNode: _titleFocus),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        '${DateFormat.yMMMMd().format(entry.createdAt.toLocal())}'
                        ' \u00b7 ${formatTime(entry.createdAt)}'
                        ' \u00b7 ${formatClock(entry.duration)}'
                        '${language == null ? '' : ' \u00b7 ${localeDisplayName(language)}'}',
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
                      key: _menuAnchor,
                      icon: AppIcons.ellipsis,
                      color: theme.topBar.iconColor,
                      items: [
                        AppMenuItem(label: l10n.rename, icon: AppIcons.textformat),
                        AppMenuItem(label: l10n.retranscribe, icon: AppIcons.arrowCounterclockwise),
                        AppMenuItem(
                          label: l10n.transcribeIn,
                          icon: AppIcons.globe,
                          // Native renders these as a nested UIMenu; the
                          // fallback fires the parent action instead and the
                          // anchored dropdown takes over. Ids, not positions:
                          // the chosen language must survive a list rebuild
                          // under the open menu.
                          children: [
                            for (final tag in transcribeTags)
                              AppMenuItem(
                                id: tag,
                                label: '${localeFlag(tag)}  ${localeDisplayName(tag)}',
                                selected: tag == preselected,
                              ),
                          ],
                        ),
                        AppMenuItem(label: l10n.delete, icon: AppIcons.trash, destructive: true),
                      ],
                      onSelected: (index) => _onAction(index, entry, l10n),
                      onSelectedId: (tag) => unawaited(
                        context.read<EntriesCubit>().retranscribe(entry, localeId: tag),
                      ),
                    ),
                  ],
                ),
              ),
              // A never-transcribed entry gets its one action as a bottom CTA,
              // clear of the document above it.
              if (showCta) _TranscribeCta(entry: entry),
            ],
          ),
        );
      },
    );
  }
}

/// Words an [EntriesError] for the notice line. The kinds are the contract;
/// the raw platform error never reaches the screen.
String? _errorMessage(EntriesError? error, AppLocalizations l10n) => switch (error) {
  null => null,
  EntriesError.permissionDenied => l10n.transcribeErrorPermission,
  EntriesError.onDeviceUnavailable => l10n.transcribeErrorUnavailable,
  EntriesError.modelInstallFailed => l10n.transcribeErrorModelInstall,
  EntriesError.reservationCap => l10n.transcribeErrorCapReached,
  EntriesError.generic => l10n.transcribeErrorGeneric,
};

/// The never-transcribed entry's one action, pinned to the screen's floor as a
/// full-width CTA over the scrolling document. The scroll reserves room for it,
/// so it never covers content.
class _TranscribeCta extends StatelessWidget {
  const _TranscribeCta({required this.entry});

  final Entry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          MediaQuery.paddingOf(context).bottom + AppSpacing.xl,
        ),
        child: AppButton(
          label: l10n.transcribe,
          onPressed: () => context.read<EntriesCubit>().retranscribe(entry),
        ),
      ),
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
