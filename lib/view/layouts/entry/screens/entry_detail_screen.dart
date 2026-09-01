import 'dart:async';

import 'package:flutter/services.dart' show TextInputAction;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:opentranscribe/core/app/deps.dart';
import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/routes/routes.dart';
import 'package:opentranscribe/core/state/entries_cubit.dart';
import 'package:opentranscribe/core/state/player_cubit.dart';
import 'package:opentranscribe/core/state/recorder_cubit.dart';
import 'package:opentranscribe/core/state/settings_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/app_motion.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/layouts/entry/components/entry_export_sheet.dart';
import 'package:opentranscribe/view/layouts/entry/components/revision_history_sheet.dart';
import 'package:opentranscribe/view/layouts/entry/components/transcribe_error_sheet.dart';
import 'package:opentranscribe/view/layouts/entry/components/wave_player.dart';
import 'package:opentranscribe/view/layouts/entry/components/transcript_view.dart';
import 'package:opentranscribe/view/widgets/app_button.dart';
import 'package:opentranscribe/view/widgets/app_menu.dart';
import 'package:opentranscribe/view/widgets/error_pill.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/app_dropdown.dart';
import 'package:opentranscribe/view/widgets/app_top_bar.dart';
import 'package:opentranscribe/view/widgets/formatting.dart';
import 'package:opentranscribe/view/widgets/locale_names.dart';
import 'package:opentranscribe/view/widgets/glass_fab.dart';
import 'package:opentranscribe/view/widgets/selectable_prose.dart';

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

/// Whether the entry offers to be continued: no live edit and no action on it.
bool continueRowVisible({required bool editing, required bool busy}) => !editing && !busy;

class _DetailView extends StatefulWidget {
  const _DetailView({required this.entryId});

  final String entryId;

  @override
  State<_DetailView> createState() => _DetailViewState();
}

class _DetailViewState extends State<_DetailView> {
  final FocusNode _titleFocus = FocusNode();

  /// The reading region's selection focus. Unfocusing it clears a live
  /// selection, so a re-transcribe can drop one before the ink capture.
  final FocusNode _selectionFocus = FocusNode();

  /// The edit mode's field over the transcript body; blur commits, like the
  /// title.
  final FocusNode _bodyFocus = FocusNode();
  final TextEditingController _bodyController = TextEditingController();
  bool _editing = false;

  /// The bar's menu button, which the Transcribe-in dropdown anchors to (the
  /// menu that offered the action grew from the same spot).
  final GlobalKey _menuAnchor = GlobalKey();
  PlayerCubit? _player;
  EntriesCubit? _entries;

  /// Set once the entry loses its audio while this screen is open, so the
  /// stop below fires exactly once.
  bool _stoppedForDiscard = false;

  /// The file the player is bound to; a landing replaces it under the screen.
  ({String path, Duration duration})? _bound;

  @override
  void initState() {
    super.initState();
    _bodyFocus.addListener(_onBodyFocusChange);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Captured here because dispose() must not look the cubits up via context.
    _player = context.read<PlayerCubit>();
    _entries = context.read<EntriesCubit>();
  }

  @override
  void deactivate() {
    // A pop while the body field is focused never delivers the blur
    // notification; without this, the typed edit would vanish with the screen.
    if (_bodyFocus.hasFocus) _commitEdit(leave: false);
    super.deactivate();
  }

  @override
  void dispose() {
    // Leaving the screen silences playback; the cubit closes with the provider.
    _player?.stopAndDetach();
    _titleFocus.dispose();
    _selectionFocus.dispose();
    _bodyFocus.removeListener(_onBodyFocusChange);
    _bodyFocus.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  /// Enters the edit mode over the current readable text; the field takes
  /// focus once the swap has painted, so the caret never lands in a dead tree.
  /// [selectedText] carries the reading region's selection into the field, so
  /// an edit begun from selected words starts with those words selected.
  void _startEditing(Entry entry, {String? selectedText}) {
    _selectionFocus.unfocus();
    final text = entry.readableText ?? '';
    _bodyController.text = text;
    if (selectedText != null) {
      final start = text.indexOf(selectedText);
      if (start >= 0) {
        _bodyController.selection = TextSelection(
          baseOffset: start,
          extentOffset: start + selectedText.length,
        );
      }
    }
    setState(() => _editing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _bodyFocus.requestFocus();
    });
  }

  /// The selection toolbar's Edit: the same gate as the menu row, walked at
  /// tap time because a toolbar can outlive the state it was built over.
  void _editFromSelection(Entry entry, String? selectedText) {
    final entriesState = context.read<EntriesCubit>().state;
    if (entry.readableText != null && !_runOn(entry, entriesState) && !_editing) {
      _startEditing(entry, selectedText: selectedText);
    }
  }

  /// A run whose landing will rewrite the words: a re-transcribe or a
  /// continuation. Either one shadows an edit opened under it.
  static bool _runOn(Entry entry, EntriesState state) =>
      state.busyId == entry.id &&
      (state.busyAction == EntriesAction.transcribe ||
          state.busyAction == EntriesAction.continueRecording);

  void _onBodyFocusChange() {
    if (!_bodyFocus.hasFocus) _commitEdit();
  }

  /// Commits the typed text and leaves the mode; the pop path commits with
  /// [leave] false, since a dying tree has no mode left to leave. The service
  /// owns the verdict: trim, push onto the history, nothing written on a
  /// blank or unchanged commit. The entry is looked up fresh so a commit
  /// racing a delete quietly drops instead of resurrecting a ghost.
  void _commitEdit({bool leave = true}) {
    if (!_editing) return;
    final entries = _entries;
    var write = Future<void>.value();
    if (entries != null) {
      final matches = entries.state.entries.where((e) => e.id == widget.entryId);
      if (matches.isNotEmpty) write = entries.edit(matches.first, _bodyController.text);
    }
    if (!leave) return;
    // The mode ends once the write has landed in the list, so the reader
    // never sees the pre-edit words flash between the two.
    unawaited(
      write.whenComplete(() {
        if (mounted) setState(() => _editing = false);
      }),
    );
  }

  /// Starts a re-transcribe after dropping any live selection, one frame later
  /// so the cleared paragraph paints before the shimmer grabs its last frame: a
  /// selection left standing would bake its highlight wash into the ink. No
  /// confirm: the landing pushes the replaced words into history, so nothing
  /// is destroyed. A live edit still blocks the door (its rows are hidden;
  /// only a stale menu can ask), so a run never lands under the open field.
  void _startRetranscribe(EntriesCubit entries, Entry entry, {String? localeId}) {
    if (_editing) return;
    _selectionFocus.unfocus();
    WidgetsBinding.instance.endOfFrame.then((_) {
      if (mounted) unawaited(entries.retranscribe(entry, localeId: localeId));
    });
  }

  /// Action row ids: the list shrinks when an entry loses its audio, and a
  /// menu opened before that rebuild still shows the old rows, so a position
  /// can land on the wrong action. An id names the choice itself; only the
  /// Transcribe-in parent answers by position (a parent with children never
  /// answers by id), and the dispatcher checks it is really the parent.
  static const _actRename = 'act:rename';
  static const _actEdit = 'act:edit';
  static const _actHistory = 'act:history';
  static const _actExport = 'act:export';
  static const _actContinue = 'act:continue';
  static const _actRetranscribe = 'act:retranscribe';
  static const _actDelete = 'act:delete';
  static const _actionIds = {
    _actRename,
    _actEdit,
    _actHistory,
    _actExport,
    _actContinue,
    _actRetranscribe,
    _actDelete,
  };

  /// Marks the entry busy and raises the recorder over this screen; the
  /// service's outcome clears the mark whatever the take's ending.
  void _startContinuation(Entry entry) {
    if (_editing) return;
    final entries = context.read<EntriesCubit>();
    if (!entries.markContinuing(entry)) return;
    _selectionFocus.unfocus();
    unawaited(_player?.silence());
    context.pushNamed(Routes.recordName, queryParameters: {Routes.recordEntryQuery: entry.id});
  }

  /// The history flow: the history sheet shows every revision with its change
  /// inline, and a tapped one comes back as the head. The service resolves
  /// the STORED entry, and restoring what the entry already reads as writes
  /// nothing, so a stale sheet cannot do harm.
  Future<void> _openHistory(Entry entry) async {
    final entries = context.read<EntriesCubit>();
    final picked = await showRevisionHistorySheet(context, entry);
    if (picked != null && mounted) unawaited(entries.restore(entry, picked));
  }

  List<AppMenuItem> _menuItems(
    Entry entry,
    AppLocalizations l10n,
    List<String> transcribeTags,
    String preselected, {
    required bool anyAction,
    required bool canContinue,
    required bool editing,
  }) => [
    AppMenuItem(id: _actRename, label: l10n.rename, icon: AppIcons.textformat),
    // Editing corrects words that exist; a never-transcribed entry has none
    // (its action is the bottom CTA), and a run in flight would land words
    // the open field could then silently shadow. While the field is up the
    // row is gone too: re-entering would re-seed the field and eat the words.
    if (entry.readableText != null && !anyAction && !editing)
      AppMenuItem(id: _actEdit, label: l10n.editTranscript, icon: AppIcons.pencil),
    // History stands whenever the entry reads as any words, empty history
    // included: the sheet then shows the original transcription alone. A
    // silent transcript reads as none, and would only open a sheet with
    // nothing to stand in. Mid-edit it hides (a restore under the open field
    // would be shadowed by its commit), and mid-run too: a landing would
    // date the open sheet.
    if ((entry.readableText?.trim().isNotEmpty ?? false) && !editing && !anyAction)
      AppMenuItem(id: _actHistory, label: l10n.revisionHistory, icon: AppIcons.clockHistory),
    AppMenuItem(id: _actExport, label: l10n.exportEntry, icon: AppIcons.squareAndArrowUp),
    if (continueRowVisible(editing: editing, busy: !canContinue))
      AppMenuItem(id: _actContinue, label: l10n.continueRecording, icon: AppIcons.mic),
    // Hidden while editing: the Edit gate's shadowing, other direction (the
    // run starts under the field instead of before it).
    if (entry.hasAudio && !editing) ...[
      AppMenuItem(
        id: _actRetranscribe,
        label: l10n.retranscribe,
        icon: AppIcons.arrowCounterclockwise,
      ),
      AppMenuItem(
        label: l10n.transcribeIn,
        icon: AppIcons.globe,
        // Native renders these as a nested UIMenu; the fallback fires the
        // parent action instead and the anchored dropdown takes over. Ids,
        // not positions: the chosen language must survive a list rebuild
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
    ],
    if (!anyAction)
      AppMenuItem(id: _actDelete, label: l10n.delete, icon: AppIcons.trash, destructive: true),
  ];

  /// Handles every id answer: the action rows and the language leaves.
  /// The audio-dependent ones re-check [Entry.hasAudio] so a tap on a stale
  /// open menu (the discard landed while it was up) is a no-op, never a wrong
  /// action on a transcript-only entry.
  void _onMenuId(String id, Entry entry) {
    // Anything act:-prefixed is an action row; an unknown one must never fall
    // through to the language branch and re-transcribe with a bogus locale.
    if (id.startsWith('act:') && !_actionIds.contains(id)) return;
    switch (id) {
      case _actRename:
        _titleFocus.requestFocus();
      case _actEdit:
        // Re-checked like the audio actions: the menu may have outlived the
        // state it offered to edit (a transcript gone, a run since started).
        final entriesState = context.read<EntriesCubit>().state;
        if (entry.readableText != null && !_runOn(entry, entriesState) && !_editing) {
          _startEditing(entry);
        }
      case _actHistory:
        // Same stale-menu rule: only an entry with a text state has anything
        // to show, and never under a live edit or an in-flight run.
        final historyState = context.read<EntriesCubit>().state;
        if ((entry.readableText?.trim().isNotEmpty ?? false) &&
            !_editing &&
            !_runOn(entry, historyState)) {
          unawaited(_openHistory(entry));
        }
      case _actExport:
        unawaited(showEntryExportSheet(context, entry));
      case _actContinue:
        _startContinuation(entry);
      case _actRetranscribe:
        // Runs in the entry's OWN language (the service resolves it); the
        // language leaves below are the explicit override.
        if (entry.hasAudio) _startRetranscribe(context.read<EntriesCubit>(), entry);
      case _actDelete:
        // Straight through, no confirm. The menu already took a deliberate tap
        // to open and a second one to land on a row marked destructive; a sheet
        // asking the same question again is a tax on every deliberate delete to
        // catch the accidental one.
        unawaited(context.read<EntriesCubit>().delete(entry));
      default:
        // A language leaf; its id is the tag itself.
        if (entry.hasAudio) {
          _startRetranscribe(context.read<EntriesCubit>(), entry, localeId: id);
        }
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

    final anchor = dropdownAnchorRect(_menuAnchor, context);
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
    if (!mounted) return;
    _startRetranscribe(entries, entry, localeId: tags[index]);
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

        // Audio discarded while this screen is open (a keep-off transcription
        // landing): the player is about to unmount, so playback must die with
        // it, not keep sounding from a deleted file with no controls left.
        if (!entry.hasAudio && !_stoppedForDiscard) {
          _stoppedForDiscard = true;
          unawaited(_player?.rebind());
        }
        // A continuation can give it a recording back; the next discard must
        // silence playback again.
        if (entry.hasAudio) _stoppedForDiscard = false;
        // A landing replaced the file; the keyed wave below reads the new one.
        final bound = _bound;
        final path = entry.audioPath;
        if (bound != null && path != null && path != bound.path) {
          final grown = entry.duration > bound.duration && bound.duration > Duration.zero;
          unawaited(
            _player?.rebind(
              keep: grown ? bound.duration.inMicroseconds / entry.duration.inMicroseconds : null,
            ),
          );
        }
        _bound = path == null ? null : (path: path, duration: entry.duration);
        // Transcribe only: a delete is also an in-flight action on this id, but
        // it must not dissolve the transcript or flash the loader on its way out.
        final busy = state.busyId == entry.id && state.busyAction == EntriesAction.transcribe;
        // A take extending this entry, live or landing: the words stay and a
        // quiet wait sits under them.
        final continuing =
            state.busyId == entry.id && state.busyAction == EntriesAction.continueRecording;
        // The entry's own language, once known: the quiet answer to "what
        // will Re-transcribe run in".
        final language = entry.effectiveLocaleId;
        // The bottom CTA exists for a never-transcribed entry; a run in flight
        // disables it in place rather than unmounting it, so a failed run
        // never blinks the button away and back. Transcribing needs the audio,
        // so a transcript-only entry offers neither the CTA nor a retry.
        final showCta = entry.transcript == null && entry.hasAudio;
        // This entry's own failure, if any. It rides the bottom dock above the
        // CTA, pulsing until the user acts on it - never a snackbar.
        // Transcribing needs the audio, so its failures hide without it; a
        // continuation's own endings show either way.
        final kind = state.errorFor(entry.id);
        final continuationEnding =
            kind == EntriesError.savedSeparately || kind == EntriesError.additionUntranscribed;
        final error = entry.hasAudio || continuationEnding ? kind : null;
        final bottomInset = MediaQuery.paddingOf(context).bottom;
        // The keyboard's height while the edit field is up, so the caret can
        // always scroll clear of it; zero the rest of the time.
        final keyboard = MediaQuery.viewInsetsOf(context).bottom;
        // What the scroll must clear so its last line never hides behind the
        // pinned dock: the pill, the CTA, and the gap between them, whichever
        // are present.
        // Zero while editing: the dock is gone then, so its one door into a
        // re-transcribe (the pill's retry) cannot open under a live edit.
        final dockHeight = _editing
            ? 0.0
            : (error != null ? theme.errorPill.height : 0.0) +
                  (error != null && showCta ? AppSpacing.md : 0.0) +
                  (showCta ? theme.button.height : 0.0);
        // Clear the pinned dock when it shows, so the last line can never
        // hide behind it; otherwise just the home indicator.
        final restingBottom = dockHeight > 0
            ? bottomInset + AppSpacing.xl + dockHeight + AppSpacing.xxxl
            : bottomInset + AppSpacing.xxxl;
        return ColoredBox(
          color: theme.screens.entryDetail,
          child: Stack(
            children: [
              // ONE document: title, what it is, how it sounds, what it says -
              // in that order, on one scroll. The player goes with it rather
              // than pinning to the floor, so the transcript reads as a page
              // and not as text squeezed between two bars.
              Positioned.fill(
                child: SelectableProse(
                  focusNode: _selectionFocus,
                  // The toolbar's road into the editor: with words selected it
                  // opens on them; bare, it just opens.
                  editLabel: entry.readableText == null ? null : l10n.editTranscript,
                  onEdit: entry.readableText == null
                      ? null
                      : (selected) => _editFromSelection(entry, selected),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      // Past the bar AND its fade tail: the material is opaque
                      // through the row and only melts across the tail, so
                      // content starting inside it would sit under the wash.
                      AppTopBar.heightOf(context) + theme.topBar.fadeTail,
                      AppSpacing.xl,
                      keyboard + restingBottom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TitleField(entry: entry, focusNode: _titleFocus),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          '${DateFormat.yMMMMd(localeTag(context)).format(entry.createdAt.toLocal())}'
                          ' \u00b7 ${formatTime(entry.createdAt, localeTag(context))}'
                          ' \u00b7 ${formatClock(entry.duration)}'
                          '${language == null ? '' : ' \u00b7 ${localeDisplayName(language)}'}'
                          // Hand-written words are never passed off as heard.
                          '${entry.readsAsTranscript ? '' : ' \u00b7 ${l10n.editedMarker}'}',
                          style: AppType.digits(
                            AppType.footnote,
                          ).copyWith(color: theme.textSecondary),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        // Discarded audio: the document flows from the metadata
                        // straight into what it says. Animated, so a discard
                        // landing mid-read collapses the player instead of
                        // snapping ~80px of layout in one frame.
                        AnimatedSize(
                          duration: context.reduceMotion
                              ? AppMotion.instant
                              : context.motionNow.indicator,
                          curve: context.motionNow.indicatorCurve,
                          alignment: Alignment.topCenter,
                          // The switcher fades the wave out while the size eases
                          // the gap closed, so nothing hard-cuts mid-read.
                          child: AnimatedSwitcher(
                            duration: context.reduceMotion
                                ? Duration.zero
                                : context.motionNow.indicator,
                            child: !entry.hasAudio
                                ? const SizedBox(width: double.infinity)
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      WavePlayer(key: ValueKey(entry.audioPath), entry: entry),
                                      const SizedBox(height: AppSpacing.xxl),
                                    ],
                                  ),
                          ),
                        ),
                        // The edit mode: the same body type in the same seat, so
                        // entering it moves no text. The service judges the
                        // commit; this widget only hands the words over. Fenced
                        // out of the reading region, whose long-press must not
                        // contest the field's own gestures.
                        if (_editing)
                          SelectionContainer.disabled(
                            child: EditableText(
                              controller: _bodyController,
                              focusNode: _bodyFocus,
                              style: AppType.body.copyWith(color: theme.text),
                              cursorColor: theme.accent,
                              backgroundCursorColor: theme.textSecondary,
                              selectionColor: theme.accent.withValues(alpha: 0.25),
                              keyboardAppearance: theme.brightness,
                              maxLines: null,
                            ),
                          )
                        else
                          // The take's live words stay on the recorder cubit
                          // until its stop settles; only the transcript
                          // follows them.
                          BlocSelector<RecorderCubit, RecorderState, String>(
                            selector: (recorder) => continuing ? recorder.liveText : '',
                            builder: (context, pending) => TranscriptView(
                              entry: entry,
                              busy: busy,
                              appending: continuing,
                              pendingText: pending,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AppTopBar(
                  actions: [
                    // Settings feed only the menu, so a model install's
                    // progress emits rebuild this button, not the document.
                    BlocBuilder<SettingsCubit, SettingsState>(
                      builder: (context, settings) {
                        final transcribeTags = _transcribeTags(entry, settings);
                        final preselected = language ?? settings.localeId;
                        final menu = _menuItems(
                          entry,
                          l10n,
                          transcribeTags,
                          preselected,
                          anyAction: state.busyId == entry.id,
                          canContinue: context.read<EntriesCubit>().canContinue(entry),
                          editing: _editing,
                        );
                        return AppMenuButton(
                          key: _menuAnchor,
                          icon: AppIcons.ellipsis,
                          color: theme.topBar.iconColor,
                          items: menu,
                          // Only the Transcribe-in parent answers by position; a
                          // stale index from a menu that outlived a rebuild is
                          // dropped rather than landing on another row.
                          onSelected: (index) {
                            if (index < 0 || index >= menu.length) return;
                            if (menu[index].children.isEmpty) return;
                            unawaited(_transcribeIn(entry));
                          },
                          onSelectedId: (id) => _onMenuId(id, entry),
                        );
                      },
                    ),
                  ],
                ),
              ),
              // The edit mode's save floats where home's record button does,
              // riding the keyboard; unfocusing commits through the blur
              // listener. The check runs well under the waveform's 26: its
              // ink box is wide for its point size.
              if (_editing)
                Positioned(
                  right: AppSpacing.xl,
                  bottom: (keyboard > 0 ? keyboard : bottomInset) + AppSpacing.xl,
                  child: GlassFab(
                    icon: AppIcons.checkmark,
                    iconSize: 18,
                    onTap: _bodyFocus.unfocus,
                  ),
                ),
              // The pinned dock: the error indicator over the Transcribe CTA,
              // both clear of the document. Either may be absent; the scroll
              // reserves exactly their room so neither covers content.
              if (!_editing && (error != null || showCta))
                _BottomDock(
                  entry: entry,
                  error: error,
                  errorTick: state.errorTick,
                  relatedId: state.error?.relatedId,
                  showCta: showCta,
                  busy: state.busyId == entry.id,
                  onOpenRelated: (id) =>
                      context.pushNamed(Routes.entryName, pathParameters: {'id': id}),
                  // Through the screen's one door, so a dock action gets the
                  // same selection drop and live-edit guard as the menu rows.
                  onTranscribe: () => _startRetranscribe(context.read<EntriesCubit>(), entry),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The screen's floor: a failure indicator that opens its details on tap, over
/// the never-transcribed entry's one action. Whichever is present sits full
/// width above the home indicator; when both show, the error rides above the
/// button so the fix and the retry read top to bottom.
class _BottomDock extends StatelessWidget {
  const _BottomDock({
    required this.entry,
    required this.error,
    required this.errorTick,
    required this.relatedId,
    required this.showCta,
    required this.busy,
    required this.onTranscribe,
    required this.onOpenRelated,
  });

  final Entry entry;
  final EntriesError? error;
  final int errorTick;

  /// The entry a take became when it could not land here; the pill opens it.
  final String? relatedId;
  final bool showCta;
  final bool busy;
  final ValueChanged<String> onOpenRelated;

  /// Both the retry and the CTA run through the screen's one re-transcribe
  /// door rather than reaching the cubit themselves, so a dock action gets
  /// the same selection drop and live-edit guard as the menu rows.
  final VoidCallback onTranscribe;

  Future<void> _openDetails(BuildContext context, EntriesError kind) async {
    final related = relatedId;
    final entries = context.read<EntriesCubit>();
    final exists = related != null && entries.state.entries.any((e) => e.id == related);
    if (kind == EntriesError.savedSeparately && exists) {
      entries.dismissFailure(entry.id);
      onOpenRelated(related);
      return;
    }
    final retry = await showTranscribeErrorSheet(context, kind);
    if (retry) {
      onTranscribe();
      return;
    }
    // Acknowledged, with no retry to clear it later.
    if (kind == EntriesError.savedSeparately) entries.dismissFailure(entry.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final kind = error;
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (kind != null)
              // Keyed by the tick: a repeat of the same failure remounts the
              // pill, so its announcing shake plays again.
              ErrorPill(
                key: ValueKey(errorTick),
                message: _pillLabel(kind, l10n),
                onTap: () => _openDetails(context, kind),
              ),
            if (kind != null && showCta) const SizedBox(height: AppSpacing.md),
            if (showCta) AppButton(label: l10n.transcribe, onPressed: busy ? null : onTranscribe),
          ],
        ),
      ),
    );
  }
}

/// The short label the error pill carries; the sheet behind it tells the rest.
String _pillLabel(EntriesError kind, AppLocalizations l10n) => switch (kind) {
  EntriesError.permissionDenied => l10n.transcribeErrorLabelPermission,
  EntriesError.onDeviceUnavailable => l10n.transcribeErrorLabelUnavailable,
  EntriesError.modelInstallFailed => l10n.transcribeErrorLabelModelInstall,
  EntriesError.reservationCap => l10n.transcribeErrorLabelCapReached,
  EntriesError.additionUntranscribed => l10n.continueUntranscribedLabel,
  EntriesError.savedSeparately => l10n.continueSavedSeparatelyLabel,
  EntriesError.generic => l10n.transcribeErrorLabelGeneric,
};

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
    text: entryDisplayTitle(widget.entry, localeTag(context)),
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
      _controller.text = entryDisplayTitle(widget.entry, localeTag(context));
    }
  }

  void _onFocusChange() {
    if (!widget.focusNode.hasFocus) _commit();
  }

  void _commit() {
    final trimmed = _controller.text.trim();
    final untitledDefault = entryDisplayTitle(widget.entry.withTitle(null), localeTag(context));
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
