import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:opentranscribe/core/app/deps.dart';

abstract class Bootstrap {
  static Future<void> bootstrap(FutureOr<Widget> Function() builder) async {
    WidgetsFlutterBinding.ensureInitialized();

    // Load date symbols for every locale up front. The global localization
    // delegates only load them per-locale and asynchronously, which leaves the
    // first paint of a date in a non-English language falling back to English.
    await initializeDateFormatting();

    await Deps.init();

    runApp(await builder());
  }
}
