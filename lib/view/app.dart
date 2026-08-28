import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:opentranscribe/core/app/deps.dart';
import 'package:opentranscribe/core/state/app_language_cubit.dart';
import 'package:opentranscribe/core/state/engines_cubit.dart';
import 'package:opentranscribe/core/state/entries_cubit.dart';
import 'package:opentranscribe/core/state/home_cubit.dart';
import 'package:opentranscribe/core/state/recorder_cubit.dart';
import 'package:opentranscribe/core/state/reflections_cubit.dart';
import 'package:opentranscribe/core/state/retranscribe_cubit.dart';
import 'package:opentranscribe/core/state/settings_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/selectable_prose.dart';

/// The root widget, wired to the router with the journal cubits provided above
/// it. Owns the [ThemeCubit] and feeds it platform brightness changes so the
/// chrome re-themes live.
class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  late final ThemeCubit _themeCubit;

  /// Hoisted like [_themeCubit] so the lifecycle observer below can reach it:
  /// the resume re-probe belongs to the app's ONE observer, not to a second
  /// observer inside the cubit.
  late final ReflectionsCubit _reflectionsCubit;

  @override
  void initState() {
    super.initState();
    _themeCubit = ThemeCubit(
      storage: Deps.i.localService,
      backdrop: Deps.i.launchBackdrop,
      isSupporter: () => Deps.i.supportService.tier.isSupporter,
      tierChanges: Deps.i.supportService.changes,
    );
    _reflectionsCubit = ReflectionsCubit(
      service: Deps.i.reflectionService,
      settings: Deps.i.reflectionSettings,
      notifier: Deps.i.reflectionNotifier,
      autoLoad: false,
    );
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // The native wave collapses over a home that has painted, never over the
      // frames building it.
      unawaited(Deps.i.splashHandoff.finish());
      // A launch the user asked to record in opens the sheet over a built
      // journal, ahead of the decrypt below.
      unawaited(Deps.i.intentActionService.serve());
      // Same decrypt-off-the-watched-frames rule as maintenance below: the
      // cubit's first derive walks the whole reflection store and journal.
      unawaited(_reflectionsCubit.load());
      // Only now: this decrypts the whole journal, and the frames before this
      // one are the ones the user is watching.
      unawaited(Deps.launchMaintenance());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _themeCubit.close();
    _reflectionsCubit.close();
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    _themeCubit.updatePlatformBrightness(
      WidgetsBinding.instance.platformDispatcher.platformBrightness,
    );
  }

  @override
  void didChangeAccessibilityFeatures() {
    // Re-runs the Reduce Motion merge in build when the switch flips mid-run.
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Termination only. Background-audio keeps a live recording in `paused`, so
    // finalizing on pause would kill background capture; only on detach (the app
    // going away) do we finalize any in-flight take, so it is never left as an
    // unfinalized file the reconcile sweep would discard.
    if (state == AppLifecycleState.detached) {
      unawaited(Deps.i.transcriptionService.finalizeActiveCapture());
      return;
    }
    if (state != AppLifecycleState.resumed) return;
    // First, ahead of the maintenance passes below: `unawaited` still runs a
    // call's synchronous prefix inline, and a tap waiting on the lock screen
    // must not queue behind a whole-journal decrypt.
    unawaited(Deps.i.intentActionService.drain());
    // A no-op once the launch pass has completed. It does anything only when
    // the audio sweep did not walk the whole directory (a capture was live or
    // finalizing, or the sweep threw), leaving an orphan no UI can reach; the
    // rerun then repeats all three passes, which the two below deliberately
    // duplicate because each is single-flighted and a no-op when idle.
    unawaited(Deps.launchMaintenance());
    // Reflect any week that closed while the app was away. Single-flighted and
    // a no-op when there is nothing due; never throws.
    unawaited(Deps.i.reflectionService.catchUp());
    // Reconcile the weekly nudge: the user may have changed notification
    // permission (or Apple Intelligence) in Settings while backgrounded.
    unawaited(Deps.i.reflectionNotifier.sync());
    // Re-probe availability: the user may have toggled Apple Intelligence in
    // Settings while backgrounded, and the surfaces must not stay frozen at
    // their launch verdict.
    unawaited(_reflectionsCubit.load());
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _themeCubit),
        // Lazy on purpose. `lazy: false` reads the value inside THIS build, so a
        // cubit whose constructor decrypts the journal (EntriesCubit, HomeCubit)
        // would pay for it in the frame the splash is waiting to commit, which
        // is the frame launch is measured by.
        BlocProvider(create: (_) => AppLanguageCubit(storage: Deps.i.localService)),
        BlocProvider(create: (_) => EntriesCubit(service: Deps.i.transcriptionService)),
        BlocProvider(create: (_) => RecorderCubit(service: Deps.i.transcriptionService)),
        // Root-scoped so a bulk run outlives the sheet that started it.
        BlocProvider(create: (_) => RetranscribeCubit(service: Deps.i.transcriptionService)),
        BlocProvider(create: (_) => HomeCubit(service: Deps.i.transcriptionService)),
        // Root-scoped so the settings screen and the language picker (separate
        // routes) share one instance. The exception to the rule above: its
        // constructor seeds from three synchronous settings reads and then
        // fires an UNAWAITED load, so building it here costs this frame
        // microseconds rather than a journal decrypt, and its language list is
        // ready before the first recording instead of populating under the
        // user's eyes.
        BlocProvider(
          lazy: false,
          create: (_) => SettingsCubit(
            service: Deps.i.transcriptionService,
            transcription: Deps.i.transcriptionSettings,
            audioStorage: Deps.i.audioStorageSettings,
          ),
        ),
        // Root-scoped so the choice survives leaving the models screen. Lazy
        // is fine: nothing needs it before that screen builds, and its
        // constructor only snapshots synchronous state.
        BlocProvider(
          create: (_) => EnginesCubit(
            registry: Deps.i.engineRegistry,
            service: Deps.i.transcriptionService,
            engineSettings: Deps.i.engineSettings,
            transcriptionSettings: Deps.i.transcriptionSettings,
          ),
        ),
        // Root-scoped so the Reflections screen and the home card (separate
        // routes) read one source.
        BlocProvider.value(value: _reflectionsCubit),
      ],
      child: BlocBuilder<ThemeCubit, ThemeState>(
        // The app-level chrome only depends on the resolved theme; skip
        // emissions that leave it identical.
        buildWhen: (previous, current) => !identical(previous.resolved, current.resolved),
        builder: (context, themeState) {
          final theme = themeState.resolved;
          final language = context.watch<AppLanguageCubit>().state;
          // Date and time formatting must follow the app language; every
          // DateFormat call site relies on this.
          Intl.defaultLocale = language;
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: theme.brightness == Brightness.dark
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark,
            child: WidgetsApp.router(
              onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
              debugShowCheckedModeBanner: false,
              color: theme.accent,
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: Deps.i.router.config,
              builder: (context, child) {
                // iOS reports Reduce Motion on dart:ui's reduceMotion flag,
                // which MediaQuery never surfaces (disableAnimations is the
                // Android switch), so fold it in here: every reduceMotion read
                // below the root sees one merged answer.
                final media = MediaQuery.of(context);
                final reduceMotion =
                    media.disableAnimations ||
                    WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.reduceMotion;
                return MediaQuery(
                  data: media.copyWith(disableAnimations: reduceMotion),
                  // Above the router's navigator, so it also tints the text
                  // selection handles and menu, which render in the root
                  // overlay.
                  child: SelectionTheme(
                    accent: theme.accent,
                    brightness: theme.brightness,
                    child: DefaultTextStyle(
                      style: AppType.body.copyWith(color: theme.text),
                      child: child ?? const SizedBox.shrink(),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
