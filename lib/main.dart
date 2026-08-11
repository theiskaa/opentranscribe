import 'package:opentranscribe/bootstrap.dart';
import 'package:opentranscribe/core/utils/launch_trace.dart';
import 'package:opentranscribe/view/app.dart';

Future<void> main() async {
  LaunchTrace.start();
  await Bootstrap.bootstrap(() => const App());
}
