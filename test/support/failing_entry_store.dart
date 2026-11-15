import 'dart:async';
import 'dart:io';

import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/services/entry_store.dart';

/// A real [EntryStore] whose next save of each id in [failOnce] throws a disk
/// error instead of writing, to break an adoption midway on purpose, and
/// whose next save waits on [saveGate] while it is set, to hold a write in
/// place for as long as a test needs.
final class FailingEntryStore extends EntryStore {
  FailingEntryStore(super.storage);

  final Set<String> failOnce = {};
  Completer<void>? saveGate;

  @override
  Future<void> save(Entry entry) async {
    final gate = saveGate;
    if (gate != null) {
      saveGate = null;
      await gate.future;
    }
    if (failOnce.remove(entry.id)) {
      throw const FileSystemException('write failed', 'entry', OSError('no space', 28));
    }
    return super.save(entry);
  }
}
