import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:opentranscribe/core/app/deps.dart';
import 'package:opentranscribe/core/state/app_language_cubit.dart';
import 'package:opentranscribe/core/state/entries_cubit.dart';
import 'package:opentranscribe/core/state/home_cubit.dart';
import 'package:opentranscribe/core/state/recorder_cubit.dart';
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
              builder: (context, child) => Stack(
                children: [
                  DefaultTextStyle(
                    style: AppType.body.copyWith(color: theme.text),
                    child: child ?? const SizedBox.shrink(),
                  ),
                  // Above the router so home builds behind the splash and the
                  // hand-off is a pure fade with nothing to load at the seam.
                  if (!_splashDone)
                    Positioned.fill(
                      child: SplashScreen(
                        onFinished: () {
                          if (mounted) setState(() => _splashDone = true);
                        },
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
