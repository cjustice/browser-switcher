#!/usr/bin/env swift
// Generates Sources/BrowserSwitcher/Resources/AppIcon.icns from scratch.
// Re-run any time you want to tweak the design.
import AppKit
import CoreGraphics

let outputPath = "Sources/BrowserSwitcher/Resources/AppIcon.icns"
let workDir = "/tmp/BrowserSwitcher.iconset"

func render(size canvas: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(canvas), pixelsHigh: Int(canvas),
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 32
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // Rounded rect background with macOS-Big-Sur-style corner radius (~22.4%).
    let radius = canvas * 0.224
    let rect = NSRect(x: 0, y: 0, width: canvas, height: canvas)
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    NSGraphicsContext.current?.cgContext.saveGState()
    path.addClip()

    // Diagonal gradient — blue → purple.
    let gradient = NSGradient(colors: [
        NSColor(red: 0.28, green: 0.55, blue: 0.95, alpha: 1.0),
        NSColor(red: 0.55, green: 0.30, blue: 0.85, alpha: 1.0),
    ])!
    gradient.draw(in: rect, angle: -45)

    // SF Symbol, white, ~50% of canvas, heavy weight, centered.
    let pointSize = canvas * 0.50
    let weight = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .heavy)
    let palette = NSImage.SymbolConfiguration(paletteColors: [.white])
    let cfg = weight.applying(palette)
    if let symbol = NSImage(systemSymbolName: "arrow.left.arrow.right", accessibilityDescription: nil)?
        .withSymbolConfiguration(cfg) {
        let sSize = symbol.size
        let sRect = NSRect(
            x: (canvas - sSize.width) / 2,
            y: (canvas - sSize.height) / 2,
            width: sSize.width,
            height: sSize.height
        )
        symbol.draw(in: sRect)
    }

    NSGraphicsContext.current?.cgContext.restoreGState()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func writePNG(rep: NSBitmapImageRep, to path: String) throws {
    let data = rep.representation(using: .png, properties: [:])!
    try data.write(to: URL(fileURLWithPath: path))
}

// Clean workdir.
try? FileManager.default.removeItem(atPath: workDir)
try FileManager.default.createDirectory(atPath: workDir, withIntermediateDirectories: true)

let sizes: [(CGFloat, String)] = [
    (16,   "icon_16x16.png"),
    (32,   "icon_16x16@2x.png"),
    (32,   "icon_32x32.png"),
    (64,   "icon_32x32@2x.png"),
    (128,  "icon_128x128.png"),
    (256,  "icon_128x128@2x.png"),
    (256,  "icon_256x256.png"),
    (512,  "icon_256x256@2x.png"),
    (512,  "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

for (size, name) in sizes {
    let rep = render(size: size)
    try writePNG(rep: rep, to: "\(workDir)/\(name)")
}

// Pack via iconutil.
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", workDir, "-o", outputPath]
try task.run()
task.waitUntilExit()

if task.terminationStatus != 0 {
    FileHandle.standardError.write("iconutil failed (\(task.terminationStatus))\n".data(using: .utf8)!)
    exit(1)
}

print("wrote \(outputPath)")
