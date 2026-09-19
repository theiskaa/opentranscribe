import 'dart:io';

/// Where an engine keeps the models it downloads, and how much memory the
/// phone has for a picker to dim a model it cannot hold.
///
/// Guarantees a caller may rely on: [modelsDirectory] exists when it
/// answers, is private to the app, protected at rest, and excluded from
/// backup (a model is re-downloadable, never journal content);
/// [physicalMemoryBytes] never throws and answers null when the platform
/// cannot say.
abstract interface class ModelStorage {
  Future<Directory> modelsDirectory();

  Future<int?> physicalMemoryBytes();
}
