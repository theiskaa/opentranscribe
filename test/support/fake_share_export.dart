import 'dart:async';
import 'dart:io';

import 'package:opentranscribe/core/export/share_export.dart';

/// In-memory [ShareExport] for service and cubit tests: records calls,
/// answers scripted outcomes, never touches a platform channel. [captureTo]
/// copies shared files out before the service deletes its staging, the way
/// the real sheet hands them to the OS.
class FakeShareExport implements ShareExport {
  FakeShareExport({
    this.shareCompletes = true,
    this.pickedPath,
    this.throwOnShare = false,
    this.throwOnProtect = false,
    this.captureTo,
  });

  bool shareCompletes;
  String? pickedPath;
  bool throwOnShare;
  bool throwOnProtect;
  Directory? captureTo;
  Duration? shareDelay;

  /// Holds [pickArchive] open until completed, like a picker still on screen.
  Completer<void>? pickGate;

  /// Thrown by [pickArchive] in place of an answer, for a picker that broke
  /// in a way the channel did not name.
  Object? pickError;

  final List<String> calls = [];
  final List<List<String>> sharedPaths = [];
  final List<String> captured = [];
  final List<String> protectedPaths = [];

  @override
  Future<bool> shareFiles(List<String> paths) async {
    calls.add('shareFiles');
    final delay = shareDelay;
    if (delay != null) await Future<void>.delayed(delay);
    sharedPaths.add(List.of(paths));
    if (throwOnShare) {
      throw const ShareExportException('no window', ShareExportException.unavailable);
    }
    final target = captureTo;
    if (target != null) {
      for (final path in paths) {
        final copy = '${target.path}/${path.split('/').last}';
        await File(path).copy(copy);
        captured.add(copy);
      }
    }
    return shareCompletes;
  }

  @override
  Future<String?> pickArchive() async {
    calls.add('pickArchive');
    await pickGate?.future;
    final error = pickError;
    if (error != null) throw error;
    return pickedPath;
  }

  @override
  Future<void> protect(String path) async {
    calls.add('protect');
    if (throwOnProtect) {
      throw const ShareExportException('protect failed', 'protect_failed');
    }
    protectedPaths.add(path);
  }
}
