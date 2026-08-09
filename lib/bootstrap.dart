import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:opentranscribe/core/app/deps.dart';
import 'package:opentranscribe/core/utils/launch_trace.dart';
import 'package:opentranscribe/view/launch_failure_app.dart';

abstract class Bootstrap {
  /// Far past a healthy startup (a third of a second) and far short of the
  /// ~20 s iOS watchdog, so a wedged dependency lands on the failure screen
  /// with time to spare instead of as a launch kill with no frame at all.
  static const _initTimeout = Duration(seconds: 8);

  /// Always calls `runApp`, even when startup fails or hangs. Without that the
  /// process commits no frame at all, which reads as a frozen launch screen
  /// until the watchdog kills it. See [LaunchFailureApp].
  static Future<void> bootstrap(FutureOr<Widget> Function() builder) async {
    WidgetsFlutterBinding.ensureInitialized();
    LaunchTrace.mark('binding'); // TEMP

    // Load date symbols for every locale up front. App code formats dates
    // against `Intl.defaultLocale` outside the widget tree, and the global
    // delegates only load intl's data when the first Localizations builds, so
    // anything formatted before that falls back to English.
    await initializeDateFormatting();
    LaunchTrace.mark('date symbols'); // TEMP

    try {
      // Timed out, not just guarded: the engine's locale calls are platform
      // channel round trips, and a channel that never replies would otherwise
      // hang here forever, which no catch can see.
      await Deps.init().timeout(_initTimeout);
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
