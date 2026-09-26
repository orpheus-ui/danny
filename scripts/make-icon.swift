import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outDir = root.appendingPathComponent("Resources/Assets.xcassets/AppIcon.appiconset")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func renderIcon(side: CGFloat) -> CGImage {
    let ctx = CGContext(
        data: nil, width: Int(side), height: Int(side),
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
    )!

    let s = side
    let rect = CGRect(x: 0, y: 0, width: s, height: s)
    let radius = s * 0.2237
    let shape = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

    ctx.addPath(shape)
    ctx.clip()

    let bg = CGGradient(colorsSpace: nil, colors: [
        CGColor(red: 0.086, green: 0.075, blue: 0.118, alpha: 1),
        CGColor(red: 0.043, green: 0.031, blue: 0.067, alpha: 1),
    ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: s), end: CGPoint(x: s, y: 0), options: [])

    let glowCenter = CGPoint(x: s * 0.5, y: s * 0.62)
    let glow = CGGradient(colorsSpace: nil, colors: [
        CGColor(red: 0.463, green: 0.400, blue: 1, alpha: 0.55),
        CGColor(red: 0.463, green: 0.400, blue: 1, alpha: 0),
    ] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(
        glow, startCenter: glowCenter, startRadius: 0,
        endCenter: glowCenter, endRadius: s * 0.55, options: [],
    )

    let chipSide = s * 0.52
    let chipRect = CGRect(
        x: (s - chipSide) / 2, y: (s - chipSide) / 2 - s * 0.01,
        width: chipSide, height: chipSide,
    )
    let chipRadius = chipSide * 0.28
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: chipRect, cornerWidth: chipRadius, cornerHeight: chipRadius, transform: nil))
    ctx.clip()
    let chip = CGGradient(colorsSpace: nil, colors: [
        CGColor(red: 0.337, green: 0.137, blue: 1, alpha: 1),
        CGColor(red: 0.635, green: 0.584, blue: 1, alpha: 1),
    ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(
        chip,
        start: CGPoint(x: chipRect.minX, y: chipRect.maxY),
        end: CGPoint(x: chipRect.maxX, y: chipRect.minY), options: [],
    )
    ctx.restoreGState()

    let white = CGColor(red: 1, green: 1, blue: 1, alpha: 1)
    let cx = s / 2
    let arrowTop = chipRect.maxY - chipSide * 0.26
    let arrowBottom = chipRect.minY + chipSide * 0.30
    let shaftHalf = chipSide * 0.055

    ctx.setFillColor(white)
    ctx.fill(CGRect(x: cx - shaftHalf, y: arrowBottom, width: shaftHalf * 2, height: arrowTop - arrowBottom))

    let headW = chipSide * 0.24
    let headH = chipSide * 0.17
    let head = CGMutablePath()
    head.move(to: CGPoint(x: cx - headW / 2, y: arrowBottom + headH))
    head.addLine(to: CGPoint(x: cx + headW / 2, y: arrowBottom + headH))
    head.addLine(to: CGPoint(x: cx, y: arrowBottom))
    head.closeSubpath()
    ctx.addPath(head)
    ctx.fillPath()

    let trayY = chipRect.minY + chipSide * 0.16
    let trayHalf = chipSide * 0.21
    let trayLine = CGRect(x: cx - trayHalf, y: trayY, width: trayHalf * 2, height: shaftHalf * 1.6)
    let trayPath = CGPath(
        roundedRect: trayLine,
        cornerWidth: shaftHalf * 0.8,
        cornerHeight: shaftHalf * 0.8,
        transform: nil,
    )
    ctx.addPath(trayPath)
    ctx.fillPath()

    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

let sizes: [(name: String, px: CGFloat)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]

for (name, px) in sizes {
    writePNG(renderIcon(side: px), to: outDir.appendingPathComponent(name))
}

let contents = """
{
  "images" : [
    { "filename" : "icon_16x16.png", "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon_16x16@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon_32x32.png", "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon_32x32@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon_128x128.png", "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_128x128@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256x256.png", "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_256x256@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512x512.png", "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_512x512@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
"""
try contents.write(to: outDir.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
print("App icons written to \(outDir.path)")
