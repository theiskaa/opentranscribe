import Flutter
import UIKit

public class LiquidPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let toggleFactory = LiquidViewFactory(registrar: registrar, viewType: "liquid_toggle") {
      _, viewId, args in
      LiquidToggleView(registrar: registrar, viewId: viewId, arguments: args)
    }
    registrar.register(toggleFactory, withId: "liquid_toggle")

    let popupButtonFactory = LiquidViewFactory(
      registrar: registrar, viewType: "liquid_popup_button"
    ) { _, viewId, args in
      LiquidPopupMenuView(
        registrar: registrar, viewId: viewId, viewType: "liquid_popup_button", arguments: args)
    }
    registrar.register(popupButtonFactory, withId: "liquid_popup_button")

    // Back-compat for the initial API.
    let popupMenuFactory = LiquidViewFactory(registrar: registrar, viewType: "liquid_popup_menu") {
      _, viewId, args in
      LiquidPopupMenuView(
        registrar: registrar, viewId: viewId, viewType: "liquid_popup_menu", arguments: args)
    }
    registrar.register(popupMenuFactory, withId: "liquid_popup_menu")

    let iconButtonFactory = LiquidViewFactory(registrar: registrar, viewType: "liquid_icon_button")
    {
      _, viewId, args in
      LiquidIconButtonView(registrar: registrar, viewId: viewId, arguments: args)
    }
    registrar.register(iconButtonFactory, withId: "liquid_icon_button")

    let segmentedControlFactory = LiquidViewFactory(
      registrar: registrar, viewType: "liquid_segmented_control"
    ) { _, viewId, args in
      LiquidSegmentedControlView(registrar: registrar, viewId: viewId, arguments: args)
    }
    registrar.register(segmentedControlFactory, withId: "liquid_segmented_control")

    let edgeFadeFactory = LiquidViewFactory(registrar: registrar, viewType: "liquid_edge_fade") {
      _, viewId, args in
      LiquidEdgeFadeView(registrar: registrar, viewId: viewId, arguments: args)
    }
    registrar.register(edgeFadeFactory, withId: "liquid_edge_fade")
  }
}
