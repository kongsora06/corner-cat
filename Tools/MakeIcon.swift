#!/usr/bin/env swift
import AppKit

// Original vector/pixel artwork, generated without external assets.
// Usage: swift Tools/MakeIcon.swift [destination.icns] [scratch-directory]
let scriptDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let projectDirectory = scriptDirectory.deletingLastPathComponent()
let outputURL = CommandLine.arguments.count > 1
    ? URL(fileURLWithPath: CommandLine.arguments[1])
    : projectDirectory.appendingPathComponent("Assets/AppIcon.icns")
let scratchURL = CommandLine.arguments.count > 2
    ? URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
    : FileManager.default.temporaryDirectory.appendingPathComponent("CornerCatIcon", isDirectory: true)
let iconsetURL = scratchURL.appendingPathComponent("CornerCat.iconset", isDirectory: true)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}
let ink = color(78, 62, 51)
let ginger = color(222, 145, 84)
let lightGinger = color(252, 190, 115)
let cream = color(255, 231, 184)
let blush = color(226, 145, 126)
let green = color(92, 125, 88)

func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ fill: NSColor) {
    fill.setFill()
    NSBezierPath(rect: NSRect(x: x, y: y, width: w, height: h)).fill()
}
func rounded(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ radius: CGFloat, _ fill: NSColor) {
    fill.setFill()
    NSBezierPath(roundedRect: NSRect(x: x, y: y, width: w, height: h), xRadius: radius, yRadius: radius).fill()
}
func poly(_ points: [(CGFloat, CGFloat)], _ fill: NSColor) {
    let p = NSBezierPath()
    p.move(to: NSPoint(x: points[0].0, y: points[0].1))
    for (x, y) in points.dropFirst() { p.line(to: NSPoint(x: x, y: y)) }
    p.close()
    fill.setFill()
    p.fill()
}
func oval(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ fill: NSColor) {
    fill.setFill()
    NSBezierPath(ovalIn: NSRect(x: x, y: y, width: w, height: h)).fill()
}

func drawIcon(size: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                             bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                             isPlanar: false, colorSpaceName: .deviceRGB,
                             bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.clear(CGRect(x: 0, y: 0, width: size, height: size))
    // A top-left coordinate system keeps the source pixel motif easy to read.
    context.cgContext.translateBy(x: 0, y: CGFloat(size))
    context.cgContext.scaleBy(x: CGFloat(size) / 1024, y: -CGFloat(size) / 1024)
    context.cgContext.setShouldAntialias(true)
    // Native icon safe area, a soft lower edge and a luminous sage tile.
    rounded(80, 95, 864, 846, 188, color(52, 71, 47, 0.13))
    let tile = NSBezierPath(roundedRect: NSRect(x: 80, y: 80, width: 864, height: 864), xRadius: 190, yRadius: 190)
    let gradient = NSGradient(starting: color(213, 224, 193), ending: color(153, 177, 142))!
    gradient.draw(in: tile, angle: 90)
    color(255, 255, 230, 0.38).setStroke()
    tile.lineWidth = 6
    tile.stroke()
    // The warm window inset also gives the dark outline breathing room.
    rounded(186, 190, 652, 636, 113, color(106, 130, 92, 0.25))
    rounded(186, 178, 652, 636, 113, color(246, 242, 216))
    rounded(212, 204, 600, 582, 88, color(228, 227, 196))
    rounded(229, 222, 566, 546, 73, color(247, 220, 178))
    // Peach dusk and a tiny sun are visible over the cat's ears.
    let glass = NSBezierPath(roundedRect: NSRect(x: 229, y: 222, width: 566, height: 546), xRadius: 73, yRadius: 73)
    NSGraphicsContext.saveGraphicsState()
    glass.addClip()
    rect(229, 510, 566, 258, color(217, 215, 172))
    rect(488, 220, 28, 548, color(234, 235, 203))
    rect(229, 468, 566, 26, color(234, 235, 203))
    oval(660, 268, 65, 65, color(255, 244, 199))
    rect(276, 290, 112, 16, color(255, 248, 221, 0.45))
    rect(253, 306, 152, 16, color(255, 248, 221, 0.45))
    NSGraphicsContext.restoreGraphicsState()
    // Small leaves tuck behind the cat, so the icon remains legible at 16 px.
    poly([(191, 691), (191, 632), (216, 632), (216, 658), (242, 658), (242, 689), (262, 689), (262, 750), (238, 750), (238, 721), (213, 721), (213, 691)], green)
    poly([(236, 748), (236, 681), (260, 681), (260, 655), (287, 655), (287, 628), (310, 628), (310, 692), (286, 692), (286, 719), (260, 719), (260, 748)], color(132, 158, 106))
    // Ground shadow and the paws anchor the face within its window.
    oval(276, 766, 468, 55, color(86, 98, 66, 0.20))
    // Draw the original sprite on a 10-point source grid. Pixel boundaries are
    // integral, while antialiasing keeps the outer rounded tile smooth.
    NSGraphicsContext.saveGraphicsState()
    context.cgContext.translateBy(x: 112, y: 131)
    context.cgContext.scaleBy(x: 10, y: 10)
    context.cgContext.setShouldAntialias(false)
    // Body and fluffy bib.
    poly([(27, 48), (54, 48), (54, 52), (58, 52), (58, 66), (54, 66), (54, 68), (26, 68), (26, 66), (22, 66), (22, 54), (27, 54)], ink)
    poly([(28, 50), (52, 50), (52, 54), (56, 54), (56, 64), (52, 64), (52, 66), (28, 66), (28, 64), (24, 64), (24, 56), (28, 56)], lightGinger)
    rect(31, 53, 19, 13, cream)
    rect(26, 57, 5, 3, ginger)
    rect(50, 57, 6, 3, ginger)
    rect(34, 63, 2, 4, ink)
    rect(45, 63, 2, 4, ink)
    // Tall ears and stepped cheeks are unmistakable even when reduced.
    poly([(16, 19), (20, 19), (20, 21), (24, 21), (24, 25), (28, 25), (28, 28), (48, 28), (48, 25), (52, 25), (52, 21), (56, 21), (56, 19), (60, 19), (60, 40), (64, 40), (64, 52), (60, 52), (60, 56), (54, 56), (54, 58), (23, 58), (23, 56), (17, 56), (17, 53), (13, 53), (13, 41), (16, 41)], ink)
    poly([(18, 22), (20, 22), (20, 24), (24, 24), (24, 28), (28, 28), (28, 30), (49, 30), (49, 28), (53, 28), (53, 24), (56, 24), (56, 22), (58, 22), (58, 42), (62, 42), (62, 51), (58, 51), (58, 54), (53, 54), (53, 56), (24, 56), (24, 54), (19, 54), (19, 51), (15, 51), (15, 43), (18, 43)], lightGinger)
    poly([(20, 27), (23, 29), (23, 32), (26, 32), (26, 35), (20, 35)], blush)
    poly([(54, 29), (56, 27), (56, 35), (50, 35), (50, 32), (54, 32)], blush)
    rect(32, 31, 3, 8, ginger)
    rect(39, 30, 3, 7, ginger)
    rect(46, 31, 3, 8, ginger)
    rect(15, 44, 8, 3, ginger)
    rect(55, 44, 7, 3, ginger)
    rect(16, 49, 7, 2, ginger)
    rect(55, 49, 6, 2, ginger)
    poly([(27, 47), (34, 47), (34, 45), (45, 45), (45, 47), (52, 47), (52, 53), (48, 53), (48, 56), (29, 56), (29, 54), (24, 54), (24, 50), (27, 50)], cream)
    rect(27, 40, 5, 7, ink)
    rect(47, 40, 5, 7, ink)
    rect(27, 40, 1, 2, cream)
    rect(47, 40, 1, 2, cream)
    rect(37, 48, 5, 2, blush)
    rect(39, 50, 2, 3, ink)
    rect(35, 53, 4, 1, ink)
    rect(41, 53, 4, 1, ink)
    rect(23, 48, 4, 2, blush)
    rect(52, 48, 4, 2, blush)
    rect(8, 49, 10, 1, ink)
    rect(10, 53, 8, 1, ink)
    rect(59, 49, 11, 1, ink)
    rect(59, 53, 9, 1, ink)
    NSGraphicsContext.restoreGraphicsState()
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let files: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024)
]
for (name, size) in files {
    try drawIcon(size: size).write(to: iconsetURL.appendingPathComponent(name))
}
try drawIcon(size: 1024).write(to: scratchURL.appendingPathComponent("AppIcon-preview.png"))
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconsetURL.path, "-o", outputURL.path]
try task.run()
task.waitUntilExit()
guard task.terminationStatus == 0 else {
    fputs("iconutil failed\n", stderr)
    exit(task.terminationStatus)
}
print("Generated \(outputURL.path)")
print("Preview: \(scratchURL.appendingPathComponent("AppIcon-preview.png").path)")
