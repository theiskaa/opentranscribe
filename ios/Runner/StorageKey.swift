import Flutter
import Foundation
import Security

// The journal's per-device encryption key. Generated once on first launch and
// held in the Keychain (kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly), so
// it never appears in the binary and never leaves the device via backup or
// iCloud. Dart obtains it through storage_key.dart; see local_service.dart for
// how it is used.

private let storageKeyService = "xyz.opentranscribe.storage"
private let storageKeyAccount = "journal-key"
private let storageKeyLength = 32

final class StorageKeyPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    let methods = FlutterMethodChannel(
      name: "opentranscribe/storage_key", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(StorageKeyPlugin(), channel: methods)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "obtain":
      obtain(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func obtain(result: @escaping FlutterResult) {
    if let existing = readKey() {
      result(existing.base64EncodedString())
      return
    }

    var bytes = [UInt8](repeating: 0, count: storageKeyLength)
    let status = SecRandomCopyBytes(kSecRandomDefault, storageKeyLength, &bytes)
    guard status == errSecSuccess else {
      result(unavailable("SecRandomCopyBytes failed: \(status)"))
      return
    }
    let generated = Data(bytes)

    let addQuery: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: storageKeyService,
      kSecAttrAccount as String: storageKeyAccount,
      kSecValueData as String: generated,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    ]
    let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
    if addStatus == errSecSuccess {
      result(generated.base64EncodedString())
      return
    }
    if addStatus == errSecDuplicateItem {
      // Another writer raced us (e.g. a second launch path); the item it wrote
      // is just as valid as the one we generated.
      if let existing = readKey() {
        result(existing.base64EncodedString())
      } else {
        result(unavailable("duplicate item reported but re-read failed"))
      }
      return
    }
    result(unavailable("SecItemAdd failed: \(addStatus)"))
  }

  private func readKey() -> Data? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: storageKeyService,
      kSecAttrAccount as String: storageKeyAccount,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status == errSecSuccess, let data = item as? Data else { return nil }
    return data
  }

  private func unavailable(_ message: String) -> FlutterError {
    FlutterError(code: "storage_key_unavailable", message: message, details: nil)
  }
}
