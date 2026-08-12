import 'dart:io';

import 'package:opentranscribe/core/export/file_names.dart';

/// Tracks which staging directories an in-flight import or export currently
/// owns, so [sweep] never deletes a directory this process is still writing
/// into mid-operation. Register right after `createTemp`, release in the same
/// `finally` that deletes the directory.
class StagingRegistry {
  final Set<String> _owned = {};

  void register(String path) => _owned.add(path);

  void release(String path) => _owned.remove(path);

  bool owns(String path) => _owned.contains(path);

  /// Deletes every stale `import-`/`export-` directory directly under [root]
  /// that this process does not currently own: leftovers from a crash,
  /// jetsam kill, or force-quit mid-operation. Best-effort per directory —
  /// one failure (permissions, a directory vanishing mid-sweep) must not
  /// stop the rest from being swept — and it never throws.
  Future<void> sweep(Directory root) async {
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
        // The next launch's sweep gets another try; a stuck deletion here
        // must not stop the rest of the directory from being swept.
      }
    }
  }
}
