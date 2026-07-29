import 'dart:convert';

import 'package:encrypt/encrypt.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Encrypted, persistent key-value storage backed by `SharedPreferences`.
///
/// [LocalService] is the home for small values that must outlive the app
/// process: the selected locale, theme, feature toggles, and any lightweight
/// user setting. Everything lives on the device and never leaves it.
///
/// All string and JSON values are encrypted on disk using AES-256-CBC with a
/// random IV per record. Plaintext keys stay in the clear, so do not encode
/// sensitive information into the key string itself. (No MAC: corruption
/// surfaces as a decrypt/parse failure, which readers already treat as a
/// skippable record; a real integrity story arrives with the Keychain key.)
///
/// ## Initialization
///
/// ```dart
/// final storage = LocalService();
/// await storage.init(encryptionKey: '<your-32-char-key>');
/// ```
///
/// Called once at startup (from [Deps.init]) before any read or write. The key
/// is padded or truncated to 32 characters internally; a real key should come
/// from a build-time `--dart-define` secret, not a literal in source.
class LocalService {
  late final SharedPreferences _prefs;
  late final Encrypter _aes;
  late final Encrypter _legacyFernet;

  // New records are 'v2:<iv>:<ciphertext>'. AES-CBC with a fresh random IV per
  // record, NOT Fernet: Fernet is a token format whose decrypt rejects any token
  // stamped more than a minute in the future, so a device clock rollback would
  // render the whole journal unreadable. At-rest storage must not depend on the
  // wall clock. Old Fernet records (no prefix) remain readable.
  static const _formatPrefix = 'v2:';

  /// Opens the underlying `SharedPreferences` and configures encryption.
  ///
  /// Must be called before any other method. [encryptionKey] is padded or
  /// truncated to 32 characters internally (counted in code units: prefer plain
  /// ASCII keys); an empty string disables encryption setup (string reads will
  /// throw; use only in tests).
  Future<void> init({required String encryptionKey}) async {
    _prefs = await SharedPreferences.getInstance();

    if (encryptionKey.isNotEmpty) {
      // All 32 padded characters feed the AES-256 key directly.
      final key = Key.fromUtf8(_padKey(encryptionKey));
      _aes = Encrypter(AES(key, mode: AESMode.cbc));
      _legacyFernet = Encrypter(Fernet(Key.fromUtf8(base64Url.encode(key.bytes).substring(0, 32))));
    }
  }

  /// Pads or truncates the key to exactly 32 characters.
  String _padKey(String key) {
    // AES-256 needs 32 BYTES; a non-ASCII char is >1 byte under Key.fromUtf8, so
    // 32 code units would not be 32 bytes and AES would reject the key. Catch
    // misuse in debug rather than at first encrypt; keys are expected ASCII.
    assert(
      key.codeUnits.every((c) => c < 128),
      'STORAGE_KEY must be ASCII: non-ASCII chars break the 32-byte AES key',
    );
    if (key.length >= 32) return key.substring(0, 32);
    return key.padRight(32, '0');
  }

  /// Encrypts a string value with a fresh random IV.
  ///
  /// Empty strings short-circuit because PKCS7 padding does not accept 0-byte
  /// input. An encrypted empty string round-trips as the literal empty string,
  /// which is unambiguous since real ciphertext is never empty.
  String _encrypt(String value) {
    if (value.isEmpty) return '';
    final iv = IV.fromSecureRandom(16);
    return '$_formatPrefix${iv.base64}:${_aes.encrypt(value, iv: iv).base64}';
  }

  /// Decrypts a stored value, accepting both the current format and legacy
  /// Fernet records written before the format change.
  String _decrypt(String encrypted) {
    if (encrypted.isEmpty) return '';
    if (encrypted.startsWith(_formatPrefix)) {
      final separator = encrypted.indexOf(':', _formatPrefix.length);
      if (separator < 0) throw const FormatException('malformed encrypted record');
      final iv = IV.fromBase64(encrypted.substring(_formatPrefix.length, separator));
      return _aes.decrypt64(encrypted.substring(separator + 1), iv: iv);
    }
    return _legacyFernet.decrypt64(encrypted);
  }

  /// Writes a value to local storage.
  ///
  /// String values are encrypted before storing. Supports [String], [int],
  /// [double], [bool], and `List<String>`. For complex objects, use
  /// [writeJson] instead. Throws [StateError] when the platform reports the
  /// write failed: persistence failures must surface, never pass silently
  /// (the in-memory cache would show the value until relaunch, then lose it).
  Future<void> write<T>(String key, T value) async {
    final ok = await switch (value) {
      final String v => _prefs.setString(key, _encrypt(v)),
      final int v => _prefs.setInt(key, v),
      final double v => _prefs.setDouble(key, v),
      final bool v => _prefs.setBool(key, v),
      final List<String> v => _prefs.setStringList(key, v.map(_encrypt).toList()),
      _ => throw ArgumentError('Unsupported type: ${value.runtimeType}'),
    };
    if (!ok) throw StateError('persist failed: $key');
  }

  /// Writes a JSON-serializable object to local storage (encrypted). Throws
  /// [StateError] when the platform reports the write failed; see [write].
  Future<void> writeJson(String key, Object value) async {
    final jsonString = jsonEncode(value);
    final ok = await _prefs.setString(key, _encrypt(jsonString));
    if (!ok) throw StateError('persist failed: $key');
  }

  /// Reads an encrypted string from local storage.
  String? readString(String key) {
    final value = _prefs.getString(key);
    if (value == null) return null;
    return _decrypt(value);
  }

  /// Reads a JSON object from local storage (decrypted).
  ///
  /// Returns `null` if the key doesn't exist. Use [fromJson] to convert the
  /// decoded JSON to your object.
  T? readJson<T>(String key, T Function(Map<String, dynamic>) fromJson) {
    final encrypted = _prefs.getString(key);
    if (encrypted == null) return null;
    final jsonString = _decrypt(encrypted);
    final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
    return fromJson(decoded);
  }

  /// Checks if a key exists in local storage.
  bool containsKey(String key) => _prefs.containsKey(key);

  /// Deletes a value from local storage.
  /// Removes [key]. Throws when the platform refuses, same rationale as
  /// [write]: the in-memory cache would show the value gone until relaunch,
  /// then resurrect it - for an entry record, a deleted entry coming back
  /// pointing at an already-deleted audio file.
  Future<bool> delete(String key) async {
    final ok = await _prefs.remove(key);
    if (!ok) throw StateError('LocalService.delete failed to persist: $key');
    return ok;
  }

  /// Clears all data from local storage.
  Future<bool> clear() => _prefs.clear();

  /// Finds all keys that start with the given prefix.
  Set<String> findKeysWithPrefix(String prefix) {
    return _prefs.getKeys().where((key) => key.startsWith(prefix)).toSet();
  }
}
