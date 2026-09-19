import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:opentranscribe/core/app/deps.dart';
import 'package:opentranscribe/core/app/onboarding.dart';
import 'package:opentranscribe/core/routes/routes.dart';
import 'package:opentranscribe/core/state/engines_cubit.dart';
import 'package:opentranscribe/core/state/models_cubit.dart';
import 'package:opentranscribe/core/state/onboarding_cubit.dart';
import 'package:opentranscribe/core/state/reflections_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/layouts/onboarding/components/back_only_physics.dart';
import 'package:opentranscribe/view/layouts/onboarding/components/onboarding_engine.dart';
import 'package:opentranscribe/view/layouts/onboarding/components/onboarding_record.dart';
import 'package:opentranscribe/view/layouts/onboarding/components/onboarding_reflect.dart';
import 'package:opentranscribe/view/layouts/onboarding/components/onboarding_setup.dart';
import 'package:opentranscribe/view/layouts/onboarding/components/onboarding_shape.dart';
import 'package:opentranscribe/view/layouts/onboarding/components/onboarding_steps.dart';
import 'package:opentranscribe/view/widgets/app_button.dart';
import 'package:opentranscribe/view/widgets/page_indicator.dart';

/// First-launch onboarding: four or five pages over one bottom button, then
/// into the app. Shown once - the router's redirect gates it on
/// [Onboarding.isDone], and finishing marks it so. The button is the only way
/// forward, and the last one fires the pending system prompts before entering
/// the app, since App Store 5.1.1(iv) requires a priming page to always lead
/// to the request; the set-up page is that priming. Back is free, by swipe or
/// by dot. Denials never block, only mark the rows.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OnboardingCubit(
        service: Deps.i.transcriptionService,
        scheduler: Deps.i.notificationScheduler,
        notifier: Deps.i.reflectionNotifier,
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
  void initState() {
    super.initState();
    unawaited(_startAsYouSpeak());
  }

  /// The engine page opens on as you speak, whatever engine was in use.
  Future<void> _startAsYouSpeak() async {
    final cubit = context.read<EnginesCubit>();
    final id = engineForAnswer(cubit.state.rows, WordsWhen.asYouSpeak);
    if (id == null ||
        cubit.state.rows.any((row) => row.isActive && row.descriptor.engineId == id)) {
      return;
    }
    try {
      await cubit.pick(id);
    } catch (_) {}
  }

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
      if (steps[_index] == OnboardingStep.engine) unawaited(_fetchChosenModel());
      _goTo(_index + 1, slide);
      return;
    }
    if (_requesting) return;
    setState(() => _requesting = true);
    await context.read<OnboardingCubit>().requestPending(reminders: _canReflect(context));
    if (!mounted) return;
    setState(() => _requesting = false);
    unawaited(_finish());
  }

  /// The chosen model starts downloading as the reader moves on, so it is
  /// here by the first entry; a failed one is retried by the first take.
  Future<void> _fetchChosenModel() async {
    final cubit = context.read<ModelsCubit>();
    try {
      // An engine picked a moment ago is not in the rows until they reload.
      await cubit.load();
      if (await settleModel(cubit)) await cubit.load();
      if (downloadsOnLeave(cubit.state)) await cubit.installSelected();
    } catch (_) {}
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
                  onPageChanged: (i) => setState(() => _index = i),
                  children: [
                    for (final step in steps)
                      switch (step) {
                        OnboardingStep.record => const OnboardingRecord(),
                        OnboardingStep.engine => const OnboardingEngine(),
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
                label: isLast ? l10n.onboardingStart : l10n.onboardingNext,
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
