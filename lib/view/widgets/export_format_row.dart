import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:opentranscribe/core/models/exporter_descriptor.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/export_l10n.dart';
import 'package:opentranscribe/view/widgets/settings_kit.dart';

/// One pickable export format: its mark, its name, and a line saying what the
/// files are. Shared so the Backup screen and the entry export sheet describe
/// a format the same way, and so adding a format is still only a descriptor.
class ExportFormatRow extends StatelessWidget {
  const ExportFormatRow({
    required this.descriptor,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final ExporterDescriptor descriptor;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final copy = exportFormatCopy(AppLocalizations.of(context)!, descriptor.format);
    return SelectableRow(
      label: copy.name,
      note: copy.note,
      leading: ExporterLogo(descriptor),
      selected: selected,
      onTap: onTap,
    );
  }
}

/// A format's mark at chip size. Each mark is normalized in its own asset, on
/// a square canvas that pads it to equal ink against the others, so this stays
/// one square box for every format instead of a table of per-mark sizes. A
/// branded mark keeps its own colors; a monochrome one paints in
/// `currentColor`, which resolves to the label color here so it never sinks
/// into a light or a dark card.
class ExporterLogo extends StatelessWidget {
  const ExporterLogo(this.descriptor, {this.size = 22, super.key});

  final ExporterDescriptor descriptor;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      descriptor.logo,
      width: size,
      height: size,
      theme: SvgTheme(currentColor: context.theme.text),
    );
  }
}
