import UIKit

extension UIColor {
    /// Creates a UIColor from a Flutter `Color.value` int in AARRGGBB format.
    convenience init?(flutterARGBValue: Any?) {
        guard let argb = UIColor._coerceFlutterInt(flutterARGBValue) else { return nil }

        let a = CGFloat((argb >> 24) & 0xFF) / 255.0
        let r = CGFloat((argb >> 16) & 0xFF) / 255.0
        let g = CGFloat((argb >> 8) & 0xFF) / 255.0
        let b = CGFloat(argb & 0xFF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: a)
    }

    private static func _coerceFlutterInt(_ value: Any?) -> Int64? {
        switch value {
        case let v as Int:
            return Int64(v)
        case let v as Int64:
            return v
        case let v as NSNumber:
            return v.int64Value
        default:
            return nil
        }
    }
}
