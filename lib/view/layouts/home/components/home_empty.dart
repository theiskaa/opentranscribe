import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/view/layouts/home/components/home_setup.dart';
import 'package:opentranscribe/view/widgets/glass_fab.dart';
import 'package:opentranscribe/view/widgets/glass_scope.dart';

/// The home empty state: the first page of the journal holds only the setup
/// the first entry will be written with, no title over it. It rides inside a
/// scrollable so the pull-to-record gesture is available here too. The
/// setup's cubits are root-scoped, so nothing here reloads them.
class HomeEmpty extends StatelessWidget {
  const HomeEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Cards on the settings inset; the bottom clears the floating record button.
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        MediaQuery.paddingOf(context).bottom + AppSpacing.xxxl + GlassFab.size,
      ),
      // Drawn controls: this page scrolls under home's drawn bar fade.
      child: const GlassScope(native: false, child: HomeSetup()),
    );
  }
}
