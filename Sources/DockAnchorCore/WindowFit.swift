import AppKit
import CoreGraphics

public struct ScreenArea: Equatable {
    public let frame: CGRect
    public let visible: CGRect

    public init(frame: CGRect, visible: CGRect) {
        self.frame = frame
        self.visible = visible
    }

    /// The area below the menu bar, ignoring the Dock.
    public var withoutDock: CGRect {
        CGRect(x: frame.minX, y: visible.minY, width: frame.width, height: frame.maxY - visible.minY)
    }

    public func dockThickness(_ orientation: DockOrientation) -> CGFloat {
        switch orientation {
        case .bottom: return frame.maxY - visible.maxY
        case .left: return visible.minX - frame.minX
        case .right: return frame.maxX - visible.maxX
        }
    }

    public func withDock(thickness: CGFloat, orientation: DockOrientation) -> CGRect {
        let base = withoutDock
        switch orientation {
        case .bottom: return CGRect(x: base.minX, y: base.minY, width: base.width, height: base.height - thickness)
        case .left: return CGRect(x: base.minX + thickness, y: base.minY, width: base.width - thickness, height: base.height)
        case .right: return CGRect(x: base.minX, y: base.minY, width: base.width - thickness, height: base.height)
        }
    }
}

public enum WindowFit {
    /// Covers Raycast window gaps and apps that size in character cells (terminals, editors).
    public static let tolerance: CGFloat = 24
    /// macOS sometimes reports a secondary display's visible frame without its menu bar after a reconnect.
    public static let menuBarTolerance: CGFloat = 44

    /// Returns the frame a window that filled one of `references` should get to fill `target`, keeping its gaps.
    public static func retarget(_ window: CGRect, references: [CGRect], target: CGRect) -> CGRect? {
        for reference in references {
            let left = window.minX - reference.minX
            let top = window.minY - reference.minY
            let right = reference.maxX - window.maxX
            let bottom = reference.maxY - window.maxY
            guard [left, right, bottom].allSatisfy({ abs($0) <= tolerance }), abs(top) <= menuBarTolerance else { continue }

            // Window gaps are uniform, so the smallest inset is the gap; anything beyond it is slack from a bad fit.
            let gap = max(0, min(left, right, bottom))
            // The Dock never sits on top, so the window's own top edge is the most trustworthy one.
            let keepsTop = window.minY >= target.minY && window.minY - target.minY <= menuBarTolerance
            let fittedTop = keepsTop ? window.minY : target.minY + gap
            let fitted = CGRect(
                x: target.minX + gap,
                y: fittedTop,
                width: target.width - 2 * gap,
                height: target.maxY - gap - fittedTop
            )
            // macOS rounds some window sizes by a point; refitting those would never settle.
            let unchanged = abs(fitted.minX - window.minX) <= 1 && abs(fitted.minY - window.minY) <= 1
                && abs(fitted.width - window.width) <= 1 && abs(fitted.height - window.height) <= 1
            return unchanged ? nil : fitted
        }
        return nil
    }
}

extension Displays {
    /// Converted to Quartz coordinates so they line up with `Display.frame` and Accessibility window frames.
    public static func screenAreas() -> [CGDirectDisplayID: ScreenArea] {
        guard let primaryHeight = NSScreen.screens.first?.frame.height else { return [:] }
        var areas: [CGDirectDisplayID: ScreenArea] = [:]
        for screen in NSScreen.screens {
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { continue }
            func flip(_ r: CGRect) -> CGRect { CGRect(x: r.minX, y: primaryHeight - r.maxY, width: r.width, height: r.height) }
            areas[number.uint32Value] = ScreenArea(frame: flip(screen.frame), visible: flip(screen.visibleFrame))
        }
        return areas
    }
}
