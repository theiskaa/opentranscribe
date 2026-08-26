import 'package:flutter/widgets.dart';

import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/glass_fab.dart';

/// The floating record button: a persistent, obvious way to start a new entry,
/// beside the quieter pull-to-record gesture. The brand waveform on the shared
/// floating disc.
class RecordFab extends StatelessWidget {
  const RecordFab({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GlassFab(icon: AppIcons.waveform, onTap: onTap);
}
