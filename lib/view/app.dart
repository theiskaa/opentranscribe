import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/app/app_language.dart';
import 'package:opentranscribe/core/app/deps.dart';
import 'package:opentranscribe/core/state/entries_cubit.dart';
import 'package:opentranscribe/core/state/recorder_cubit.dart';
import 'package:opentranscribe/core/theming/app_theme.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';

/// The root widget: a Cupertino app (no Material) wired to the router, with the
/// journal cubits provided above it so every routed screen can reach them.
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;

    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => EntriesCubit(service: Deps.i.transcriptionService)),
        BlocProvider(create: (_) => RecorderCubit(service: Deps.i.transcriptionService)),
      ],
      child: CupertinoApp.router(
        onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
        debugShowCheckedModeBanner: false,
        locale: Locale(AppLanguage.of(Deps.i.localService)),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: appCupertinoTheme(brightness),
        routerConfig: Deps.i.router.config,
      ),
    );
  }
}
