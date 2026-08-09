import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:opentranscribe/core/app/deps.dart';
import 'package:opentranscribe/core/utils/launch_trace.dart';
import 'package:opentranscribe/view/launch_failure_app.dart';

abstract class Bootstrap {
  /// Always calls `runApp`, even when startup fails or hangs. Without that the
  /// process commits no frame at all, which reads as a frozen launch screen
  /// until the watchdog kills it. See [LaunchFailureApp].
  ///
  /// Nothing is deadlined here: the only startup work that can hang forever is
  /// a platform channel, and each of those carries its own timeout inside
  /// [Deps.init], whose `TimeoutException` lands in the catch below.
  static Future<void> bootstrap(FutureOr<Widget> Function() builder) async {
    WidgetsFlutterBinding.ensureInitialized();
    LaunchTrace.mark('binding'); // TEMP

    try {
      // Load date symbols for every locale up front. App code formats dates
      // against `Intl.defaultLocale` outside the widget tree, and the global
      // delegates only load intl's data when the first Localizations builds, so
      // anything formatted before that falls back to English. Inside the try:
      // a throw here would otherwise leave `runApp` uncalled.
      await initializeDateFormatting();
      LaunchTrace.mark('date symbols'); // TEMP

      await Deps.init();
    } catch (error, stack) {
      // Unconditional: a release build that cannot start is diagnosable only
      // from the device log, and this stays on the device.
      debugPrint('bootstrap: startup failed: $error\n$stack');
      runApp(LaunchFailureApp(error));
      return;
    }
    LaunchTrace.mark('deps'); // TEMP

    runApp(await builder());
    // TEMP
    WidgetsBinding.instance.addPostFrameCallback((_) => LaunchTrace.mark('first frame'));
  }
}
