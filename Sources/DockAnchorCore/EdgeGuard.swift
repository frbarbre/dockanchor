import CoreGraphics
import Foundation

public enum DockOrientation: String {
    case bottom, left, right

    public static func current() -> DockOrientation {
        let domain = "com.apple.dock" as CFString
        CFPreferencesAppSynchronize(domain)
        let value = CFPreferencesCopyAppValue("orientation" as CFString, domain) as? String
        return value.flatMap(DockOrientation.init(rawValue:)) ?? .bottom
    }
}

/// The Dock follows the cursor to whichever display's Dock edge it is pushed against.
public enum EdgeGuard {
    public static let inset: CGFloat = 2

    public static func clamp(
        _ point: CGPoint,
        displays: [CGRect],
        allowed: CGRect,
        orientation: DockOrientation
    ) -> CGPoint? {
        guard let d = displays.first(where: { $0.contains(point) }), d != allowed else { return nil }
        let isOuterEdge: (CGPoint) -> Bool = { probe in !displays.contains { $0.contains(probe) } }

        switch orientation {
        case .bottom:
            let limit = d.maxY - inset
            guard point.y > limit, isOuterEdge(CGPoint(x: point.x, y: d.maxY + 0.5)) else { return nil }
            return CGPoint(x: point.x, y: limit)
        case .left:
            let limit = d.minX + inset
            guard point.x < limit, isOuterEdge(CGPoint(x: d.minX - 0.5, y: point.y)) else { return nil }
            return CGPoint(x: limit, y: point.y)
        case .right:
            let limit = d.maxX - inset
            guard point.x > limit, isOuterEdge(CGPoint(x: d.maxX + 0.5, y: point.y)) else { return nil }
            return CGPoint(x: limit, y: point.y)
        }
    }
}
