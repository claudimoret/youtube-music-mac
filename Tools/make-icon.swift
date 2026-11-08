// Renders the YTM Desktop app icon into an .iconset folder: swift make-icon.swift <out.iconset>
import AppKit

let out = CommandLine.arguments[1]
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor {
    NSColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: 1)
}

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)

    // Squircle body on the macOS icon grid (824/1024) with a soft drop shadow
    let inset = s * 100 / 1024
    let body = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let bodyPath = NSBezierPath(roundedRect: body, xRadius: body.width * 0.225, yRadius: body.width * 0.225)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
    shadow.shadowBlurRadius = s * 0.022
    shadow.shadowOffset = NSSize(width: 0, height: -s * 0.010)
    shadow.set()
    rgb(200, 0, 40).setFill()
    bodyPath.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Warm diagonal gradient: coral top-left → deep crimson bottom-right
    NSGradient(colors: [rgb(255, 92, 92), rgb(232, 20, 60), rgb(150, 0, 60)],
               atLocations: [0, 0.5, 1], colorSpace: .sRGB)!.draw(in: bodyPath, angle: -50)

    // Subtle sound-wave arcs behind the note
    func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: body.minX + x * body.width, y: body.minY + y * body.height) }
    let w = body.width
    NSColor.white.withAlphaComponent(0.16).setStroke()
    for (i, r) in [0.40, 0.52, 0.64].enumerated() {
        let arc = NSBezierPath()
        arc.appendArc(withCenter: p(0.30, 0.30), radius: w * r, startAngle: 5, endAngle: 85)
        arc.lineWidth = w * (0.035 - CGFloat(i) * 0.006)
        arc.lineCapStyle = .round
        arc.stroke()
    }

    // Double eighth note (beamed), drawn by hand
    NSColor.white.setFill()
    func head(_ cx: CGFloat, _ cy: CGFloat) {
        let t = NSAffineTransform()
        t.translateX(by: p(cx, cy).x, yBy: p(cx, cy).y)
        t.rotate(byDegrees: 24)
        let e = NSBezierPath(ovalIn: NSRect(x: -w * 0.105, y: -w * 0.075, width: w * 0.21, height: w * 0.15))
        e.transform(using: t as AffineTransform)
        e.fill()
    }
    head(0.34, 0.27)
    head(0.66, 0.33)
    let stem = w * 0.045
    NSBezierPath(rect: NSRect(x: p(0.34, 0).x + w * 0.105 - stem * 0.7, y: p(0, 0.28).y, width: stem, height: w * 0.43)).fill()
    NSBezierPath(rect: NSRect(x: p(0.66, 0).x + w * 0.105 - stem * 0.7, y: p(0, 0.34).y, width: stem, height: w * 0.43)).fill()
    let beam = NSBezierPath()
    let x1 = p(0.34, 0).x + w * 0.105 - stem * 0.7, x2 = p(0.66, 0).x + w * 0.105 + stem * 0.3
    beam.move(to: NSPoint(x: x1, y: p(0, 0.71).y))
    beam.line(to: NSPoint(x: x2, y: p(0, 0.77).y))
    beam.line(to: NSPoint(x: x2, y: p(0, 0.77).y - w * 0.11))
    beam.line(to: NSPoint(x: x1, y: p(0, 0.71).y - w * 0.11))
    beam.close()
    beam.fill()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for size in [16, 32, 128, 256, 512] {
    try! render(size).write(to: URL(fileURLWithPath: "\(out)/icon_\(size)x\(size).png"))
    try! render(size * 2).write(to: URL(fileURLWithPath: "\(out)/icon_\(size)x\(size)@2x.png"))
}
