import 'package:opentranscribe/core/app/app_icon.dart';

/// In-memory [AppIconStore]: records sets, answers a scripted current icon,
/// never touches a channel.
class FakeAppIconStore implements AppIconStore {
  FakeAppIconStore({this.currentAnswer, this.setError, this.currentError});

  String? currentAnswer;
  AppIconStoreException? setError;
  AppIconStoreException? currentError;

  /// Held open, the next [set] waits on it before landing.
  Future<void>? setGate;

  /// Held open, the next [current] waits on it before answering.
  Future<void>? currentGate;

  final List<String?> sets = [];

  @override
  Future<String?> current() async {
    if (currentError != null) throw currentError!;
    await currentGate;
    return currentAnswer;
  }

  @override
  Future<void> set(String? iconName) async {
    if (setError != null) throw setError!;
    await setGate;
    sets.add(iconName);
    currentAnswer = iconName;
  }
}
