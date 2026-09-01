import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';
import 'package:pointycastle/export.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Encrypted, persistent key-value storage backed by `SharedPreferences`.
///
/// [LocalService] is the home for small values that must outlive the app
/// process: the selected locale, theme, feature toggles, and any lightweight
/// user setting. Everything lives on the device and never leaves it.
///
/// New records are AES-256-GCM under a per-device Keychain key (see
/// [StorageKey]): authenticated, with a fresh random nonce per record. A
/// failed authentication (a tampered or corrupted record) throws; callers
/// already treat a thrown read as a skippable record, which is the correct
/// tamper response. Records written before the device key existed (`v2:`
/// AES-CBC, or bare legacy Fernet tokens) migrate to the new format in place
/// at launch; see [migrate]. Plaintext keys stay in the clear, so do not
/// encode sensitive information into the key string itself.
///
/// ## Initialization
///
/// ```dart
/// final storage = LocalService();
/// await storage.init(legacyKey: '<your-32-char-key>', deviceKey: keychainKey);
/// ```
///
/// Called once at startup (from [Deps.init]) before any read or write.
/// [legacyKey] is padded or truncated to 32 characters internally; it is
/// still required with a device key present, since old records need it to
/// read and migrate. A real key should come from a build-time `--dart-define`
/// secret, not a literal in source.
class LocalService {
  late final SharedPreferences _prefs;
  late final Encrypter _aes;
  late final Encrypter _legacyFernet;
  Uint8List? _deviceKey;

  // v2 records are 'v2:<iv>:<ciphertext>'. AES-CBC with a fresh random IV per
  // record, NOT Fernet: Fernet is a token format whose decrypt rejects any token
  // stamped more than a minute in the future, so a device clock rollback would
  // render the whole journal unreadable. At-rest storage must not depend on the
  // wall clock. Old Fernet records (no prefix) remain readable.
  static const _legacyFormatPrefix = 'v2:';

  // v3 records are 'v3:<nonce>:<ciphertext||tag>'. AES-256-GCM under the
  // per-device Keychain key; the 16-byte tag rides appended to the ciphertext,
  // which is what pointycastle's GCMBlockCipher.process produces and consumes.
  static const _formatPrefix = 'v3:';
  static const _nonceLength = 12;
  static const _macSizeBits = 128;

  /// Opens the underlying `SharedPreferences`, configures encryption, and
  /// (when [deviceKey] is supplied) migrates any legacy record to the new
  /// format.
  ///
  /// Must be called before any other method. [legacyKey] is padded or
  /// truncated to 32 characters internally (counted in code units: prefer
  /// plain ASCII keys); an empty string disables legacy-key setup (reading a
  /// legacy record will then throw; use only in tests). When [deviceKey] is
  /// `null`, [LocalService] behaves exactly as it did before this key
  /// existed: writes produce `v2:` records, and reads accept `v2:` and
  /// legacy Fernet records. When [deviceKey] is supplied (exactly 32 bytes),
  /// writes produce `v3:` records and every stored value is migrated to `v3:`
  /// in place before [init] returns.
  ///
  /// [channelTimeout] bounds the OPEN only, the one round trip here that a
  /// wedged platform channel can park forever. It deliberately does not cover
  /// [migrate], which is bounded work that always finishes and legitimately
  /// takes seconds on a large journal.
  Future<void> init({
    required String legacyKey,
    Uint8List? deviceKey,
    Duration? channelTimeout,
  }) async {
    final open = SharedPreferences.getInstance();
    _prefs = channelTimeout == null ? await open : await open.timeout(channelTimeout);
    _deviceKey = deviceKey;

    if (legacyKey.isNotEmpty) {
      // All 32 padded characters feed the AES-256 key directly.
      final key = Key.fromUtf8(_padKey(legacyKey));
      _aes = Encrypter(AES(key, mode: AESMode.cbc));
      _legacyFernet = Encrypter(Fernet(Key.fromUtf8(base64Url.encode(key.bytes).substring(0, 32))));
    }

    if (deviceKey != null) await migrate();
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

  /// Encrypts a string value, under the device key when one was supplied at
  /// [init], otherwise under the legacy key (unchanged `v2:` behavior).
  ///
  /// Empty strings short-circuit because an encrypted empty string is
  /// otherwise ambiguous with "no value"; it round-trips as the literal empty
  /// string, which is unambiguous since real ciphertext is never empty.
  String _encrypt(String value) {
    if (value.isEmpty) return '';
    final deviceKey = _deviceKey;
    return deviceKey != null ? _encryptV3(value, deviceKey) : _encryptLegacy(value);
  }

  String _encryptLegacy(String value) {
    final iv = IV.fromSecureRandom(16);
    return '$_legacyFormatPrefix${iv.base64}:${_aes.encrypt(value, iv: iv).base64}';
  }

  String _encryptV3(String value, Uint8List deviceKey) {
    final nonce = _randomNonce();
    final sealed = _gcm(true, deviceKey, nonce).process(Uint8List.fromList(utf8.encode(value)));
    return '$_formatPrefix${base64.encode(nonce)}:${base64.encode(sealed)}';
  }

  Uint8List _randomNonce() {
    final random = Random.secure();
    return Uint8List.fromList([for (var i = 0; i < _nonceLength; i++) random.nextInt(256)]);
  }

  static GCMBlockCipher _gcm(bool forEncryption, Uint8List deviceKey, Uint8List nonce) {
    return GCMBlockCipher(AESEngine())..init(
      forEncryption,
      AEADParameters(KeyParameter(deviceKey), _macSizeBits, nonce, Uint8List(0)),
    );
  }

  /// Decrypts a stored value, accepting the current `v3:` format, the
  /// previous `v2:` format, and legacy Fernet records written before either
  /// format change.
  String _decrypt(String encrypted) {
    if (encrypted.isEmpty) return '';
    if (encrypted.startsWith(_formatPrefix)) return _decryptV3(encrypted);
    return _decryptLegacy(encrypted);
  }

  String _decryptV3(String encrypted) {
    final deviceKey = _deviceKey;
    // A v3 record with no device key configured is a wiring bug (init() was
    // not given the key that wrote it), not corruption: it must not be
    // silently treated like a skippable bad record.
    if (deviceKey == null) {
      throw StateError('a v3 record was read but init() was not given a device key');
    }
    return _decryptV3Record(deviceKey, encrypted);
  }

  /// The v3 decrypt core. Static so [readAllOnIsolate]'s isolate closure
  /// captures no instance.
  static String _decryptV3Record(Uint8List deviceKey, String encrypted) {
    final separator = encrypted.indexOf(':', _formatPrefix.length);
    if (separator < 0) throw const FormatException('malformed encrypted record');
    final nonce = base64.decode(encrypted.substring(_formatPrefix.length, separator));
    final sealed = base64.decode(encrypted.substring(separator + 1));
    // InvalidCipherTextException (thrown on a failed tag check) is a
    // pointycastle Exception, which readers already treat as a skippable
    // decrypt failure like any other thrown read.
    final plaintext = _gcm(false, deviceKey, nonce).process(sealed);
    return utf8.decode(plaintext);
  }

  String _decryptLegacy(String encrypted) {
    if (encrypted.isEmpty) return '';
    if (encrypted.startsWith(_legacyFormatPrefix)) return _decryptLegacyV2(encrypted);
    return _legacyFernet.decrypt64(encrypted);
  }

  String _decryptLegacyV2(String encrypted) {
    final separator = encrypted.indexOf(':', _legacyFormatPrefix.length);
    if (separator < 0) throw const FormatException('malformed encrypted record');
    final iv = IV.fromBase64(encrypted.substring(_legacyFormatPrefix.length, separator));
    return _aes.decrypt64(encrypted.substring(separator + 1), iv: iv);
  }

  /// Migrates every legacy (`v2:` or bare Fernet) record to `v3:` under the
  /// device key. Idempotent (a `v3:` record is left untouched), per-record
  /// atomic (each rewrite is one `setString`/`setStringList` call), and
  /// interruption-safe: a record not yet reached still decrypts through the
  /// legacy arm, so a killed migration simply resumes where it left off on
  /// the next launch. A record that fails to decrypt under the legacy key is
  /// left exactly as it is: it was already unreadable before this method ran,
  /// and migration must not turn a skippable corrupt record into data loss.
  Future<void> migrate() async {
    final deviceKey = _deviceKey;
    if (deviceKey == null) return;

    for (final key in _prefs.getKeys().toList()) {
      // getString/getStringList each throw on a type mismatch (a bool, int, or
      // double stored under this key), so branch on the raw value's runtime
      // type first rather than probing with the typed getters.
      switch (_prefs.get(key)) {
        case final String value:
          await _migrateString(key, value, deviceKey);
        case List<Object?>():
          await _migrateStringList(key, _prefs.getStringList(key)!, deviceKey);
        default:
          break;
      }
    }
  }

  bool _alreadyMigrated(String value) => value.isEmpty || value.startsWith(_formatPrefix);

  Future<void> _migrateString(String key, String stored, Uint8List deviceKey) async {
    if (_alreadyMigrated(stored)) return;
    final String plaintext;
    try {
      plaintext = _decryptLegacy(stored);
    } catch (_) {
      return;
    }
    await _prefs.setString(key, _encryptV3(plaintext, deviceKey));
  }

  Future<void> _migrateStringList(String key, List<String> stored, Uint8List deviceKey) async {
    if (stored.every(_alreadyMigrated)) return;
    var changed = false;
    final migrated = [
      for (final value in stored)
        if (_alreadyMigrated(value))
          value
        else
          _migratedElement(value, deviceKey, onChanged: () => changed = true),
    ];
    if (changed) await _prefs.setStringList(key, migrated);
  }

  String _migratedElement(String value, Uint8List deviceKey, {required void Function() onChanged}) {
    final String plaintext;
    try {
      plaintext = _decryptLegacy(value);
    } catch (_) {
      return value;
    }
    onChanged();
    return _encryptV3(plaintext, deviceKey);
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

  /// Reads every JSON record under [prefix], decrypting and parsing on a
  /// worker isolate, so a whole-journal read can run off the frames the user
  /// is watching. Corrupt records are skipped, like the synchronous reads.
  /// Returns null when the work cannot leave the main isolate (no device key
  /// yet, or a record still in a legacy format): callers then fall back to
  /// the synchronous path.
  Future<List<T>?> readAllOnIsolate<T>(
    String prefix,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final deviceKey = _deviceKey;
    if (deviceKey == null) return null;
    final sealed = <String>[];
    for (final key in findKeysWithPrefix(prefix)) {
      // Raw read: getString throws on a non-String value, and a bad key must
      // be skipped here exactly as the synchronous reads skip it.
      final value = _prefs.get(key);
      if (value is! String || value.isEmpty) continue;
      if (!value.startsWith(_formatPrefix)) return null;
      sealed.add(value);
    }
    // An isolate costs more than it saves on a journal this small.
    if (sealed.isEmpty) return <T>[];
    return Isolate.run(() {
      final out = <T>[];
      for (final record in sealed) {
        try {
          final decoded = jsonDecode(_decryptV3Record(deviceKey, record)) as Map<String, dynamic>;
          out.add(fromJson(decoded));
        } catch (_) {
          continue;
        }
      }
      return out;
    });
  }
}
