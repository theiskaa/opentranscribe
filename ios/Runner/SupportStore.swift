import Flutter
import StoreKit
import UIKit

// The app's one door to StoreKit: prices, the purchase sheet, and the local
// entitlement walk. The OS talks to the App Store; no journal content is in
// that conversation, and nothing here opens a socket of its own. Dart drives
// it through support_store.dart.

/// Channel error codes. Cross-boundary contract with support_store.dart.
private enum SupportErrorCode: String {
  case badArgs = "bad_args"
  case busy
  case unavailable
  case unverified
  case failed

  func error(_ message: String) -> FlutterError {
    FlutterError(code: rawValue, message: message, details: nil)
  }
}

final class SupportStorePlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    // Channel names + payload shapes: must match support_store.dart.
    let methods = FlutterMethodChannel(
      name: "opentranscribe/support", binaryMessenger: registrar.messenger())
    let events = FlutterEventChannel(
      name: "opentranscribe/support/events", binaryMessenger: registrar.messenger())
    let plugin = SupportStorePlugin()
    registrar.addMethodCallDelegate(plugin, channel: methods)
    events.setStreamHandler(plugin)
    // Started at registration, before Dart asks anything: transactions left
    // unfinished by a killed purchase, an Ask to Buy approval, or a renewal
    // while dead all land here on the next launch.
    plugin.startUpdatesListener()
  }

  private var sink: FlutterEventSink?

  // One presented purchase at a time: a second sheet over the first would
  // strand its pending FlutterResult, the ShareExport rule.
  private var presenting = false

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "products":
      products(call, result: result)
    case "purchase":
      purchase(call, result: result)
    case "entitlement":
      entitlement(result: result)
    case "restore":
      restore(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func products(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
      let ids = args["ids"] as? [String], !ids.isEmpty
    else {
      result(SupportErrorCode.badArgs.error("products needs a non-empty ids list"))
      return
    }
    Task { @MainActor in
      do {
        let products = try await Product.products(for: ids)
        let byID = Dictionary(products.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        // Answered in the asked order, so Dart's rows never reshuffle.
        let payload: [[String: Any]] = ids.compactMap { id in
          guard let product = byID[id] else { return nil }
          return ["id": product.id, "displayPrice": product.displayPrice]
        }
        result(payload)
      } catch {
        result(SupportErrorCode.unavailable.error(error.localizedDescription))
      }
    }
  }

  private func purchase(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any], let id = args["id"] as? String else {
      result(SupportErrorCode.badArgs.error("purchase needs a product id"))
      return
    }
    guard !presenting else {
      result(SupportErrorCode.busy.error("a flow is already presenting"))
      return
    }
    presenting = true
    Task { @MainActor in
      defer { presenting = false }
      // The resolve step fails for the same reason products does (store
      // unreachable), so it answers the same code, not a purchase failure.
      let resolved: Product?
      do {
        resolved = try await Product.products(for: [id]).first
      } catch {
        result(SupportErrorCode.unavailable.error(error.localizedDescription))
        return
      }
      guard let product = resolved else {
        result(SupportErrorCode.failed.error("unknown product \(id)"))
        return
      }
      do {
        let outcome: Product.PurchaseResult
        if #available(iOS 18.2, *), let scene = Self.activeScene() {
          outcome = try await product.purchase(confirmIn: scene)
        } else {
          outcome = try await product.purchase()
        }
        switch outcome {
        case .success(let verification):
          guard case .verified(let transaction) = verification else {
            result(SupportErrorCode.unverified.error("purchase failed local verification"))
            return
          }
          await transaction.finish()
          result(["outcome": "purchased"])
        case .userCancelled:
          result(["outcome": "cancelled"])
        case .pending:
          result(["outcome": "pending"])
        @unknown default:
          result(SupportErrorCode.failed.error("unknown purchase result"))
        }
      } catch StoreKitError.userCancelled {
        // Cancel occasionally arrives thrown instead of as .userCancelled;
        // either way it is an outcome, never an error.
        result(["outcome": "cancelled"])
      } catch {
        result(SupportErrorCode.failed.error(error.localizedDescription))
      }
    }
  }

  private func entitlement(result: @escaping FlutterResult) {
    Task { @MainActor in
      result(["tier": await Self.currentTier()])
    }
  }

  private func restore(result: @escaping FlutterResult) {
    Task { @MainActor in
      do {
        try await AppStore.sync()
      } catch StoreKitError.userCancelled {
        // A declined Apple ID prompt is a cancel, not a failure: nothing
        // synced, and the local walk below is still the truth.
      } catch {
        result(SupportErrorCode.failed.error(error.localizedDescription))
        return
      }
      result(["tier": await Self.currentTier()])
    }
  }

  private func startUpdatesListener() {
    // App-lifetime, like every Runner plugin: the registrar keeps the plugin
    // alive and the loop never ends, so there is no cancel story to carry.
    Task {
      for await update in Transaction.updates {
        guard case .verified(let transaction) = update else { continue }
        await transaction.finish()
        let tier = await Self.currentTier()
        await MainActor.run {
          self.sink?(["tier": tier])
        }
      }
    }
  }

  /// The tier StoreKit's own on-device record answers for right now, from
  /// verified transactions only. Classified by product type, not id, so the
  /// Swift side never names a product: any non-consumable is the lifetime
  /// unlock. Revoked transactions never appear in the sequence.
  private static func currentTier() async -> String {
    for await entitlement in Transaction.currentEntitlements {
      guard case .verified(let transaction) = entitlement else { continue }
      if transaction.productType == .nonConsumable { return "lifetime" }
    }
    return "none"
  }

  @MainActor
  private static func activeScene() -> UIWindowScene? {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive }
  }
}

extension SupportStorePlugin: FlutterStreamHandler {
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    sink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }
}
