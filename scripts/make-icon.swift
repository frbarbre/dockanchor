import AppKit

let size: CGFloat = 1024
let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon-1024.png"

let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
    guard let ctx = NSGraphicsContext.current?.cgContext else { return false }

    // macOS icon grid: 824pt body centred in the 1024 canvas.
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let squircle = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor.black.withAlphaComponent(0.35).cgColor)
    ctx.addPath(squircle)
    ctx.setFillColor(NSColor.black.cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.clip()
    let background = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
            NSColor(red: 0.16, green: 0.42, blue: 0.98, alpha: 1).cgColor,
            NSColor(red: 0.23, green: 0.16, blue: 0.62, alpha: 1).cgColor,
        ] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(background, start: CGPoint(x: 0, y: body.maxY), end: CGPoint(x: 0, y: body.minY), options: [])

    let dock = CGRect(x: 210, y: 170, width: 604, height: 120)
    let dockPath = CGPath(roundedRect: dock, cornerWidth: 44, cornerHeight: 44, transform: nil)
    ctx.addPath(dockPath)
    ctx.setFillColor(NSColor.white.withAlphaComponent(0.22).cgColor)
    ctx.fillPath()
    ctx.addPath(dockPath)
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.45).cgColor)
    ctx.setLineWidth(4)
    ctx.strokePath()

    let tile: CGFloat = 76
    let colors: [NSColor] = [.systemTeal, .systemYellow, .white, .systemPink, .systemGreen]
    let spacing = (dock.width - CGFloat(colors.count) * tile) / CGFloat(colors.count + 1)
    for (i, color) in colors.enumerated() {
        let rect = CGRect(x: dock.minX + spacing + CGFloat(i) * (tile + spacing), y: dock.midY - tile / 2, width: tile, height: tile)
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 18, cornerHeight: 18, transform: nil))
        ctx.setFillColor((i == 2 ? NSColor.white : color.withAlphaComponent(0.9)).cgColor)
        ctx.fillPath()
    }
    ctx.restoreGState()

    let anchor = CGMutablePath()
    let cx: CGFloat = 512
    anchor.addEllipse(in: CGRect(x: cx - 52, y: 742, width: 104, height: 104))
    anchor.move(to: CGPoint(x: cx, y: 742))
    anchor.addLine(to: CGPoint(x: cx, y: 360))
    anchor.move(to: CGPoint(x: cx - 120, y: 668))
    anchor.addLine(to: CGPoint(x: cx + 120, y: 668))
    anchor.move(to: CGPoint(x: cx + 170 * cos(.pi * 1.08), y: 520 + 170 * sin(.pi * 1.08)))
    anchor.addArc(center: CGPoint(x: cx, y: 520), radius: 170, startAngle: .pi * 1.08, endAngle: .pi * 1.92, clockwise: false)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 14, color: NSColor.black.withAlphaComponent(0.25).cgColor)
    ctx.addPath(anchor)
    ctx.setStrokeColor(NSColor.white.cgColor)
    ctx.setLineWidth(46)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.strokePath()

    // Barbs at both arm tips, pointing up and outward.
    for side: CGFloat in [-1, 1] {
        let angle = side < 0 ? CGFloat.pi * 1.08 : CGFloat.pi * 1.92
        let tip = CGPoint(x: cx + 170 * cos(angle), y: 520 + 170 * sin(angle))
        let barb = CGMutablePath()
        barb.move(to: CGPoint(x: tip.x + side * 44, y: tip.y + 62))
        barb.addLine(to: CGPoint(x: tip.x - side * 40, y: tip.y + 30))
        barb.addLine(to: CGPoint(x: tip.x + side * 14, y: tip.y - 36))
        barb.closeSubpath()
        ctx.addPath(barb)
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fillPath()
    }
    ctx.restoreGState()
    return true
}

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else { fatalError("could not render icon") }
try png.write(to: URL(fileURLWithPath: output))
