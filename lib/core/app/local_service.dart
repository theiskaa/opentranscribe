import 'dart:convert';

import 'package:encrypt/encrypt.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Encrypted, persistent key-value storage backed by `SharedPreferences`.
///
/// [LocalService] is the home for small values that must outlive the app
/// process: the selected locale, theme, feature toggles, and any lightweight
/// user setting. Everything lives on the device and never leaves it.
///
/// All string and JSON values are encrypted on disk using Fernet
/// (symmetric AES-CBC + HMAC). Plaintext keys stay in the clear, so do not
/// encode sensitive information into the key string itself.
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
  late final Encrypter _encrypter;

  /// Opens the underlying `SharedPreferences` and configures encryption.
  ///
  /// Must be called before any other method. [encryptionKey] is padded or
  /// truncated to 32 characters internally; an empty string disables
  /// encryption setup (string reads will throw — use only in tests).
  Future<void> init({required String encryptionKey}) async {
    _prefs = await SharedPreferences.getInstance();

    if (encryptionKey.isNotEmpty) {
      final key = Key.fromUtf8(_padKey(encryptionKey));
      final fernet = Fernet(Key.fromUtf8(base64Url.encode(key.bytes).substring(0, 32)));
      _encrypter = Encrypter(fernet);
    }
  }

  /// Pads or truncates the key to exactly 32 characters.
  String _padKey(String key) {
    if (key.length >= 32) return key.substring(0, 32);
    return key.padRight(32, '0');
  }

  /// Encrypts a string value.
  ///
  /// Empty strings short-circuit because Fernet's PKCS7 padding does not
  /// accept 0-byte input. An encrypted empty string round-trips as the
  /// literal empty string, which is unambiguous since real Fernet
  /// ciphertext is never empty.
  String _encrypt(String value) {
    if (value.isEmpty) return '';
    return _encrypter.encrypt(value).base64;
  }

  /// Decrypts an encrypted string value.
  String _decrypt(String encrypted) {
    if (encrypted.isEmpty) return '';
    return _encrypter.decrypt64(encrypted);
  }

  /// Writes a value to local storage.
  ///
  /// String values are encrypted before storing. Supports [String], [int],
  /// [double], [bool], and `List<String>`. For complex objects, use
  /// [writeJson] instead.
  Future<bool> write<T>(String key, T value) async {
    return switch (value) {
      final String v => _prefs.setString(key, _encrypt(v)),
      final int v => _prefs.setInt(key, v),
      final double v => _prefs.setDouble(key, v),
      final bool v => _prefs.setBool(key, v),
      final List<String> v => _prefs.setStringList(key, v.map(_encrypt).toList()),
      _ => throw ArgumentError('Unsupported type: ${value.runtimeType}'),
    };
  }

  /// Writes a JSON-serializable object to local storage (encrypted).
  Future<bool> writeJson(String key, Object value) async {
    final jsonString = jsonEncode(value);
    return _prefs.setString(key, _encrypt(jsonString));
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
  Future<bool> delete(String key) => _prefs.remove(key);

  /// Clears all data from local storage.
  Future<bool> clear() => _prefs.clear();

  /// Finds all keys that start with the given prefix.
  Set<String> findKeysWithPrefix(String prefix) {
    return _prefs.getKeys().where((key) => key.startsWith(prefix)).toSet();
  }
}
