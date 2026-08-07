import Flutter
import UIKit

/// A native UISegmentedControl behind the LiquidSegmentedControl Flutter widget.
/// On iOS 26 it adopts Liquid Glass automatically; below it, it is the plain
/// system segmented control. Selection is driven by `selectedIndex` and only
/// moved on a genuine external change, so a Flutter rebuild never fights a tap.
final class LiquidSegmentedControlView: LiquidNativeView {
  private let control: UISegmentedControl

  // Last-applied styling, so a selection change (which re-sends every param)
  // never re-runs the expensive work. Re-setting overrideUserInterfaceStyle,
  // the tint, or the title attributes forces the glass material to recompute;
  // doing that a frame into the indicator's own slide is what read as a
  // stutter. A theme-selector tap does change these for real (the whole app
  // flips), and the cache lets that through since the values genuinely differ.
  private var appliedIsDark: Bool?
  private var appliedEnabled: Bool?
  private var appliedLabel: String?
  private var appliedTint: UIColor?
  private var appliedLabelColor: UIColor?
  private var appliedSelectedLabelColor: UIColor?

  init(registrar: FlutterPluginRegistrar, viewId: Int64, arguments: Any?) {
    let params = arguments as? [String: Any] ?? [:]
    let segments = (params["segments"] as? [String]) ?? []
    control = UISegmentedControl(items: segments)

    super.init(
      registrar: registrar, viewId: viewId, viewType: "liquid_segmented_control", rootView: control)

    apply(params)

    let action = UIAction { [weak self] _ in
      guard let self else { return }
      self.channel.invokeMethod("onSelected", arguments: self.control.selectedSegmentIndex)
    }
    control.addAction(action, for: .valueChanged)
  }

  override func update(with params: [String: Any]) {
    apply(params)
  }

  private func apply(_ params: [String: Any]) {
    applyStyle(from: params)
    applySegments(from: params)
    applySelectedIndex(from: params)
    applyEnabled(from: params)
    applyLabel(from: params)
    applyColors(from: params)
  }

  private func applyStyle(from params: [String: Any]) {
    guard let isDark = boolValue(from: params, key: "isDark"), isDark != appliedIsDark else {
      return
    }
    appliedIsDark = isDark
    control.overrideUserInterfaceStyle = isDark ? .dark : .light
  }

  private func applySegments(from params: [String: Any]) {
    guard let segments = params["segments"] as? [String] else { return }
    let current = (0..<control.numberOfSegments).map { control.titleForSegment(at: $0) ?? "" }
    guard current != segments else { return }

    // removeAllSegments resets selection to -1; carry it across the rebuild so a
    // segment relabel without a selectedIndex param can't blank the selection.
    let previousSelection = control.selectedSegmentIndex
    control.removeAllSegments()
    for (index, title) in segments.enumerated() {
      control.insertSegment(withTitle: title, at: index, animated: false)
    }
    if previousSelection >= 0, previousSelection < control.numberOfSegments {
      control.selectedSegmentIndex = previousSelection
    }
    // Fresh segments carry none of the old title attributes; drop the color
    // caches so applyColors re-stamps them onto the new segments.
    appliedTint = nil
    appliedLabelColor = nil
    appliedSelectedLabelColor = nil
  }

  private func applySelectedIndex(from params: [String: Any]) {
    guard let index = params["selectedIndex"] as? Int,
      index >= 0, index < control.numberOfSegments,
      control.selectedSegmentIndex != index
    else { return }
    control.selectedSegmentIndex = index
  }

  private func applyEnabled(from params: [String: Any]) {
    let enabled = params["enabled"] as? Bool ?? true
    guard enabled != appliedEnabled else { return }
    appliedEnabled = enabled
    control.isEnabled = enabled
  }

  private func applyLabel(from params: [String: Any]) {
    let label = params["semanticLabel"] as? String
    guard label != appliedLabel else { return }
    appliedLabel = label
    control.accessibilityLabel = label
  }

  private func applyColors(from params: [String: Any]) {
    if let tint = UIColor(flutterARGBValue: params["selectedTintColor"]),
      !tint.isEqual(appliedTint)
    {
      appliedTint = tint
      control.selectedSegmentTintColor = tint
    }
    if let label = UIColor(flutterARGBValue: params["labelColor"]),
      !label.isEqual(appliedLabelColor)
    {
      appliedLabelColor = label
      control.setTitleTextAttributes([.foregroundColor: label], for: .normal)
    }
    if let selected = UIColor(flutterARGBValue: params["selectedLabelColor"]),
      !selected.isEqual(appliedSelectedLabelColor)
    {
      appliedSelectedLabelColor = selected
      control.setTitleTextAttributes([.foregroundColor: selected], for: .selected)
    }
  }
}
