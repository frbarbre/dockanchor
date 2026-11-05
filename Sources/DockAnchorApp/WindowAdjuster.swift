import AppKit
import ApplicationServices
import DockAnchorCore

enum WindowAdjuster {
    private static let queue = DispatchQueue(label: "io.frbarbre.dockanchor.windows")

    static func fitMaximizedWindows(
        previous: [CGDirectDisplayID: ScreenArea],
        current: [CGDirectDisplayID: ScreenArea],
        dockThickness: CGFloat,
        orientation: DockOrientation
    ) {
        let pids = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && !$0.isHidden && $0.processIdentifier != getpid() }
            .map(\.processIdentifier)

        queue.async {
            for pid in pids {
                let app = AXUIElementCreateApplication(pid)
                // A hung app must not stall the whole pass.
                AXUIElementSetMessagingTimeout(app, 0.25)
                for window in windows(of: app) {
                    guard let frame = frame(of: window),
                          let (id, area) = current.first(where: { $0.value.frame.contains(CGPoint(x: frame.midX, y: frame.midY)) })
                    else { continue }
                    var references = [area.withoutDock, area.frame]
                    if dockThickness > 0 {
                        references.append(area.withDock(thickness: dockThickness, orientation: orientation))
                    }
                    if let old = previous[id] { references.insert(old.visible, at: 0) }
                    if let fitted = WindowFit.retarget(frame, references: references, target: area.visible) {
                        setFrame(fitted, of: window)
                    }
                }
            }
        }
    }

    private static func windows(of app: AXUIElement) -> [AXUIElement] {
        guard let windows = attribute(app, kAXWindowsAttribute) as? [AXUIElement] else { return [] }
        return windows.filter { window in
            attribute(window, kAXSubroleAttribute) as? String == kAXStandardWindowSubrole
                && attribute(window, kAXMinimizedAttribute) as? Bool != true
                && attribute(window, "AXFullScreen") as? Bool != true
        }
    }

    private static func attribute(_ element: AXUIElement, _ name: String) -> AnyObject? {
        var value: AnyObject?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }

    private static func frame(of window: AXUIElement) -> CGRect? {
        var origin = CGPoint.zero
        var size = CGSize.zero
        guard let position = attribute(window, kAXPositionAttribute),
              let dimensions = attribute(window, kAXSizeAttribute),
              AXValueGetValue(position as! AXValue, .cgPoint, &origin),
              AXValueGetValue(dimensions as! AXValue, .cgSize, &size) else { return nil }
        return CGRect(origin: origin, size: size)
    }

    // Size, then position, then size again: apps clamp a size that would not fit at the old position.
    private static func setFrame(_ frame: CGRect, of window: AXUIElement) {
        var origin = frame.origin
        var size = frame.size
        guard let position = AXValueCreate(.cgPoint, &origin), let dimensions = AXValueCreate(.cgSize, &size) else { return }
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, dimensions)
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, position)
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, dimensions)
    }
}
