import 'dart:convert';

import 'package:flutter/services.dart';

const _channel = 'opentranscribe/storage_key';
const _keyLength = 32;

/// Obtains the per-device journal encryption key from the iOS Keychain.
///
/// [StorageKey] talks to `StorageKey.swift` over a `MethodChannel`. The key
/// is generated once, on the device's first launch, and held in the Keychain
/// under `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`: it never leaves
/// the device (not through iCloud, not through a device backup), and it is
/// stable across every later launch on the same device.
///
/// [obtain] always returns exactly 32 bytes or throws [StorageKeyException];
/// it never returns a degraded or partial key, so callers must not catch this
/// exception and fall back to a weaker key.
class StorageKey {
  StorageKey({MethodChannel? methods}) : _methods = methods ?? const MethodChannel(_channel);

  final MethodChannel _methods;

  /// Returns the device's 32-byte storage key, generating and persisting one
  /// in the Keychain on first call.
  Future<Uint8List> obtain() async {
    final String encoded;
    try {
      final raw = await _methods.invokeMethod<String>('obtain');
      if (raw == null) throw const StorageKeyException('obtain returned no key');
      encoded = raw;
    } on PlatformException catch (e) {
      throw StorageKeyException(e.message, e.code);
    } on MissingPluginException catch (e) {
      throw StorageKeyException(e.message);
    }

    final Uint8List bytes;
    try {
      bytes = base64Decode(encoded);
    } on FormatException catch (e) {
      throw StorageKeyException('obtain returned malformed base64: ${e.message}');
    }
    if (bytes.length != _keyLength) {
      throw StorageKeyException('obtain returned ${bytes.length} bytes, expected $_keyLength');
    }
    return bytes;
  }
}

/// Thrown when the device's Keychain-held storage key could not be obtained.
///
/// Always fatal to the caller: a missing or unreadable device key must never
/// be papered over with a fallback key, since that would either silently
/// re-encrypt the journal under a key nobody can reproduce, or, worse, present
/// an empty journal.
class StorageKeyException implements Exception {
  const StorageKeyException(this.message, [this.code]);

  final String? message;
  final String? code;

  @override
  String toString() => 'StorageKeyException(${code ?? 'no code'}): ${message ?? 'no message'}';
}
