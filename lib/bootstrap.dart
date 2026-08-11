import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:opentranscribe/core/app/deps.dart';
import 'package:opentranscribe/view/launch_failure_app.dart';

abstract class Bootstrap {
  /// Always calls `runApp`, even when startup fails or hangs. Without that the
  /// process commits no frame at all, which reads as a frozen launch screen
  /// until the watchdog kills it. See [LaunchFailureApp].
  ///
  /// Nothing is deadlined here: every platform channel [Deps.init] awaits
  /// carries its own timeout there, whose `TimeoutException` lands in the catch
  /// below. The one step [Deps.init] leaves undeadlined is the legacy storage
  /// migration, which is bounded work that always finishes.
  static Future<void> bootstrap(FutureOr<Widget> Function() builder) async {
    WidgetsFlutterBinding.ensureInitialized();

    try {
      // Load date symbols for every locale up front. App code formats dates
      // against `Intl.defaultLocale` outside the widget tree, and the global
      // delegates only load intl's data when the first Localizations builds, so
      // anything formatted before that falls back to English. Inside the try:
      // a throw here would otherwise leave `runApp` uncalled.
      await initializeDateFormatting();

      await Deps.init();
    } catch (error, stack) {
      // Unconditional: a release build that cannot start is diagnosable only
      // from the device log, and this stays on the device.
      debugPrint('bootstrap: startup failed: $error\n$stack');
      runApp(LaunchFailureApp(error));
      return;
    }

    runApp(await builder());
  }
}
