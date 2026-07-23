import 'package:opentranscribe/bootstrap.dart';
import 'package:opentranscribe/view/app.dart';

Future<void> main() async {
  await Bootstrap.bootstrap(() => const App());
}
