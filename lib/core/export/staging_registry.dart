import 'dart:io';

import 'package:opentranscribe/core/export/file_names.dart';

/// Tracks which staging directories an in-flight import or export currently
/// owns, so [sweep] never deletes a directory this process is still writing
/// into mid-operation. Register right after `createTemp`, release in the same
/// `finally` that deletes the directory.
class StagingRegistry {
  final Set<String> _owned = {};
  int _operations = 0;

  void register(String path) => _owned.add(path);

  void release(String path) => _owned.remove(path);

  bool owns(String path) => _owned.contains(path);

  /// Brackets one import/export from before its directory exists until after
  /// its cleanup. While any operation is open the sweep stands down, so no
  /// window exists where a live directory is on disk and unprotected.
  void begin() => _operations++;

  void end() => _operations = _operations > 0 ? _operations - 1 : 0;

  /// Deletes every stale `import-`/`export-` directory directly under [root]
  /// that this process does not currently own: leftovers from a crash,
  /// jetsam kill, or force-quit mid-operation. Best-effort per directory:
  /// one failure (permissions, a directory vanishing mid-sweep) must not
  /// stop the rest from being swept, and it never throws.
  Future<void> sweep(Directory root) async {
    // A skipped sweep costs nothing; the next launch or resume sweeps.
    if (_operations > 0) return;
    List<FileSystemEntity> children;
    try {
      children = await root.list().toList();
    } catch (_) {
      return;
    }
    for (final child in children) {
      if (child is! Directory) continue;
      final name = baseName(child.path);
      if (!name.startsWith('import-') && !name.startsWith('export-')) continue;
      if (owns(child.path)) continue;
      try {
        await child.delete(recursive: true);
      } catch (_) {
        // The next launch's sweep gets another try. A stuck deletion here
        // must not stop the rest of the directory from being swept.
      }
    }
  }
}
