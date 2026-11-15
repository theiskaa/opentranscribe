import 'package:opentranscribe/core/export/staging_registry.dart';

/// A real [StagingRegistry] that also remembers every directory it was handed,
/// so a test can ask whether a given staging is still owned.
final class TrackingStagingRegistry extends StagingRegistry {
  final List<String> registered = [];

  Iterable<String> get imports => registered.where((p) => p.contains('/import-'));

  Iterable<String> get exports => registered.where((p) => p.contains('/export-'));

  @override
  void register(String path) {
    registered.add(path);
    super.register(path);
  }
}
