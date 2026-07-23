import 'package:flutter/material.dart';

import 'package:opentranscribe/core/app/app_language.dart';
import 'package:opentranscribe/core/app/deps.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      debugShowCheckedModeBanner: false,
      locale: Locale(AppLanguage.of(Deps.i.localService)),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(useMaterial3: true, brightness: Brightness.light),
      darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
      routerConfig: Deps.i.router.config,
    );
  }
}
