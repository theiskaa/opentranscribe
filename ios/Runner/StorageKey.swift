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

  // Only `absent` may generate a fresh key. Every other read outcome must fail
  // loudly: generating one over a key that exists but could not be read re-keys
  // the journal, and the user's whole history then decrypts as nothing.
  private enum KeyRead {
    case found(Data)
    case absent
    case failed(OSStatus)
    // The read succeeded but the item is not raw key data, which is not a
    // failure status and must not be reported as one. Carries what it was
    // instead, so this arm is as diagnosable as the ones carrying a status.
    case malformed(String)
  }

  private func obtain(result: @escaping FlutterResult) {
    switch readKey() {
    case .found(let existing):
      result(existing.base64EncodedString())
      return
    case .failed(let status):
      result(unavailable("SecItemCopyMatching failed: \(status)"))
      return
    case .malformed(let kind):
      result(unavailable("keychain item is not raw key data: \(kind)"))
      return
    case .absent:
      break
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
      // is just as valid as the one we generated. The re-read outcomes are told
      // apart because this message is the only diagnostic for a launch that is
      // otherwise undebuggable.
      switch readKey() {
      case .found(let existing):
        result(existing.base64EncodedString())
      case .absent:
        result(unavailable("duplicate item reported but the re-read found none"))
      case .failed(let status):
        result(unavailable("duplicate item reported but the re-read failed: \(status)"))
      case .malformed(let kind):
        result(unavailable("duplicate item reported but it is not raw key data: \(kind)"))
      }
      return
    }
    result(unavailable("SecItemAdd failed: \(addStatus)"))
  }

  private func readKey() -> KeyRead {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: storageKeyService,
      kSecAttrAccount as String: storageKeyAccount,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    if status == errSecItemNotFound { return .absent }
    guard status == errSecSuccess else { return .failed(status) }
    guard let data = item as? Data else {
      return .malformed(item.map { String(describing: type(of: $0)) } ?? "nil")
    }
    return .found(data)
  }

  private func unavailable(_ message: String) -> FlutterError {
    FlutterError(code: "storage_key_unavailable", message: message, details: nil)
  }
}
