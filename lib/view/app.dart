import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:opentranscribe/core/app/deps.dart';
import 'package:opentranscribe/core/state/app_language_cubit.dart';
import 'package:opentranscribe/core/state/entries_cubit.dart';
import 'package:opentranscribe/core/state/home_cubit.dart';
import 'package:opentranscribe/core/state/recorder_cubit.dart';
import 'package:opentranscribe/core/state/reflections_cubit.dart';
import 'package:opentranscribe/core/state/settings_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/layouts/splash/screens/splash_screen.dart';

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

  /// The startup splash sits above the router until its animation finishes, then
  /// removes itself for good. One cold-start affair, never shown again.
  bool _splashDone = false;

  @override
  void initState() {
    super.initState();
    _themeCubit = ThemeCubit(storage: Deps.i.localService);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _themeCubit.close();
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    _themeCubit.updatePlatformBrightness(
      WidgetsBinding.instance.platformDispatcher.platformBrightness,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Termination only. Background-audio keeps a live recording in `paused`, so
    // finalizing on pause would kill background capture; only on detach (the app
    // going away) do we finalize any in-flight take, so it is never left as an
    // unfinalized file the reconcile sweep would discard.
    if (state == AppLifecycleState.detached) {
      unawaited(Deps.i.transcriptionService.finalizeActiveCapture());
    } else if (state == AppLifecycleState.resumed) {
      // Reflect any week that closed while the app was away. Single-flighted and
      // a no-op when there is nothing due; never throws.
      unawaited(Deps.i.reflectionService.catchUp());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _themeCubit),
        BlocProvider(create: (_) => AppLanguageCubit(storage: Deps.i.localService)),
        BlocProvider(create: (_) => EntriesCubit(service: Deps.i.transcriptionService)),
        BlocProvider(create: (_) => RecorderCubit(service: Deps.i.transcriptionService)),
        BlocProvider(create: (_) => HomeCubit(service: Deps.i.transcriptionService)),
        // Root-scoped so the settings screen and the language picker (separate
        // routes) share one instance.
        BlocProvider(
          create: (_) => SettingsCubit(
            service: Deps.i.transcriptionService,
            transcription: Deps.i.transcriptionSettings,
            audioStorage: Deps.i.audioStorageSettings,
          ),
        ),
        // Root-scoped so the Reflections screen and the home card (separate
        // routes) read one source.
        BlocProvider(
          create: (_) => ReflectionsCubit(
            service: Deps.i.reflectionService,
            settings: Deps.i.reflectionSettings,
            store: Deps.i.reflectionStore,
            engine: Deps.i.reflectionEngine,
          ),
        ),
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
                // The splash REPLACES the app while it runs rather than
                // overlaying it. Home's top-bar buttons are native platform
                // views, and those composite ABOVE any Flutter overlay (the same
                // reason AppToggle cannot be blurred under the frosted bar), so
                // an overlay lets them punch through. Not building home until the
                // splash is done keeps them out of the tree; the splash shares
                // home's background colour, so the swap is a seamless cut.
                if (!_splashDone) {
                  return SplashScreen(
                    onFinished: () {
                      if (mounted) setState(() => _splashDone = true);
                    },
                  );
                }
                return DefaultTextStyle(
                  style: AppType.body.copyWith(color: theme.text),
                  child: child ?? const SizedBox.shrink(),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
