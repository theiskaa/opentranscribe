import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:opentranscribe/core/export/stored_zip.dart';

/// A pack the user called off. Maps to the quiet cancel everywhere: nothing
/// was shared, and the user already knows why.
final class ZipPackAborted implements Exception {
  const ZipPackAborted();
}

/// Builds one stored zip on its own isolate, so a journal of gigabytes never
/// runs its checksum loop under the UI. Byte entries land first, then the
/// files, streamed; [onProgress] reports file bytes written against their
/// total (per file landed, so one huge file moves it in one step), and
/// [abort] kills the build, leaving the partial target to the caller's
/// staging cleanup. One run per instance.
///
/// Failures cross the isolate as data and are rethrown typed: the size cap
/// as [StoredZipException] with [StoredZipError.tooLarge] and disk errors as
/// [FileSystemException] with their OS code, so the failure sheets keep
/// naming causes exactly as an on-isolate build would.
final class ZipPack {
  ZipPack({required this.target, required this.bytes, required this.files});

  final String target;
  final List<(String, Uint8List)> bytes;

  /// Zip path to source path, packed in order.
  final List<(String, String)> files;

  final Completer<void> _done = Completer<void>();
  Isolate? _isolate;
  bool _ran = false;

  Future<void> run({void Function(int written, int total)? onProgress}) async {
    if (_ran) throw StateError('a ZipPack runs once');
    _ran = true;
    var total = 0;
    for (final (_, source) in files) {
      try {
        total += await File(source).length();
      } catch (_) {
        // Vanished before the build: the packer skips it too.
      }
    }
    final port = ReceivePort();
    port.listen((Object? message) {
      if (_done.isCompleted) return;
      switch (message) {
        case final int written:
          onProgress?.call(written, total);
        case ('done',):
          _done.complete();
        case ('error', final String kind, final String text, final int? code, final String? path):
          _done.completeError(_rebuild(kind, text, code, path));
        case null:
          // The exit notice with no answer before it: the isolate died.
          _done.completeError(StateError('the pack isolate died without answering'));
      }
    });
    try {
      if (!_done.isCompleted) {
        // The exit notice rides the answer port, so it can never overtake a
        // sent answer and misread a finished pack as a death.
        _isolate = await Isolate.spawn(_pack, (
          port.sendPort,
          target,
          bytes,
          files,
        ), onExit: port.sendPort);
        if (_done.isCompleted) {
          // Aborted while spawning: the isolate must not outlive the answer.
          _isolate!.kill(priority: Isolate.immediate);
          _isolate = null;
        }
      }
      await _done.future;
    } finally {
      port.close();
      _isolate = null;
    }
  }

  /// Stops the build now. The awaited [run] throws [ZipPackAborted]; a pack
  /// already settled is left alone.
  void abort() {
    if (_done.isCompleted) return;
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _done.completeError(const ZipPackAborted());
  }

  Object _rebuild(String kind, String text, int? code, String? path) => switch (kind) {
    'tooLarge' => StoredZipException(StoredZipError.tooLarge, text),
    'zip' => StoredZipException(StoredZipError.unsupported, text),
    'fs' => FileSystemException(text, path ?? target, code == null ? null : OSError(text, code)),
    _ => Exception(text),
  };

  static Future<void> _pack(
    (SendPort, String, List<(String, Uint8List)>, List<(String, String)>) args,
  ) async {
    final (port, target, bytes, files) = args;
    try {
      final writer = await StoredZipWriter.create(File(target));
      try {
        for (final (path, data) in bytes) {
          await writer.addBytes(path, data);
        }
        var written = 0;
        for (final (path, source) in files) {
          final file = File(source);
          if (!file.existsSync()) continue;
          await writer.addFile(path, file);
          written += file.lengthSync();
          port.send(written);
        }
        await writer.close();
      } catch (_) {
        await writer.abort();
        rethrow;
      }
      port.send(('done',));
    } on StoredZipException catch (e) {
      port.send((
        'error',
        e.error == StoredZipError.tooLarge ? 'tooLarge' : 'zip',
        e.message,
        null,
        null,
      ));
    } on FileSystemException catch (e) {
      port.send(('error', 'fs', e.message, e.osError?.errorCode, e.path));
    } catch (e) {
      port.send(('error', 'other', e.toString(), null, null));
    }
  }
}
