import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:opentranscribe/core/state/entries_cubit.dart';
import 'package:opentranscribe/core/state/home_cubit.dart';
import 'package:opentranscribe/core/state/recorder_cubit.dart';
import 'package:opentranscribe/core/state/settings_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/app_icons.dart';
import 'package:opentranscribe/core/theming/app_motion.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/utils/haptics.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/layouts/recorder/components/continuing_line.dart';
import 'package:opentranscribe/view/layouts/recorder/components/live_transcript.dart';
import 'package:opentranscribe/view/layouts/recorder/components/recorder_controls.dart';
import 'package:opentranscribe/view/layouts/recorder/components/waveform.dart';
import 'package:opentranscribe/view/widgets/app_button.dart';
import 'package:opentranscribe/view/widgets/app_notice.dart';
import 'package:opentranscribe/view/widgets/app_top_bar.dart';
import 'package:opentranscribe/view/widgets/empty_state.dart';
import 'package:opentranscribe/view/widgets/language_menu_button.dart';
import 'package:opentranscribe/view/widgets/rolling_text.dart';

/// The one margin this screen repeats: the band, the transcript and the
/// controls all sit on it, so a single edge runs down the page.
const double _columnInset = AppSpacing.xxxl + AppSpacing.sm;

/// The recording surface: the clock alone in the top bar, live waveform and
/// transcript centered, and one row of four circles along the bottom carrying
/// every way out - close, restart, complete, pause. Recording starts when the
/// sheet opens. Both exits keep the take and close onto the journal without
/// waiting for the save; only restart, which throws speech away, confirms
/// first. A denied microphone renders as a persistent in-screen state, not a
/// dialog.
class RecorderScreen extends StatefulWidget {
  const RecorderScreen({super.key, this.continueEntryId});

  /// The entry this take extends, from the route's query; null for a fresh take.
  final String? continueEntryId;

  @override
  State<RecorderScreen> createState() => _RecorderScreenState();
}

class _RecorderScreenState extends State<RecorderScreen> {
  Animation<double>? _entrance;

  @override
  void initState() {
    super.initState();
    // Synchronously, before the first frame: the previous take's stop may
    // still be finalizing behind its popped sheet, and this sheet must not
    // open wearing that take's text and clock while it waits for start().
    context.read<RecorderCubit>().prepareTake();
    // Opening the microphone is a platform round trip that blocks the UI
    // thread (session category, activation, engine start), so it waits until
    // the sheet has LANDED. Done during the rise it eats the frames of the
    // very transition that is meant to feel instant.
    WidgetsBinding.instance.addPostFrameCallback((_) => _startWhenSettled());
  }

  void _startWhenSettled() {
    if (!mounted) return;
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.isCompleted) {
      _start();
      return;
    }
    _entrance = animation..addStatusListener(_onEntrance);
  }

  void _onEntrance(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _entrance?.removeStatusListener(_onEntrance);
    _entrance = null;
    _start();
  }

  void _start() {
    if (!mounted) return;
    // Unconditionally: the cubit outlives this screen, and it is the only thing
    // that can tell a take genuinely in flight from a state left busy by a
    // previous screen (a save still running behind a popped sheet). Guarding on
    // isBusy here refused to start on exactly the states it knows how to heal,
    // and the screen sat dead with the last take's clock and text on it.
    final cubit = context.read<RecorderCubit>();
    final id = widget.continueEntryId;
    if (id == null) {
      cubit.start();
      return;
    }
    final entries = context.read<EntriesCubit>();
    final entry = entries.state.entries.where((e) => e.id == id).firstOrNull;
    // A stale link records a fresh take; the mark it left has no take to wait for.
    if (entry == null) {
      entries.clearContinuing(id);
      cubit.start();
      return;
    }
    cubit.start(continuing: entry);
  }

  /// Leave, keeping what was said. The sheet closes onto the journal it came
  /// from, never onto the new entry: someone who just stopped talking asked to
  /// stop, not to be handed a screen.
  ///
  /// [keepSilence] is what separates the two ways out. Complete is a deliberate
  /// save and keeps the audio whatever was heard - the batch pass may still read
  /// what the live engine could not. Closing is not: nothing heard means nothing
  /// worth filing, so an X on a silent take discards it.
  void _close({required bool keepSilence}) {
    final cubit = context.read<RecorderCubit>();
    final home = context.read<HomeCubit>();
    final state = cubit.state;
    // What decides discard is whether the MIC heard sound, not whether the live
    // engine transcribed it: the live window can be blank over real speech, and
    // the batch pass on stop still reads it. Gating on live text alone discarded
    // fully-spoken takes whenever live transcription was blank. Live text is kept
    // as a belt-and-suspenders signal (if there is text, there was certainly sound).
    final heardSomething = state.heardSound || state.liveText.trim().isNotEmpty;
    // LEAVE FIRST. Persisting runs the batch pass over the whole take, seconds
    // of it, and nothing on this screen is waiting on the answer: the cubit
    // outlives the route, so the save finishes behind the closing sheet. Home's
    // own refresh fires on the pop, too early to see the new record, so this
    // reloads it again once the save has actually landed.
    context.pop();
    if (!state.isBusy) return;
    final ending = heardSomething || keepSilence ? cubit.stop() : cubit.cancel();
    unawaited(ending.then((_) => home.load()));
  }

  @override
  void dispose() {
    _entrance?.removeStatusListener(_onEntrance);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;

    return ColoredBox(
      color: theme.screens.recorder,
      child: BlocConsumer<RecorderCubit, RecorderState>(
        // Errors are rendered, not announced: permission-denied as a persistent
        // state, a generic failure as an inline notice (below). The one thing
        // worth a one-shot reaction is the microphone actually opening.
        listenWhen: (previous, current) => current.live && !previous.live,
        listener: (context, state) {
          // Capture began. Since it now opens after the sheet lands, this tick
          // is the only thing that says so at the moment it happens.
          Haptics.light();
        },
        // Elapsed ticks and live text are consumed by scoped selectors below;
        // the frame only rebuilds on lifecycle changes.
        buildWhen: (previous, current) =>
            previous.status != current.status ||
            previous.error != current.error ||
            previous.live != current.live ||
            previous.interrupted != current.interrupted ||
            previous.localeId != current.localeId,
        builder: (context, state) {
          final saving = state.status == RecorderStatus.saving;
          final restarting = state.status == RecorderStatus.restarting;
          final denied = state.error == RecorderError.permissionDenied;
          return Column(
            children: [
              AppTopBar(
                centerTitle: true,
                // Nothing but the clock: every way out lives on the control
                // row. Except when the microphone was refused - that screen has
                // no control row, so the way out comes back up here, in the
                // same circle the row would have used.
                leading: denied
                    ? AppIconButton(
                        icon: AppIcons.xmark,
                        size: theme.topBar.largeHeight - AppSpacing.md,
                        onTap: () => _close(keepSilence: false),
                      )
                    : const SizedBox.shrink(),
                title: denied ? null : _Timer(paused: state.isPaused),
                subtitle: denied
                    ? null
                    : _StateLine(
                        label: state.isPaused
                            ? l10n.recordStatePaused
                            : (state.live ? l10n.recordStateRecording : null),
                      ),
                actions: [
                  // Change what THIS take transcribes in, mid-sentence if
                  // needed; the next take starts from the default again.
                  if (!denied && !saving) _LanguageAction(sessionTag: state.localeId),
                ],
              ),
              if (denied)
                Expanded(
                  child: Center(
                    child: EmptyState(
                      icon: AppIcons.mic,
                      title: l10n.recordPermissionTitle,
                      message: l10n.recordPermissionMessage,
                    ),
                  ),
                )
              else ...[
                // Mathematical centre reads low; the block settles just above it.
                const Spacer(flex: 45),
                // From the route, not the state: the take starts after the
                // rise, and the line must not drop in under a settled wave.
                if (widget.continueEntryId != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: _columnInset),
                    child: ContinuingLine(entryId: widget.continueEntryId!),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _columnInset),
                  child: Waveform(
                    // A restart discards the take, and its bars with it; a
                    // pause keeps both.
                    key: ValueKey(state.takeId),
                    levels: context.read<RecorderCubit>().inputLevel,
                    active: state.isRecording,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: _columnInset),
                  child: _LiveText(),
                ),
                const Spacer(flex: 42),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: _columnInset),
                  child: AppNotice(
                    message: switch (state.error) {
                      RecorderError.generic => l10n.recordErrorMessage,
                      RecorderError.entryBusy => l10n.continueEntryBusy,
                      _ => state.interrupted ? l10n.recordInterruptedSaved : null,
                    },
                    onDismiss: () {
                      final cubit = context.read<RecorderCubit>();
                      state.error != null ? cubit.clearError() : cubit.clearInterrupted();
                      // Nothing to record on a refused base: the sheet leaves
                      // with its notice.
                      if (state.error == RecorderError.entryBusy && context.canPop()) {
                        context.pop();
                      }
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(_columnInset, 0, _columnInset, 42),
                  child: RecorderControls(
                    paused: state.isPaused,
                    saving: saving,
                    restarting: restarting,
                    onClose: () => _close(keepSilence: false),
                    onRestart: () => context.read<RecorderCubit>().restart(),
                    onComplete: () => _close(keepSilence: true),
                    onTogglePause: () {
                      final cubit = context.read<RecorderCubit>();
                      state.isPaused ? cubit.resume() : cubit.pause();
                    },
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// The elapsed timer, isolated so a tick repaints only this text. Each second
/// rolls the digit that changed and no other, the quiet metronome: minutes and
/// hours therefore turn rarely, and a restart rolls the whole value back down
/// to zero. Paused, it dims: a clock that merely stopped is indistinguishable
/// from one that hung.
class _Timer extends StatefulWidget {
  const _Timer({required this.paused});

  final bool paused;

  @override
  State<_Timer> createState() => _TimerState();
}

class _TimerState extends State<_Timer> {
  Duration _last = Duration.zero;
  int _direction = 1;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return AnimatedOpacity(
      // Opacity, not a color tween: RollingText rebuilds its whole glyph spec
      // when its style changes, and a dim must not churn a hundred layouts.
      duration: theme.motion.crossfade,
      opacity: widget.paused ? 0.45 : 1,
      child: BlocSelector<RecorderCubit, RecorderState, Duration>(
        selector: (state) => state.elapsed,
        builder: (context, elapsed) {
          if (elapsed != _last) {
            _direction = elapsed > _last ? 1 : -1;
            _last = elapsed;
          }
          return RollingText(
            text: _formatElapsed(elapsed),
            style: AppType.timer.copyWith(color: theme.recorder.timerColor),
            direction: _direction,
          );
        },
      ),
    );
  }
}

/// What the machine is doing, in one word under the timer. Absent until the
/// microphone is actually open, so the screen never claims to be listening
/// before it is; its line is reserved either way, so nothing jumps when the
/// word arrives.
class _StateLine extends StatelessWidget {
  const _StateLine({required this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    // The eyebrow's line box, held whether or not there is a word in it, and
    // scaled: a fixed height would clip the word at large text sizes.
    final height = MediaQuery.textScalerOf(context).scale(AppType.eyebrow.fontSize!) * 1.3;
    return SizedBox(
      height: height,
      child: AnimatedSwitcher(
        duration: theme.motion.crossfade,
        child: label == null
            ? const SizedBox.shrink()
            : Text(
                label!.toUpperCase(),
                key: ValueKey(label),
                style: AppType.eyebrow.copyWith(color: theme.textSecondary),
              ),
      ),
    );
  }
}

/// The live transcript, isolated so only a text change re-measures it.
class _LiveText extends StatelessWidget {
  const _LiveText();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        BlocSelector<RecorderCubit, RecorderState, String>(
          selector: (state) => state.liveText,
          builder: (context, text) => LiveTranscript(text: text),
        ),
        // Live is a nicety; the batch pass still transcribes the entry, so
        // failure gets calm copy, not an alarm.
        BlocSelector<RecorderCubit, RecorderState, bool>(
          selector: (state) => state.liveUnavailable,
          builder: (context, unavailable) {
            final motion = context.theme.motion;
            final reduce = context.reduceMotion;
            // The seat grows before the words fade in, so the caption never
            // shoves the centered transcript block in one frame.
            return AnimatedSize(
              duration: reduce ? AppMotion.instant : motion.expand,
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: reduce ? Duration.zero : motion.crossfade,
                child: unavailable
                    ? Padding(
                        key: const ValueKey('live-unavailable'),
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Text(
                          AppLocalizations.of(context)!.recordLiveUnavailable,
                          textAlign: TextAlign.center,
                          style: AppType.caption.copyWith(color: context.theme.textSecondary),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            );
          },
        ),
      ],
    );
  }
}

String _formatElapsed(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
}

/// The session-language switch on the bar. Session-only: picking here
/// re-languages the current take and never rewrites the app default.
class _LanguageAction extends StatelessWidget {
  const _LanguageAction({required this.sessionTag});

  final String sessionTag;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final settings = context.watch<SettingsCubit>().state;
    return LanguageMenuButton(
      current: sessionTag,
      tags: [
        // The session's language leads even if its model just vanished.
        if (sessionTag.isNotEmpty) sessionTag,
        for (final tag in settings.selectableLanguageTags())
          if (tag != sessionTag) tag,
      ],
      color: theme.topBar.iconColor,
      onPick: (tag) => context.read<RecorderCubit>().setLanguage(tag),
    );
  }
}
