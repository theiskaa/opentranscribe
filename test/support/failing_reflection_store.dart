import 'dart:io';

import 'package:opentranscribe/core/models/reflection.dart';
import 'package:opentranscribe/core/services/reflection_store.dart';
import 'package:reflections/reflections.dart';

/// A real [ReflectionStore] whose next erase throws a disk error while
/// [failNextDelete] is set, and whose next save writes the row and then
/// throws while [failNextSaveAfterRow] is set, as a save failing on its
/// marker clear does: to break a restore's reflections partway.
final class FailingReflectionStore extends ReflectionStore {
  FailingReflectionStore(super.storage);

  bool failNextDelete = false;
  bool failNextSaveAfterRow = false;

  @override
  Future<void> save(Reflection reflection) async {
    await super.save(reflection);
    if (failNextSaveAfterRow) {
      failNextSaveAfterRow = false;
      throw const FileSystemException('write failed', 'marker', OSError('no space', 28));
    }
  }

  @override
  Future<bool> delete(DateTime start, {ReflectionPeriod period = ReflectionPeriod.weekly}) async {
    if (failNextDelete) {
      failNextDelete = false;
      throw const FileSystemException('write failed', 'reflection', OSError('no space', 28));
    }
    return super.delete(start, period: period);
  }
}
