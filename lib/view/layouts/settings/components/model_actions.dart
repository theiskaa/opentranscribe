import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/state/models_cubit.dart';
import 'package:opentranscribe/core/utils/haptics.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/app_button.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/app_sheet.dart';
import 'package:opentranscribe/view/widgets/formatting.dart';
import 'package:opentranscribe/view/widgets/sheet_message.dart';

// What a tap on a model does, shared by the model card, its chips and the
// model sheet, so each surface words a refusal the same way. Every opener
// checks the route first: two pointers in one frame must not stack sheets.

bool _onTop(BuildContext context) => ModalRoute.of(context)?.isCurrent ?? true;

/// Starts the model's download, which chooses it once landed. A refusal is a
/// model a run holds, and the busy words say to wait.
Future<void> installModel(BuildContext context, ModelRowState row) async {
  final installing = await context.read<ModelsCubit>().installModelById(row.option.id);
  if (installing || !context.mounted) return;
  await _explainBusy(context, row);
}

/// Makes the model the one runs use. Answers whether the pick was made; a
/// refused persist still takes for the session and says it will not last.
Future<bool> useModel(BuildContext context, ModelRowState row) async {
  if (!_onTop(context)) return false;
  final l10n = AppLocalizations.of(context)!;
  try {
    await context.read<ModelsCubit>().selectModel(row.option.id);
  } catch (_) {
    if (!context.mounted || !(ModalRoute.of(context)?.isCurrent ?? false)) return true;
    await showAppSheet<void>(
      context,
      builder: (context) => SheetMessage(
        icon: AppIcons.internaldrive,
        title: l10n.engineNotSavedTitle,
        body: l10n.modelNotSavedBody,
      ),
    );
  }
  return true;
}

Future<void> explainHeavyModel(BuildContext context, ModelRowState row) async {
  if (!_onTop(context)) return;
  final l10n = AppLocalizations.of(context)!;
  await showAppSheet<void>(
    context,
    builder: (context) => SheetMessage(
      icon: AppIcons.internaldrive,
      title: l10n.modelTooHeavyTitle,
      body: l10n.modelTooHeavyBody(row.option.displayName),
    ),
  );
}

/// Asks, then deletes the model's files. A refusal shows only while the file
/// is really still there: a model that vanished underneath reads as removed
/// once the reload lands.
Future<void> confirmRemoveModel(BuildContext context, ModelRowState row) async {
  if (!_onTop(context)) return;
  final l10n = AppLocalizations.of(context)!;
  final cubit = context.read<ModelsCubit>();
  final held = row.option.bytes + (row.accelerated ? row.option.accelerationBytes : 0);
  final size = formatBytes(held, localeTag(context));
  final confirmed = await showAppSheet<bool>(
    context,
    builder: (context) => SheetMessage(
      icon: AppIcons.trash,
      title: l10n.modelRemoveTitle(row.option.displayName),
      body: l10n.modelRemoveBody(size),
      action: AppButton(
        label: l10n.modelRemoveConfirm,
        variant: AppButtonVariant.danger,
        onPressed: () {
          Haptics.medium();
          Navigator.of(context).pop(true);
        },
      ),
    ),
  );
  if (!(confirmed ?? false)) return;
  final removed = await cubit.removeModel(row.option.id);
  final stillThere = cubit.state.models.any((r) => r.option.id == row.option.id && r.installed);
  if (removed || !stillThere || !context.mounted) return;
  await _explainBusy(context, row);
}

Future<void> _explainBusy(BuildContext context, ModelRowState row) async {
  if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
  final l10n = AppLocalizations.of(context)!;
  await showAppSheet<void>(
    context,
    builder: (context) => SheetMessage(
      icon: AppIcons.internaldrive,
      title: l10n.modelBusyTitle,
      body: l10n.modelBusyBody(row.option.displayName),
    ),
  );
}
