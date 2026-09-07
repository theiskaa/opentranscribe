import 'package:flutter/widgets.dart';
import 'package:opentranscribe/core/models/engine_descriptor.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';

/// A descriptor for tests: the id stands in for every name it does not need.
EngineDescriptor engineDescriptor(
  String id, {
  String? displayName,
  String Function(AppLocalizations)? blurb,
  int displayOrder = 0,
}) => EngineDescriptor(
  engineId: id,
  displayName: displayName ?? id,
  displayOrder: displayOrder,
  blurb: blurb ?? ((_) => id),
  logo: const IconData(0x21),
);
