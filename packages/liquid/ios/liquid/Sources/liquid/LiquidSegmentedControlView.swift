import Flutter
import UIKit

/// A native UISegmentedControl behind the LiquidSegmentedControl Flutter widget.
/// On iOS 26 it adopts Liquid Glass automatically; below it, it is the plain
/// system segmented control. Selection is driven by `selectedIndex` and only
/// moved on a genuine external change, so a Flutter rebuild never fights a tap.
final class LiquidSegmentedControlView: LiquidNativeView {
  private let control: UISegmentedControl

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
    applyUserInterfaceStyle(from: params)

    if let segments = params["segments"] as? [String] {
      let current = (0..<control.numberOfSegments).map { control.titleForSegment(at: $0) ?? "" }
      if current != segments {
        control.removeAllSegments()
        for (index, title) in segments.enumerated() {
          control.insertSegment(withTitle: title, at: index, animated: false)
        }
      }
    }

    if let index = params["selectedIndex"] as? Int,
      index >= 0, index < control.numberOfSegments,
      control.selectedSegmentIndex != index
    {
      control.selectedSegmentIndex = index
    }

    control.isEnabled = params["enabled"] as? Bool ?? true
    control.accessibilityLabel = params["semanticLabel"] as? String

    if let tint = UIColor(flutterARGBValue: params["selectedTintColor"]) {
      control.selectedSegmentTintColor = tint
    }
    if let label = UIColor(flutterARGBValue: params["labelColor"]) {
      control.setTitleTextAttributes([.foregroundColor: label], for: .normal)
    }
    if let selected = UIColor(flutterARGBValue: params["selectedLabelColor"]) {
      control.setTitleTextAttributes([.foregroundColor: selected], for: .selected)
    }
  }
}
