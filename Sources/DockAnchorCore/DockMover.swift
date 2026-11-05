import CoreGraphics
import Foundation

public enum DockMover {
    /// The Dock keeps one window the size of the display it currently lives on.
    public static func currentDockFrame() -> CGRect? {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else { return nil }
        for window in windows where window[kCGWindowOwnerName as String] as? String == "Dock" {
            guard window[kCGWindowLayer as String] as? Int == Int(CGWindowLevelForKey(.dockWindow)),
                  let bounds = window[kCGWindowBounds as String] as? NSDictionary,
                  let rect = CGRect(dictionaryRepresentation: bounds) else { continue }
            return rect
        }
        return nil
    }

    public static func isDock(on frame: CGRect) -> Bool {
        guard let dock = currentDockFrame() else { return false }
        return frame.contains(CGPoint(x: dock.midX, y: dock.midY))
    }

    public static func move(to frame: CGRect, orientation: DockOrientation, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let original = CGEvent(source: nil)?.location
            var moved = isDock(on: frame)
            for _ in 0..<3 where !moved {
                push(into: frame, orientation: orientation)
                for _ in 0..<10 where !moved {
                    usleep(50_000)
                    moved = isDock(on: frame)
                }
            }
            if let original { CGWarpMouseCursorPosition(original) }
            DispatchQueue.main.async { completion(moved) }
        }
    }

    private static func push(into frame: CGRect, orientation: DockOrientation) {
        let source = CGEventSource(stateID: .hidSystemState)
        source?.localEventsSuppressionInterval = 0

        let edge: CGPoint
        let inward: CGVector
        switch orientation {
        case .bottom:
            edge = CGPoint(x: frame.midX, y: frame.maxY - 1)
            inward = CGVector(dx: 0, dy: -1)
        case .left:
            edge = CGPoint(x: frame.minX, y: frame.midY)
            inward = CGVector(dx: 1, dy: 0)
        case .right:
            edge = CGPoint(x: frame.maxX - 1, y: frame.midY)
            inward = CGVector(dx: -1, dy: 0)
        }

        func post(_ point: CGPoint, delta: Int64) {
            guard let event = CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left) else { return }
            event.setIntegerValueField(.mouseEventDeltaX, value: Int64(-inward.dx) * delta)
            event.setIntegerValueField(.mouseEventDeltaY, value: Int64(-inward.dy) * delta)
            event.post(tap: .cghidEventTap)
        }

        // The Dock only reacts to the cursor travelling into the edge, not to it appearing there.
        CGWarpMouseCursorPosition(CGPoint(x: edge.x + inward.dx * 80, y: edge.y + inward.dy * 80))
        for step in stride(from: 80, through: 0, by: -8) {
            post(CGPoint(x: edge.x + inward.dx * CGFloat(step), y: edge.y + inward.dy * CGFloat(step)), delta: 8)
            usleep(10_000)
        }
        for _ in 0..<60 {
            CGWarpMouseCursorPosition(edge)
            post(edge, delta: 4)
            usleep(12_000)
        }
    }
}
