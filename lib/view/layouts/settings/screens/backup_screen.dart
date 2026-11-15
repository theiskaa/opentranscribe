import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:opentranscribe/core/app/deps.dart';
import 'package:opentranscribe/core/models/exporter_descriptor.dart';
import 'package:opentranscribe/core/state/backup_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/layouts/settings/components/backup_card.dart';
import 'package:opentranscribe/view/layouts/settings/components/backup_format_row.dart';
import 'package:opentranscribe/view/layouts/settings/components/backup_rules.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/app_scaffold.dart';
import 'package:opentranscribe/view/widgets/export_l10n.dart';
import 'package:opentranscribe/view/widgets/passphrase_fields.dart';
import 'package:opentranscribe/view/widgets/settings_kit.dart';

/// Backup: the restorable native archive out and back in from one card, and
/// the one-way formatted exports, one row per format. Owns a [BackupCubit] so
/// the journal is measured on every open.
class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => BackupCubit(
        service: Deps.i.transcriptionService,
        export: Deps.i.exportService,
        import: Deps.i.importService,
        settings: Deps.i.backupSettings,
        descriptors: Deps.i.exporterDescriptors,
      )..load(),
      child: const _BackupView(),
    );
  }
}

class _BackupView extends StatefulWidget {
  const _BackupView();

  @override
  State<_BackupView> createState() => _BackupViewState();
}

class _BackupViewState extends State<_BackupView> {
  /// Null until the user decides; [includeAudioOf] reads the default.
  bool? _includeAudio;

  /// The last finished backup's or export's outcome, told where it happened.
  BackupNote? _note;

  /// The backup's passphrase fields are open above the capsules.
  bool _asking = false;
  final _passphrase = TextEditingController();
  final _repeat = TextEditingController();
  final _firstField = FocusNode();

  /// The restore's passphrase; the cubit decides when its field shows.
  final _unlock = TextEditingController();
  final _unlockField = FocusNode();

  @override
  void dispose() {
    _passphrase.dispose();
    _repeat.dispose();
    _firstField.dispose();
    _unlock.dispose();
    _unlockField.dispose();
    super.dispose();
  }

  bool get _passphraseReady =>
      passphraseSubmittable(confirm: true, passphrase: _passphrase.text, repeat: _repeat.text);

  bool get _unlockReady => passphraseSubmittable(confirm: false, passphrase: _unlock.text);

  void _closeAsk() {
    // The fields stay mounted while they fold away; the keyboard must not
    // ride that fold.
    if (_asking) FocusManager.instance.primaryFocus?.unfocus();
    _asking = false;
    _passphrase.clear();
    _repeat.clear();
  }

  void _act(CardAction action) {
    final cubit = context.read<BackupCubit>();
    switch (action) {
      case CardAction.none:
        return;
      case CardAction.startBackup:
        unawaited(_runBackup(null));
      case CardAction.askPassphrase:
        // The cubit refuses a second operation; the fields must not open
        // for a backup that could not start.
        if (cubit.state.isBusy) return;
        setState(() {
          _note = null;
          _asking = true;
        });
        _firstField.requestFocus();
      case CardAction.submitBackup:
        final passphrase = _passphrase.text;
        setState(_closeAsk);
        unawaited(_runBackup(passphrase));
      case CardAction.closeAsk:
        setState(_closeAsk);
      case CardAction.pickRestore:
        setState(() => _note = null);
        unawaited(cubit.pickForRestore());
      case CardAction.unlockRestore:
        unawaited(cubit.unlockRestore(_unlock.text));
      case CardAction.adoptRestore:
        unawaited(cubit.adoptRestore());
      case CardAction.dismissRestore:
        unawaited(cubit.dismissRestore());
    }
  }

  Capsule _leading(BackupState state) => leadingCapsule(
    state,
    asking: _asking,
    passphraseReady: _passphraseReady,
    unlockReady: _unlockReady,
  );

  /// The keyboard's Done presses the leading capsule, but only for the
  /// field's own action.
  void _submitIf(CardAction expected) {
    final capsule = _leading(context.read<BackupCubit>().state);
    if (capsule.live && capsule.action == expected) _act(expected);
  }

  Future<void> _runBackup(String? passphrase) async {
    final cubit = context.read<BackupCubit>();
    if (cubit.state.isBusy) return;
    setState(() => _note = null);
    final result = await cubit.exportArchive(passphrase: passphrase);
    if (!mounted) return;
    setState(() => _note = archiveNoteOf(result, sealed: passphrase != null));
  }

  Future<void> _exportJournal(ExporterDescriptor descriptor) async {
    final cubit = context.read<BackupCubit>();
    if (cubit.state.isBusy) return;
    final strings = exportStringsOf(AppLocalizations.of(context)!);
    // Another action takes the place of a backup still asking for its
    // passphrase, as the cubit runs one operation at a time.
    setState(() {
      _note = null;
      _closeAsk();
    });
    final result = await cubit.exportJournal(
      strings: strings,
      exporterId: descriptor.exporterId,
      includeAudio: includeAudioOf(cubit.state, _includeAudio),
    );
    if (!mounted) return;
    setState(() => _note = exportNoteOf(descriptor.exporterId, result));
  }

  void _sealChanged(bool seal) {
    setState(() {
      _note = noteAfterSealFlip(_note);
      if (!seal) _closeAsk();
    });
    unawaited(context.read<BackupCubit>().setSeal(seal));
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final cubit = context.read<BackupCubit>();
    final state = context.watch<BackupCubit>().state;

    final live = backupLive(state);
    // A pop mid-step would orphan the restore's outcome. PopScope covers the
    // edge swipe the hidden back button cannot.
    final canLeave = !state.restore.inFlight;
    return BlocListener<BackupCubit, BackupState>(
      // The restore's passphrase is the cubit's to ask for; once the field
      // closes, what was typed in it goes too.
      listenWhen: (previous, next) =>
          restoreAsksPassphrase(previous.restore) && !restoreAsksPassphrase(next.restore),
      listener: (context, _) {
        _unlockField.unfocus();
        _unlock.clear();
      },
      child: PopScope(
        canPop: canLeave,
        child: AppScaffold(
          background: theme.screens.settings,
          onBack: canLeave ? () => context.pop() : null,
          child: SettingsList(
            children: [
              BackupCard(
                state: state,
                note: _note,
                asking: _asking,
                passphrase: _passphrase,
                repeat: _repeat,
                firstField: _firstField,
                unlock: _unlock,
                unlockField: _unlockField,
                leading: _leading(state),
                trailing: trailingCapsule(state, asking: _asking),
                onAct: _act,
                onCancelRun: cubit.cancelShare,
                onSealChanged: live.seal ? _sealChanged : null,
                onPassphraseChanged: () => setState(() {}),
                onPassphraseSubmitted: () => _submitIf(CardAction.submitBackup),
                onUnlockSubmitted: () => _submitIf(CardAction.unlockRestore),
              ),
              SectionLabel(l10n.backupCopiesSection),
              SettingsCard(
                children: [
                  for (final descriptor in cubit.descriptors)
                    BackupFormatRow(
                      descriptor: descriptor,
                      state: state,
                      note: _note,
                      onTap: live.formats ? () => unawaited(_exportJournal(descriptor)) : null,
                      onCancel: cubit.cancelShare,
                    ),
                  SettingsToggleRow(
                    icon: AppIcons.micFill,
                    label: l10n.exportIncludeAudio,
                    value: includeAudioOf(state, _includeAudio),
                    onChanged: live.includeAudio ? (v) => setState(() => _includeAudio = v) : null,
                  ),
                ],
              ),
              // The gap every settings screen leaves above its footnotes.
              const SizedBox(height: AppSpacing.md),
              SectionInfo(l10n.backupCopiesInfo),
            ],
          ),
        ),
      ),
    );
  }
}
