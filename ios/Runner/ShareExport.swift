import Flutter
import UIKit
import UniformTypeIdentifiers

// The app's one outward door for files: presents the system share sheet for
// staged export files, and the document picker for choosing an archive to
// import. Nothing here opens a socket; a file leaves the phone only through
// the sheet the user just asked for. Dart drives it through share_export.dart.

/// Channel error codes. Cross-boundary contract with share_export.dart.
private enum ShareExportError: String {
  case badArgs = "bad_args"
  case busy
  case unavailable

  func error(_ message: String) -> FlutterError {
    FlutterError(code: rawValue, message: message, details: nil)
  }
}

final class ShareExportPlugin: NSObject, FlutterPlugin {
  static func register(with registrar: FlutterPluginRegistrar) {
    // Channel name + payload shapes: must match share_export.dart.
    let methods = FlutterMethodChannel(
      name: "opentranscribe/share_export", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(ShareExportPlugin(), channel: methods)
  }

  // One presentation at a time, across BOTH surfaces: UIKit's present silently
  // no-ops on a controller mid-transition, which would strand the pending
  // FlutterResult forever. Answering busy instead keeps every future
  // answerable. pendingPick holds the picker's result until its delegate
  // fires; presenting covers the share sheet, whose result lives in its
  // completion handler.
  private var pendingPick: FlutterResult?
  private var presenting = false

  private var busyNow: Bool { presenting || pendingPick != nil }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "shareFiles":
      shareFiles(call, result: result)
    case "pickArchive":
      pickArchive(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func shareFiles(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
      let paths = args["paths"] as? [String], !paths.isEmpty
    else {
      result(ShareExportError.badArgs.error("shareFiles needs a non-empty paths list"))
      return
    }
    guard !busyNow else {
      result(ShareExportError.busy.error("a share or pick is already presenting"))
      return
    }
    guard let presenter = stablePresenter(result) else { return }
    let urls = paths.map { URL(fileURLWithPath: $0) }
    // Staged files carry the recordings directory's protection discipline.
    for url in urls {
      try? FileManager.default.setAttributes(
        [.protectionKey: FileProtectionType.completeUnlessOpen], ofItemAtPath: url.path)
    }
    let sheet = UIActivityViewController(activityItems: urls, applicationActivities: nil)
    var answered = false
    // Cancel is a normal outcome, not an error; Dart deletes the staging
    // files after either answer. The answered latch guards the handler's
    // historical double-fire on some iOS versions.
    sheet.completionWithItemsHandler = { [weak self] _, completed, _, _ in
      guard !answered else { return }
      answered = true
      DispatchQueue.main.async {
        self?.presenting = false
        result(["completed": completed])
      }
    }
    sheet.popoverPresentationController?.sourceView = presenter.view
    presenting = true
    presenter.present(sheet, animated: true)
  }

  private func pickArchive(result: @escaping FlutterResult) {
    guard !busyNow else {
      result(ShareExportError.busy.error("a share or pick is already presenting"))
      return
    }
    guard let presenter = stablePresenter(result) else { return }
    // .zip covers the plain archive; the sealed .otarchive resolves through
    // the UTExportedTypeDeclarations entry in Info.plist, which must keep
    // declaring xyz.opentranscribe.archive or sealed files grey out here.
    var types: [UTType] = [.zip]
    if let archive = UTType("xyz.opentranscribe.archive") {
      types.append(archive)
    }
    // asCopy hands us a sandbox-local copy, so no security-scoped access.
    let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: true)
    picker.allowsMultipleSelection = false
    picker.delegate = self
    pendingPick = result
    presenter.present(picker, animated: true)
  }

  /// The topmost controller when it can actually present right now, else
  /// answers the error itself and returns nil: no window is unavailable, a
  /// controller mid-presentation or mid-dismissal is busy (presenting on it
  /// would no-op and hang the pending result).
  private func stablePresenter(_ result: @escaping FlutterResult) -> UIViewController? {
    let scene = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first { $0.activationState == .foregroundActive }
    guard var controller = scene?.keyWindow?.rootViewController else {
      result(ShareExportError.unavailable.error("no view controller to present from"))
      return nil
    }
    while let presented = controller.presentedViewController, !presented.isBeingDismissed {
      controller = presented
    }
    if controller.isBeingPresented || controller.isBeingDismissed
      || controller.presentedViewController != nil
    {
      result(ShareExportError.busy.error("a presentation is in flight"))
      return nil
    }
    return controller
  }

  private func answerPick(_ path: String?) {
    guard let result = pendingPick else { return }
    pendingPick = nil
    DispatchQueue.main.async { result(["path": path as Any]) }
  }
}

extension ShareExportPlugin: UIDocumentPickerDelegate {
  func documentPicker(
    _ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]
  ) {
    answerPick(urls.first?.path)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    answerPick(nil)
  }
}
