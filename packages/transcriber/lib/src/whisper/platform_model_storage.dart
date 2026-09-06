import 'dart:io';

import 'package:flutter/services.dart';

import 'package:transcriber/src/whisper/model_storage.dart';

// Must match AudioCapture.swift.
const _controlChannel = 'transcriber/audio';

/// The iOS-native [ModelStorage] on the recorder's channel: Application
/// Support/models, created like the recordings directory. A directory the
/// platform cannot provide throws a [FileSystemException], the caller's
/// launch-time failure to word.
class PlatformModelStorage implements ModelStorage {
  PlatformModelStorage({MethodChannel? methods})
    : _methods = methods ?? const MethodChannel(_controlChannel);

  final MethodChannel _methods;

  @override
  Future<Directory> modelsDirectory() async {
    try {
      final path = await _methods.invokeMethod<String>('modelsDirectory');
      if (path == null || path.isEmpty) throw const FileSystemException('no models directory');
      return Directory(path);
    } on PlatformException catch (e) {
      throw FileSystemException(e.message ?? e.code);
    } on MissingPluginException catch (e) {
      throw FileSystemException(e.message ?? 'no plugin');
    }
  }

  @override
  Future<int?> physicalMemoryBytes() async {
    try {
      final bytes = await _methods.invokeMethod<int>('physicalMemory');
      return bytes == null || bytes <= 0 ? null : bytes;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
