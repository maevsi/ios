// Renders the App Store "header and search results" Universal asset, as docs/header-artwork.md specifies.
//
// usage: swift render.swift <app_logo.svg> <raleway.woff2> <out.png> [--safe-area | --template]
//   --safe-area  also outlines the art safe area in red, to check a render
//   --template   draws only the background and the outlined safe area, as a starting point for designers
import AppKit
import CoreText

let args = CommandLine.arguments
guard args.count >= 4 else {
    print("usage: swift render.swift <app_logo.svg> <raleway.woff2> <out.png> [--safe-area | --template]")
    exit(1)
}
let logoURL = URL(fileURLWithPath: args[1])
let fontURL = URL(fileURLWithPath: args[2])
let outURL = URL(fileURLWithPath: args[3])
let mode = args.count > 4 ? args[4] : ""
let outlineSafeArea = mode == "--safe-area" || mode == "--template"
let drawContent = mode != "--template"

// Canvas and art safe area from Apple's creative assets specification, with a top-left origin.
let W = 5244, H = 2950
let safe = CGRect(x: 1921, y: 660, width: 1402, height: 962)

let tagline = ["BROWSE THE VIBE.", "FIND YOUR TYPE."]
let ink: UInt32 = 0x1D1D1B // the logo's wordmark colour

let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
func color(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255, alpha: a)
}

let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0, space: sRGB, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
// Flip to a top-left origin so coordinates match Apple's template.
ctx.translateBy(x: 0, y: CGFloat(H))
ctx.scaleBy(x: 1, y: -1)

// Background: white with soft glows in the logo colours, centred outside the safe area.
ctx.setFillColor(color(0xFFFFFF))
ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
func glow(_ c: UInt32, _ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ a: CGFloat) {
    let g = CGGradient(colorsSpace: sRGB, colors: [color(c, a), color(c, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(g, startCenter: CGPoint(x: x, y: y), startRadius: 0, endCenter: CGPoint(x: x, y: y), endRadius: r, options: [])
}
glow(0x0467F1, 900, 500, 1900, 0.22)
glow(0xFF3167, 4500, 450, 1700, 0.20)
glow(0x70E884, 1100, 2700, 1800, 0.24)
glow(0xFFE504, 4400, 2650, 1700, 0.26)

if drawContent {
    // Rasterise the logo and crop it to its visible pixels, since the SVG has padding.
    guard let logo = NSImage(contentsOf: logoURL) else { fatalError("cannot load \(logoURL.path)") }
    let lw = 6000, lh = 1500
    let lctx = CGContext(data: nil, width: lw, height: lh, bitsPerComponent: 8, bytesPerRow: 0, space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    NSGraphicsContext.current = NSGraphicsContext(cgContext: lctx, flipped: false)
    logo.draw(in: NSRect(x: 0, y: 0, width: lw, height: lh))
    let lbuf = lctx.data!.assumingMemoryBound(to: UInt8.self)
    var minX = lw, minY = lh, maxX = 0, maxY = 0
    for y in 0..<lh {
        for x in 0..<lw where lbuf[y * lctx.bytesPerRow + x * 4 + 3] > 8 {
            minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
        }
    }
    let logoImage = lctx.makeImage()!.cropping(to: CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1))!

    // Raleway is a variable font; the tagline uses weight 800 (ExtraBold).
    let fontData = try! Data(contentsOf: fontURL) as CFData
    let descriptors = CTFontManagerCreateFontDescriptorsFromData(fontData) as! [CTFontDescriptor]
    func raleway(_ size: CGFloat) -> CTFont {
        let d = CTFontDescriptorCreateCopyWithAttributes(descriptors[0], [kCTFontVariationAttribute: [0x77676874: 800]] as CFDictionary)
        return CTFontCreateWithFontDescriptor(d, size, nil)
    }
    func line(_ s: String, _ f: CTFont) -> CTLine {
        CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: [.font: f, .kern: CTFontGetSize(f) * 0.04, .foregroundColor: color(ink)]))
    }

    // The logo spans the safe area minus a margin; the tagline shrinks until its longest line matches the logo's width.
    let margin: CGFloat = 60
    let logoW = safe.width - 2 * margin
    let logoH = logoW * CGFloat(logoImage.height) / CGFloat(logoImage.width)
    var size: CGFloat = 200
    while tagline.map({ CTLineGetTypographicBounds(line($0, raleway(size)), nil, nil, nil) }).max()! > logoW { size -= 2 }
    let font = raleway(size)
    let lineGap = size * 1.15
    let gap: CGFloat = 110
    var top = safe.midY - (logoH + gap + lineGap * CGFloat(tagline.count - 1) + CTFontGetCapHeight(font)) / 2

    ctx.saveGState()
    ctx.translateBy(x: safe.midX - logoW / 2, y: top + logoH)
    ctx.scaleBy(x: 1, y: -1)
    ctx.interpolationQuality = .high
    ctx.draw(logoImage, in: CGRect(x: 0, y: 0, width: logoW, height: logoH))
    ctx.restoreGState()
    top += logoH + gap

    for (i, s) in tagline.enumerated() {
        let l = line(s, font)
        let w = CTLineGetTypographicBounds(l, nil, nil, nil)
        ctx.saveGState()
        ctx.translateBy(x: safe.midX - w / 2, y: top + CTFontGetCapHeight(font) + lineGap * CGFloat(i))
        ctx.scaleBy(x: 1, y: -1)
        ctx.textPosition = .zero
        CTLineDraw(l, ctx)
        ctx.restoreGState()
    }
}

if outlineSafeArea {
    ctx.setStrokeColor(color(0xFF0000))
    ctx.setLineWidth(6)
    ctx.setLineDash(phase: 0, lengths: mode == "--template" ? [30, 20] : [])
    ctx.stroke(safe)
}

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: outURL)
print("wrote \(outURL.path) (\(W) × \(H))")
