import 'package:flutter/services.dart';

// Channel identifiers. Must match ShareExport.swift.
const _channel = 'opentranscribe/share_export';

/// The app's one outward door for files, over `ShareExport.swift`: the system
/// share sheet for staged export files, and the document picker for choosing
/// an archive to import. Presenting either is always the direct result of a
/// user tap; nothing here runs on its own.
///
/// Cancel is a normal answer on both calls ([shareFiles] false, [pickArchive]
/// null), never an exception; [ShareExportException] means the call itself
/// could not run (no window, already presenting, bad arguments).
class ShareExport {
  ShareExport({MethodChannel? methods}) : _methods = methods ?? const MethodChannel(_channel);

  final MethodChannel _methods;

  /// Hands [paths] to the share sheet. Resolves once the sheet closes:
  /// whether the user completed an activity. Callers keep the staged files
  /// alive until this resolves and delete them after either answer.
  Future<bool> shareFiles(List<String> paths) async {
    if (paths.isEmpty) throw ArgumentError.value(paths, 'paths', 'must not be empty');
    final reply = await _invoke('shareFiles', {'paths': paths});
    return reply?['completed'] == true;
  }

  /// Opens the document picker for an archive. Resolves to a sandbox-local
  /// copy's path, or null when the user cancels.
  Future<String?> pickArchive() async {
    final reply = await _invoke('pickArchive');
    return reply?['path'] as String?;
  }

  Future<Map<Object?, Object?>?> _invoke(String method, [Object? args]) async {
    try {
      return await _methods.invokeMethod<Map<Object?, Object?>>(method, args);
    } on PlatformException catch (e) {
      throw ShareExportException(e.message, e.code);
    } on MissingPluginException catch (e) {
      throw ShareExportException(e.message);
    }
  }
}

/// Thrown when the share sheet or picker could not be presented at all;
/// a user cancel is never an exception.
class ShareExportException implements Exception {
  const ShareExportException(this.message, [this.code]);

  static const busy = 'busy';
  static const unavailable = 'unavailable';

  final String? message;
  final String? code;

  @override
  String toString() => 'ShareExportException(${code ?? 'no code'}): ${message ?? 'no message'}';
}
