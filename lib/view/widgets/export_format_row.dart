import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:opentranscribe/core/models/exporter_descriptor.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/export_l10n.dart';
import 'package:opentranscribe/view/widgets/settings_kit.dart';

/// One pickable export format: its mark, its name, and a line saying what the
/// files are. Shared so the Backup screen and the entry export sheet describe
/// a format the same way.
class ExportFormatRow extends StatelessWidget {
  const ExportFormatRow({
    required this.descriptor,
    required this.selected,
    required this.onTap,
    this.locked = false,
    super.key,
  });

  final ExporterDescriptor descriptor;
  final bool selected;

  /// Supporter-gated: the row wears the quiet lock instead of a selection.
  final bool locked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final copy = exportFormatCopy(AppLocalizations.of(context)!, descriptor.format);
    return SelectableRow(
      label: copy.name,
      note: copy.note,
      leading: ExporterLogo(descriptor),
      selected: selected,
      locked: locked,
      onTap: onTap,
    );
  }
}

/// A format's mark at chip size, shared by every row that puts one in the
/// settings tile (the format pickers, the support screen's exports perk).
/// Each mark is normalized in its own asset, on a square canvas that pads it
/// to equal ink against the others, so this stays one square box for every
/// format instead of a table of per-mark sizes. A branded mark keeps its own
/// colors; a monochrome one paints in `currentColor`, which resolves to the
/// label color here so it never sinks into a light or a dark card.
class ExporterLogo extends StatelessWidget {
  const ExporterLogo(this.descriptor, {super.key});

  final ExporterDescriptor descriptor;

  /// Chip size. Sits inside the row's icon tile with its own margin, and larger
  /// than the flag a language row puts there because a mark is line art, not a
  /// filled glyph.
  static const _size = 22.0;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      descriptor.logo,
      width: _size,
      height: _size,
      theme: SvgTheme(currentColor: context.theme.text),
    );
  }
}
