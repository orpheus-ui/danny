import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let outDir = root.appendingPathComponent("Resources/Assets.xcassets/AppIcon.appiconset")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

/// The character layer (Resources/Icons/app-icon-layer.webp): a sphere with a face and
/// its glow, placed large and low so the icon's edges cut it.
let layerURL = root.appendingPathComponent("Resources/Icons/app-icon-layer.webp")
guard let source = CGImageSourceCreateWithURL(layerURL as CFURL, nil),
      let layer = CGImageSourceCreateImageAtIndex(source, 0, nil)
else { fatalError("Can't read \(layerURL.path)") }

/// Draws on Apple's macOS icon grid, in points of a 1024 canvas: an 824-point rounded
/// square with 100-point margins, so macOS shows it like any native icon.
func renderIcon(side: CGFloat) -> CGImage {
    let ctx = CGContext(
        data: nil, width: Int(side), height: Int(side),
        bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
    )!
    ctx.interpolationQuality = .high
    ctx.scaleBy(x: side / 1024, y: side / 1024)

    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

    // The drop shadow every macOS icon sits on.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: CGColor(gray: 0, alpha: 0.35))
    ctx.addPath(shape)
    ctx.setFillColor(CGColor(gray: 0.12, alpha: 1))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.addPath(shape)
    ctx.clip()
    let background = CGGradient(colorsSpace: nil, colors: [
        CGColor(red: 0.165, green: 0.161, blue: 0.176, alpha: 1),
        CGColor(red: 0.098, green: 0.094, blue: 0.110, alpha: 1),
    ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(background, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])

    // The sphere is 1050 px across in the layer and 947 points here, centred at
    // (452, 336) from the bottom left: the face lands in the middle, the top of the
    // sphere a fifth of the way down, and the left, right and bottom edges cut it.
    let scale: CGFloat = 947 / 1050
    let width = CGFloat(layer.width) * scale, height = CGFloat(layer.height) * scale
    let sphereCentre = CGPoint(x: 730 * scale, y: (CGFloat(layer.height) - 770) * scale)
    ctx.draw(layer, in: CGRect(x: 452 - sphereCentre.x, y: 336 - sphereCentre.y, width: width, height: height))

    // A hairline inner edge, as on Apple's own icons.
    ctx.addPath(shape)
    ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.08))
    ctx.setLineWidth(3)
    ctx.strokePath()

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
