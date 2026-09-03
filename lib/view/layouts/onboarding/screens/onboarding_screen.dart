import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:opentranscribe/core/app/deps.dart';
import 'package:opentranscribe/core/app/onboarding.dart';
import 'package:opentranscribe/core/routes/routes.dart';
import 'package:opentranscribe/core/state/onboarding_cubit.dart';
import 'package:opentranscribe/core/state/reflections_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/layouts/onboarding/components/back_only_physics.dart';
import 'package:opentranscribe/view/layouts/onboarding/components/onboarding_record.dart';
import 'package:opentranscribe/view/layouts/onboarding/components/onboarding_reflect.dart';
import 'package:opentranscribe/view/layouts/onboarding/components/onboarding_setup.dart';
import 'package:opentranscribe/view/layouts/onboarding/components/onboarding_shape.dart';
import 'package:opentranscribe/view/layouts/onboarding/components/onboarding_steps.dart';
import 'package:opentranscribe/view/widgets/app_button.dart';
import 'package:opentranscribe/view/widgets/app_top_bar.dart';
import 'package:opentranscribe/view/widgets/page_indicator.dart';

/// First-launch onboarding: three or four pages over one bottom button, then
/// into the app. Shown once - the router's redirect gates it on
/// [Onboarding.isDone], and finishing marks it so. The button is the only way
/// forward, and the last one fires the pending system prompts before entering
/// the app, since App Store 5.1.1(iv) requires a priming page to always lead
/// to the request; the set-up page is that priming. Back is free, by swipe or
/// by dot. Denials never block, only mark the rows.
///
/// A [replay] is the same flow pushed over home by a finished user: its last
/// button pops instead of marking anything, and the prompts fire on reaching
/// the set-up page rather than on that button (see [promptsOnArrival]).
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({this.replay = false, super.key});

  final bool replay;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OnboardingCubit(
        service: Deps.i.transcriptionService,
        scheduler: Deps.i.notificationScheduler,
        notifier: Deps.i.reflectionNotifier,
      ),
      child: _OnboardingView(replay: replay),
    );
  }
}

/// Whether landing on [page] of [pageCount] fires the pending prompts. A first
/// run asks on the last page's button; a replay's last button only pops, so a
/// replay asks on arriving at that page instead, still over the page that
/// primes the request. The cubit asks only for an answer that never landed,
/// so a replay after a full first run asks nothing.
bool promptsOnArrival({required bool replay, required int page, required int pageCount}) =>
    replay && page == pageCount - 1;

class _OnboardingView extends StatefulWidget {
  const _OnboardingView({required this.replay});

  final bool replay;

  @override
  State<_OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<_OnboardingView> {
  final PageController _controller = PageController();
  int _index = 0;

  /// The pager's forward gate: the page the button has unlocked. Raised before
  /// the button's drive so its first tick passes, closed on the resting page
  /// once the pager stops, never mid-motion (see [BackOnlyPagePhysics]).
  int _reach = 0;

  /// The flow, frozen the moment the reader leaves the first page. Until then
  /// it follows the reflections probe, which answers after launch and would
  /// otherwise be read as "cannot" on every eligible phone; after, a page
  /// appearing mid-flow would shift the one under the reader's thumb.
  List<OnboardingStep>? _frozen;

  bool _requesting = false;
  bool _finishing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<OnboardingStep> _stepsFor(BuildContext context) =>
      _frozen ??
      onboardingSteps(
        canReflect: reflectionsEligible(
          context.watch<ReflectionsCubit>().state.availability.status,
        ),
      );

  /// Read, not watched: the callers are the button and the page change, never
  /// a build.
  bool _canReflect(BuildContext context) =>
      reflectionsEligible(context.read<ReflectionsCubit>().state.availability.status);

  Future<void> _next(List<OnboardingStep> steps, Duration slide) async {
    if (_index < steps.length - 1) {
      _frozen ??= steps;
      _goTo(_index + 1, slide);
      return;
    }
    if (!widget.replay) {
      if (_requesting) return;
      setState(() => _requesting = true);
      await context.read<OnboardingCubit>().requestPending(reminders: _canReflect(context));
      if (!mounted) return;
      setState(() => _requesting = false);
    }
    unawaited(_finish());
  }

  /// Dots only ever go back; a forward dot stays inert so the button keeps
  /// its job.
  void _back(int page, Duration slide) {
    if (page < _index) _goTo(page, slide);
  }

  void _goTo(int page, Duration slide) {
    if (page > _reach) _reach = page;
    if (slide == Duration.zero) {
      _controller.jumpToPage(page);
    } else {
      unawaited(_controller.animateToPage(page, duration: slide, curve: Curves.easeOut));
    }
  }

  Future<void> _finish() async {
    if (_finishing) return;
    if (widget.replay) {
      // No setState: the page is leaving, a spinner on it would only flash.
      _finishing = true;
      context.pop();
      return;
    }
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
    final steps = _stepsFor(context);
    final isLast = _index == steps.length - 1;
    final slide = context.reduceMotion ? Duration.zero : theme.motion.pageSlide;

    return ColoredBox(
      color: theme.background,
      child: SafeArea(
        child: Column(
          children: [
            if (widget.replay)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: AppBackButton(onBack: () => context.pop()),
                ),
              ),
            Expanded(
              child: NotificationListener<ScrollEndNotification>(
                onNotification: (n) {
                  if (n.depth == 0) {
                    _reach = restingReach(
                      pixels: n.metrics.pixels,
                      viewportDimension: n.metrics.viewportDimension,
                    );
                  }
                  return false;
                },
                child: PageView(
                  controller: _controller,
                  physics: BackOnlyPagePhysics(reach: () => _reach),
                  onPageChanged: (i) {
                    setState(() => _index = i);
                    if (promptsOnArrival(replay: widget.replay, page: i, pageCount: steps.length)) {
                      // A replay only asks for answers that never landed; it
                      // must not switch on reminders the user turned off.
                      unawaited(context.read<OnboardingCubit>().requestPending(reminders: false));
                    }
                  },
                  children: [
                    for (final step in steps)
                      switch (step) {
                        OnboardingStep.record => const OnboardingRecord(),
                        OnboardingStep.reflect => const OnboardingReflect(),
                        OnboardingStep.shape => const OnboardingShape(),
                        OnboardingStep.setup => const OnboardingSetup(),
                      },
                  ],
                ),
              ),
            ),
            PageIndicator(count: steps.length, index: _index, onTap: (i) => _back(i, slide)),
            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: AppButton(
                label: switch ((isLast, widget.replay)) {
                  (false, _) => l10n.onboardingNext,
                  (true, false) => l10n.onboardingStart,
                  (true, true) => l10n.onboardingDone,
                },
                isLoading: _requesting || _finishing,
                onPressed: () => unawaited(_next(steps, slide)),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }
}
