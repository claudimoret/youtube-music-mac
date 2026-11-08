// Renders the Tubemac app icon into an .iconset folder: swift make-icon.swift <out.iconset>
import AppKit

let out = CommandLine.arguments[1]
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

/// Beamed double eighth note in unit coordinates (0…1, y up): the separate pieces (for filling)
/// and their merged outline (for the round-joined stroke that softens the corners).
func notePaths() -> (pieces: [CGPath], outline: CGPath) {
    let a: CGFloat = 0.118, b: CGFloat = 0.086, tilt: CGFloat = 22 * .pi / 180  // note head ellipse
    let stemWidth: CGFloat = 0.052
    let beamThickness: CGFloat = 0.115
    let heads = [CGPoint(x: 0.335, y: 0.265), CGPoint(x: 0.665, y: 0.325)]
    let beamTop = [0.815, 0.875] as [CGFloat]

    // Rightmost point of the tilted ellipse: the stem's right edge touches it tangentially.
    let reach = (a * a * cos(tilt) * cos(tilt) + b * b * sin(tilt) * sin(tilt)).squareRoot()
    let rise = (a * a - b * b) * sin(tilt) * cos(tilt) / reach

    var pieces: [CGPath] = []
    var stemRights: [CGFloat] = []
    for (i, c) in heads.enumerated() {
        var t = CGAffineTransform(translationX: c.x, y: c.y).rotated(by: tilt)
        let head = CGPath(ellipseIn: CGRect(x: -a, y: -b, width: 2 * a, height: 2 * b), transform: &t)
        let right = c.x + reach
        stemRights.append(right)
        let stem = CGPath(rect: CGRect(x: right - stemWidth, y: c.y + rise, width: stemWidth,
                                       height: beamTop[i] - (c.y + rise) - 0.01), transform: nil)
        pieces += [head, stem]
    }
    let beam = CGMutablePath()
    let left = stemRights[0] - stemWidth, right = stemRights[1]
    beam.move(to: CGPoint(x: left, y: beamTop[0]))
    beam.addLine(to: CGPoint(x: right, y: beamTop[1]))
    beam.addLine(to: CGPoint(x: right, y: beamTop[1] - beamThickness))
    beam.addLine(to: CGPoint(x: left, y: beamTop[0] - beamThickness))
    beam.closeSubpath()
    pieces.append(beam)
    let outline = pieces.dropFirst().reduce(pieces[0]) { $0.union($1) }
    return (pieces, outline)
}

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    let s = CGFloat(px)

    // Squircle body on the macOS icon grid (824/1024) with a soft drop shadow
    let inset = s * 100 / 1024
    let body = CGRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let bodyPath = CGPath(roundedRect: body, cornerWidth: body.width * 0.225, cornerHeight: body.width * 0.225, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.010), blur: s * 0.022, color: rgb(0, 0, 0, 0.3))
    ctx.setFillColor(rgb(200, 0, 40))
    ctx.addPath(bodyPath)
    ctx.fillPath()
    ctx.restoreGState()

    // Warm diagonal gradient: coral top-left → deep crimson bottom-right
    ctx.saveGState()
    ctx.addPath(bodyPath)
    ctx.clip()
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                              colors: [rgb(255, 92, 92), rgb(232, 20, 60), rgb(150, 0, 60)] as CFArray,
                              locations: [0, 0.5, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: body.minX, y: body.maxY),
                           end: CGPoint(x: body.maxX, y: body.minY), options: [])
    ctx.restoreGState()

    // The note: one merged outline, corners softened by a round-joined stroke, gentle shadow
    var toBody = CGAffineTransform(translationX: body.minX, y: body.minY).scaledBy(x: body.width, y: body.height)
    let note = notePaths()
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.012), blur: s * 0.03, color: rgb(90, 0, 25, 0.45))
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)  // one shadow for the whole note
    ctx.setFillColor(rgb(255, 255, 255))
    for piece in note.pieces {
        ctx.addPath(piece.copy(using: &toBody)!)
        ctx.fillPath()
    }
    ctx.setStrokeColor(rgb(255, 255, 255))
    ctx.setLineJoin(.round)
    ctx.setLineWidth(body.width * 0.03)
    ctx.addPath(note.outline.copy(using: &toBody)!)
    ctx.strokePath()
    ctx.endTransparencyLayer()
    ctx.restoreGState()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for size in [16, 32, 128, 256, 512] {
    try! render(size).write(to: URL(fileURLWithPath: "\(out)/icon_\(size)x\(size).png"))
    try! render(size * 2).write(to: URL(fileURLWithPath: "\(out)/icon_\(size)x\(size)@2x.png"))
}
