import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/app/deps.dart';

abstract class Bootstrap {
  static Future<void> bootstrap(FutureOr<Widget> Function() builder) async {
    WidgetsFlutterBinding.ensureInitialized();

    await Deps.init();

    runApp(await builder());
  }
}
