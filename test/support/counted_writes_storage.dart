import 'package:opentranscribe/core/app/local_service.dart';

/// A [LocalService] that counts every write and, while [failing], refuses it,
/// so a suite can tell a skipped write from one that never landed.
class CountedWritesStorage extends LocalService {
  int writes = 0;
  bool failing = false;

  @override
  Future<void> write<T>(String key, T value) {
    writes++;
    return failing ? Future.error(StateError('no disk')) : super.write(key, value);
  }
}
