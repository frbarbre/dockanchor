import AppKit
import DockAnchorCore

enum DisplayThumbnail {
    static func image(displays: [Display], highlight: CGDirectDisplayID) -> NSImage {
        let size = NSSize(width: 44, height: 18)
        let union = displays.reduce(CGRect.null) { $0.union($1.frame) }
        guard !union.isNull, union.width > 0, union.height > 0 else { return NSImage(size: size) }

        let scale = min((size.width - 2) / union.width, (size.height - 2) / union.height)
        let offset = CGPoint(
            x: (size.width - union.width * scale) / 2,
            y: (size.height - union.height * scale) / 2
        )

        return NSImage(size: size, flipped: true) { _ in
            for display in displays {
                let rect = CGRect(
                    x: offset.x + (display.frame.minX - union.minX) * scale,
                    y: offset.y + (display.frame.minY - union.minY) * scale,
                    width: display.frame.width * scale,
                    height: display.frame.height * scale
                ).insetBy(dx: 0.75, dy: 0.75)
                let path = NSBezierPath(roundedRect: rect, xRadius: 1.5, yRadius: 1.5)
                if display.id == highlight {
                    NSColor.controlAccentColor.setFill()
                } else {
                    NSColor.labelColor.withAlphaComponent(0.12).setFill()
                }
                path.fill()
                NSColor.labelColor.withAlphaComponent(0.6).setStroke()
                path.lineWidth = 1
                path.stroke()
            }
            return true
        }
    }
}
