import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:opentranscribe/core/app/deps.dart';
import 'package:opentranscribe/view/layouts/splash/screens/launch_failure_screen.dart';

abstract class Bootstrap {
  /// Always calls `runApp`, even when startup fails. A throw that escapes here
  /// would leave the process with no committed frame at all: iOS holds the
  /// launch screen, nothing is logged where the user can see it, and the
  /// watchdog eventually kills it. A Keychain read before the first unlock
  /// after a reboot is enough to get there.
  static Future<void> bootstrap(FutureOr<Widget> Function() builder) async {
    WidgetsFlutterBinding.ensureInitialized();

    // Load date symbols for every locale up front. The global localization
    // delegates only load them per-locale and asynchronously, which leaves the
    // first paint of a date in a non-English language falling back to English.
    // This does not make those delegates synchronous: the very first frame is
    // still empty while they resolve.
    await initializeDateFormatting();

    try {
      await Deps.init();
    } catch (error, stack) {
      if (kDebugMode) debugPrint('bootstrap: startup failed: $error\n$stack');
      runApp(LaunchFailureApp(error));
      return;
    }

    runApp(await builder());
  }
}
