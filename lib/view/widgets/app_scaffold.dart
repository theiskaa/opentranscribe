import 'package:flutter/cupertino.dart';

import 'package:opentranscribe/core/theming/app_theme.dart';

/// A minimal page scaffold with an iOS-style large title and an optional back
/// chevron and trailing action. No Material.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.title,
    required this.child,
    this.trailing,
    this.onBack,
    super.key,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return ColoredBox(
      color: colors.background,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 44,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: Row(
                  children: [
                    if (onBack != null)
                      CupertinoButton(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        minimumSize: Size.zero,
                        onPressed: onBack,
                        child: Icon(CupertinoIcons.back, color: colors.text, size: 26),
                      ),
                    const Spacer(),
                    ?trailing,
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Text(title, style: AppText.largeTitle(context)),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
