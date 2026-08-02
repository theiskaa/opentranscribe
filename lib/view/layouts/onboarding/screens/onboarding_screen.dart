import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:opentranscribe/core/app/deps.dart';
import 'package:opentranscribe/core/app/onboarding.dart';
import 'package:opentranscribe/core/routes/routes.dart';
import 'package:opentranscribe/core/state/onboarding_cubit.dart';
import 'package:opentranscribe/core/state/settings_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/layouts/onboarding/components/onboarding_intro.dart';
import 'package:opentranscribe/view/layouts/onboarding/components/onboarding_models.dart';
import 'package:opentranscribe/view/layouts/onboarding/components/onboarding_permissions.dart';
import 'package:opentranscribe/view/widgets/app_button.dart';
import 'package:opentranscribe/view/widgets/page_indicator.dart';

/// First-launch onboarding: three swipeable steps (intro, permissions, model
/// download) over one bottom button, then into the app. Shown once - the
/// router's redirect gates it on [Onboarding.isDone], and finishing marks it so.
/// Free to proceed: no step blocks the button, since the app prompts for
/// permissions and installs the default model on first use anyway.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OnboardingCubit(
        service: Deps.i.transcriptionService,
        scheduler: Deps.i.notificationScheduler,
      ),
      child: const _OnboardingView(),
    );
  }
}

class _OnboardingView extends StatefulWidget {
  const _OnboardingView();

  @override
  State<_OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<_OnboardingView> {
  static const _pageCount = 3;

  final PageController _controller = PageController();
  int _index = 0;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    // The model step reads the language list; load it now so a row is ready by
    // the time the user swipes there. Shared root cubit, so the Models screen
    // later sees the same state.
    unawaited(context.read<SettingsCubit>().load());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next(Duration slide) {
    if (_index >= _pageCount - 1) {
      unawaited(_finish());
      return;
    }
    if (slide == Duration.zero) {
      _controller.jumpToPage(_index + 1);
    } else {
      _controller.nextPage(duration: slide, curve: Curves.easeOut);
    }
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    try {
      await Onboarding.markDone(Deps.i.localService);
    } catch (_) {
      // A failed write only means onboarding shows again next launch; still let
      // the user in rather than pinning them to a loading button.
    }
    if (mounted) context.goNamed(Routes.homeName);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final isLast = _index == _pageCount - 1;
    final slide = context.reduceMotion ? Duration.zero : theme.motion.pageSlide;

    return ColoredBox(
      color: theme.background,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _index = i),
                children: const [OnboardingIntro(), OnboardingPermissions(), OnboardingModels()],
              ),
            ),
            PageIndicator(count: _pageCount, index: _index),
            const SizedBox(height: AppSpacing.xl),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: AppButton(
                label: isLast ? l10n.onboardingStart : l10n.onboardingNext,
                isLoading: _finishing,
                onPressed: () => _next(slide),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}
