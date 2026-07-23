import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/routes/app_router.dart';

/// Compile-time storage encryption key.
///
/// Override at build time with a real secret and never commit one:
///
/// ```
/// flutter run --dart-define=STORAGE_KEY=<your-32-char-key>
/// ```
///
/// The fallback below is a development-only default so the app runs out of the
/// box. Nothing here ever leaves the device.
const _storageKey = String.fromEnvironment(
  'STORAGE_KEY',
  defaultValue: 'opentranscribe-dev-storage-key-0',
);

/// The app's dependency composition root.
///
/// A single global object with typed fields, built exactly once in
/// [Deps.init] during bootstrap and read from anywhere without a
/// `BuildContext`:
///
/// ```dart
/// final storage = Deps.i.localService;
/// final router = Deps.i.router;
/// ```
///
/// No service locator, no `get_it`, no code generation — dependencies are
/// plain, type-safe fields. Add a new dependency by giving it a field here and
/// constructing it in [init].
class Deps {
  const Deps._({required this.localService, required this.router});

  /// The singleton instance. Valid only after [init] has completed.
  static late final Deps i;

  final LocalService localService;
  final AppRouter router;

  /// Builds every dependency and installs the singleton. Called once, from
  /// bootstrap, before `runApp`.
  static Future<void> init() async {
    final localService = LocalService();
    await localService.init(encryptionKey: _storageKey);

    i = Deps._(
      localService: localService,
      router: AppRouter(),
    );
  }
}
