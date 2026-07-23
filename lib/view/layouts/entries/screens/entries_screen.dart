import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:opentranscribe/core/routes/routes.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';

/// Landing screen: the list of journal entries.
///
/// Placeholder for now; the record button and entries list land here.
class EntriesScreen extends StatelessWidget {
  const EntriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.entriesTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.goNamed(Routes.settingsName),
          ),
        ],
      ),
      body: Center(child: Text(l10n.entriesEmpty)),
    );
  }
}
