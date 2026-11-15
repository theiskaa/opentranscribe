import Flutter
import UIKit

// What the display reserves around the Flutter view, read from local UIKit
// state only. Dart reads it through core/utils/display_regions.dart.

final class DisplayRegionsPlugin: NSObject, FlutterPlugin, FlutterSceneLifeCycleDelegate {
  static func register(with registrar: FlutterPluginRegistrar) {
    // Channel names: display_regions.dart; payload keys: display_signal.dart.
    let methods = FlutterMethodChannel(
      name: "opentranscribe/display", binaryMessenger: registrar.messenger())
    let events = FlutterEventChannel(
      name: "opentranscribe/display/events", binaryMessenger: registrar.messenger())
    let plugin = DisplayRegionsPlugin(registrar: registrar)
    registrar.addMethodCallDelegate(plugin, channel: methods)
    registrar.addSceneDelegate(plugin)
    events.setStreamHandler(plugin)
  }

  private weak var registrar: FlutterPluginRegistrar?
  private var sink: FlutterEventSink?
  private var probe: DisplayProbeView?

  init(registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "current":
      // Channel handlers run on the platform thread, which is the main one.
      result(
        MainActor.assumeIsolated {
          attach()
          return probe?.current() ?? DisplayProbeView.detached
        })
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // The controller's view may not be loaded when Dart first listens; the
  // scene turning active is the first moment it surely is.
  func sceneDidBecomeActive(_ scene: UIScene) {
    MainActor.assumeIsolated { attach() }
  }

  @MainActor private func attach() {
    guard probe == nil, let host = registrar?.viewController?.viewIfLoaded else { return }
    let view = DisplayProbeView(frame: host.bounds)
    view.onSettled = { [weak self] payload in self?.sink?(payload) }
    host.addSubview(view)
    probe = view
  }
}

extension DisplayRegionsPlugin: FlutterStreamHandler {
  func onListen(withArguments arguments: Any?, eventSink: @escaping FlutterEventSink)
    -> FlutterError?
  {
    sink = eventSink
    MainActor.assumeIsolated {
      attach()
      if let settled = probe?.settled { eventSink(settled.payload) }
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }
}

private struct RegionReading: Equatable {
  var kind: String
  var frame: CGRect
  var active: Bool

  var payload: [String: Any] {
    [
      "kind": kind, "active": active,
      "x": frame.minX, "y": frame.minY, "width": frame.width, "height": frame.height,
    ]
  }
}

private struct DisplayReading: Equatable {
  // Region frames land on pixel boundaries at 3x, which can put a point's
  // fraction past the view's edge without the region being anywhere else.
  static let slack: CGFloat = 0.5

  // No window reserves this much at a side without a vertical bar standing
  // there; the cover's bar column is 84.
  static let barInset: CGFloat = 80

  var supported = false
  var size = CGSize.zero
  var horizontal = "unspecified"
  var insets = UIEdgeInsets.zero
  var fullScreen = false
  var barSide = "none"
  var regions: [RegionReading] = []
  var reduceTransparency = false

  var payload: [String: Any] {
    [
      "supported": supported,
      "width": size.width, "height": size.height,
      "horizontal": horizontal,
      "insets": [
        "top": insets.top, "left": insets.left, "bottom": insets.bottom, "right": insets.right,
      ],
      "fullScreen": fullScreen,
      "barSide": barSide,
      "regions": regions.map(\.payload),
      "reduceTransparency": reduceTransparency,
    ]
  }

  // A pass can run with the view resized but its host not yet, or the
  // reverse; only a reading of the whole current view describes it.
  func isWhole(in host: CGSize) -> Bool {
    size.width > 0 && size.height > 0 && size == host
      && insets.left + insets.right < size.width && insets.top + insets.bottom < size.height
  }

  // Across a display switch UIKit first reports the other display's regions
  // beside this one's size and insets, and the bar trait can lag the insets.
  var isSuspect: Bool {
    let outside = regions.contains { !bounds.contains($0.frame) }
    let divisions = regions.filter { $0.kind == "division" }
    let foldShort = divisions.contains { !spansView($0.frame) }
    let foldWhileCompact = horizontal == "compact" && !divisions.isEmpty
    let barlessColumn = barSide == "none" && max(insets.left, insets.right) >= Self.barInset
    return outside || foldShort || foldWhileCompact || barlessColumn
  }

  // A fold crosses the whole view: top to bottom when it stands, side to side
  // when it lies. Clipped to a Split View half it still does.
  private func spansView(_ frame: CGRect) -> Bool {
    if frame.height >= frame.width {
      return frame.minY <= Self.slack && frame.maxY >= size.height - Self.slack
    }
    return frame.minX <= Self.slack && frame.maxX >= size.width - Self.slack
  }

  func clipped() -> DisplayReading {
    var kept = self
    let view = CGRect(origin: .zero, size: size)
    kept.regions = regions.compactMap { region in
      let frame = region.frame.intersection(view)
      guard !frame.isNull, !frame.isEmpty else { return nil }
      var cut = region
      cut.frame = frame
      return cut
    }
    return kept
  }

  private var bounds: CGRect {
    CGRect(origin: .zero, size: size).insetBy(dx: -Self.slack, dy: -Self.slack)
  }
}

private final class DisplayProbeView: UIView {
  static let detached: [String: Any] = ["supported": false]
  private static let recheckDelay: TimeInterval = 0.5
  private static let rechecksPerEpisode = 3

  var onSettled: (([String: Any]) -> Void)?
  private(set) var settled: DisplayReading?

  private var pending: DisplayReading?
  private var lastLayoutReading: DisplayReading?
  private var suspect: DisplayReading?
  private var suspectSince: CFTimeInterval = 0
  private var episode = 0
  private var flushQueued = false
  private var transparencyObserver: NSObjectProtocol?

  // Opts into the constraints pass, the one where reserved regions settle,
  // though this view carries no constraints of its own.
  override class var requiresConstraintBasedLayout: Bool { true }

  override init(frame: CGRect) {
    super.init(frame: frame)
    autoresizingMask = [.flexibleWidth, .flexibleHeight]
    isUserInteractionEnabled = false
    isAccessibilityElement = false
    accessibilityElementsHidden = true
    isOpaque = false
    backgroundColor = .clear
    registerForTraitChanges([UITraitHorizontalSizeClass.self, UITraitLayoutDirection.self]) {
      (view: DisplayProbeView, _: UITraitCollection) in
      view.setNeedsUpdateConstraints()
    }
    if #available(iOS 27.1, *) {
      registerForTraitChanges(UITraitCollection.systemTraitsAffectingVerticalBarEdge) {
        (view: DisplayProbeView, _: UITraitCollection) in
        view.setNeedsUpdateConstraints()
      }
    }
    transparencyObserver = NotificationCenter.default.addObserver(
      forName: UIAccessibility.reduceTransparencyStatusDidChangeNotification, object: nil,
      queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.setNeedsUpdateConstraints() }
    }
  }

  required init?(coder: NSCoder) { fatalError("built in code only") }

  deinit {
    if let transparencyObserver { NotificationCenter.default.removeObserver(transparencyObserver) }
  }

  // The tracked read: UIKit runs this pass again when a region it read changes.
  override func updateConstraints() {
    super.updateConstraints()
    pending = read()
    queueFlush()
  }

  // Read here too so layout tracks the regions, but only to ask for a
  // constraints pass; a reading that has not changed asks for nothing.
  override func layoutSubviews() {
    super.layoutSubviews()
    let reading = read()
    if reading != lastLayoutReading {
      lastLayoutReading = reading
      setNeedsUpdateConstraints()
    }
  }

  override func safeAreaInsetsDidChange() {
    super.safeAreaInsetsDidChange()
    setNeedsUpdateConstraints()
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    setNeedsUpdateConstraints()
  }

  // The settled reading, or a plain unsupported one until a pass settles.
  func current() -> [String: Any] {
    settled?.payload ?? plainReading().payload
  }

  // A burst of passes lands on the next runloop turn as its last reading, so
  // Dart never sees the states a display switch passes through.
  private func queueFlush() {
    guard !flushQueued else { return }
    flushQueued = true
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.flushQueued = false
      guard let reading = self.pending, self.isWhole(reading) else { return }
      self.weigh(reading)
    }
  }

  private func isWhole(_ reading: DisplayReading) -> Bool {
    reading.size == bounds.size && reading.isWhole(in: superview?.bounds.size ?? .zero)
  }

  // A suspect seen again a full delay after its first sighting is real: a
  // Split View half can hold part of the fold.
  private func weigh(_ reading: DisplayReading) {
    if reading.clipped() == settled { return finishEpisode() }
    guard reading.isSuspect else { return settle(reading) }
    let now = CACurrentMediaTime()
    if reading == suspect {
      if now - suspectSince >= Self.recheckDelay { settle(reading) }
      return
    }
    if suspect == nil { scheduleRecheck(in: episode, left: Self.rechecksPerEpisode) }
    suspect = reading
    suspectSince = now
  }

  // Capped per episode so replacing suspects still end; at the cap a fresh
  // whole reading beats the stored one.
  private func scheduleRecheck(in episode: Int, left: Int) {
    DispatchQueue.main.asyncAfter(deadline: .now() + Self.recheckDelay) { [weak self] in
      guard let self, episode == self.episode, let suspect = self.suspect else { return }
      self.setNeedsUpdateConstraints()
      guard left <= 1 else { return self.scheduleRecheck(in: episode, left: left - 1) }
      self.updateConstraintsIfNeeded()
      if let fresh = self.pending, self.isWhole(fresh) {
        self.settle(fresh)
      } else {
        self.settle(suspect)
      }
    }
  }

  // Ends the wait on a suspect, its rechecks with it.
  private func finishEpisode() {
    suspect = nil
    episode += 1
  }

  private func settle(_ reading: DisplayReading) {
    finishEpisode()
    let kept = reading.clipped()
    guard kept != settled else { return }
    settled = kept
    onSettled?(kept.payload)
  }

  private func read() -> DisplayReading {
    var reading = plainReading()
    if #available(iOS 27.1, *) { addReserved(to: &reading) }
    return reading
  }

  // What every iOS reports; on its own it reads as unsupported.
  private func plainReading() -> DisplayReading {
    DisplayReading(
      size: bounds.size,
      horizontal: Self.encode(traitCollection.horizontalSizeClass),
      insets: safeAreaInsets,
      fullScreen: fillsScreen,
      reduceTransparency: UIAccessibility.isReduceTransparencyEnabled
    )
  }

  @available(iOS 27.1, *)
  private func addReserved(to reading: inout DisplayReading) {
    reading.supported = true
    reading.barSide = physicalSide(traitCollection.verticalBarEdge)
    let kinds: [(UIView.ReservedRegion.Kind, String)] = [
      (.division, "division"), (.occlusion, "occlusion"),
    ]
    for (kind, name) in kinds {
      for region in reservedRegions(kind: kind, options: .includeInactive) {
        reading.regions.append(
          RegionReading(kind: name, frame: region.frame, active: region.isActive))
      }
    }
  }

  // Split View and Slide Over windows are smaller than their screen, in
  // either orientation the screen's bounds report.
  private var fillsScreen: Bool {
    guard let window, let screen = window.windowScene?.screen.bounds.size else { return false }
    let size = window.bounds.size
    return size == screen || size == CGSize(width: screen.height, height: screen.width)
  }

  @available(iOS 27.1, *)
  private func physicalSide(_ edge: UIVerticalBarEdge) -> String {
    let rtl = effectiveUserInterfaceLayoutDirection == .rightToLeft
    switch edge {
    case .leading: return rtl ? "right" : "left"
    case .trailing: return rtl ? "left" : "right"
    case .unspecified: return "none"
    @unknown default: return "none"
    }
  }

  private static func encode(_ size: UIUserInterfaceSizeClass) -> String {
    switch size {
    case .compact: return "compact"
    case .regular: return "regular"
    case .unspecified: return "unspecified"
    @unknown default: return "unspecified"
    }
  }
}
