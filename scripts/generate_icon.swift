import AppKit
import Foundation

let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resourcesURL = rootURL.appendingPathComponent("Resources", isDirectory: true)
let iconsetURL = resourcesURL.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let icnsURL = resourcesURL.appendingPathComponent("AppIcon.icns")

let fileManager = FileManager.default
try? fileManager.removeItem(at: iconsetURL)
try? fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

struct IconSpec {
    let points: Int
    let filename: String
}

let specs: [IconSpec] = [
    .init(points: 16, filename: "icon_16x16.png"),
    .init(points: 32, filename: "icon_16x16@2x.png"),
    .init(points: 32, filename: "icon_32x32.png"),
    .init(points: 64, filename: "icon_32x32@2x.png"),
    .init(points: 128, filename: "icon_128x128.png"),
    .init(points: 256, filename: "icon_128x128@2x.png"),
    .init(points: 256, filename: "icon_256x256.png"),
    .init(points: 512, filename: "icon_256x256@2x.png"),
    .init(points: 512, filename: "icon_512x512.png"),
    .init(points: 1024, filename: "icon_512x512@2x.png")
]

func savePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let data = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconGeneration", code: 1)
    }
    try data.write(to: url)
}

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let canvas = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    canvas.fill()

    let inset = size * 0.04
    let outerRect = canvas.insetBy(dx: inset, dy: inset)
    let outerRadius = size * 0.22
    let outerPath = NSBezierPath(roundedRect: outerRect, xRadius: outerRadius, yRadius: outerRadius)

    NSGraphicsContext.current?.cgContext.saveGState()
    NSShadow().set()
    outerPath.addClip()

    let backgroundGradient = NSGradient(
        colors: [
            NSColor(calibratedRed: 0.07, green: 0.14, blue: 0.24, alpha: 1),
            NSColor(calibratedRed: 0.13, green: 0.28, blue: 0.44, alpha: 1),
            NSColor(calibratedRed: 0.23, green: 0.50, blue: 0.68, alpha: 1)
        ]
    )!
    backgroundGradient.draw(in: outerPath, angle: 55)

    let glowRect = NSRect(x: size * 0.12, y: size * 0.54, width: size * 0.76, height: size * 0.28)
    let glowPath = NSBezierPath(ovalIn: glowRect)
    NSColor(calibratedRed: 1, green: 1, blue: 1, alpha: 0.12).setFill()
    glowPath.fill()
    NSGraphicsContext.current?.cgContext.restoreGState()

    let cardRect = NSRect(
        x: size * 0.18,
        y: size * 0.17,
        width: size * 0.64,
        height: size * 0.66
    )
    let cardPath = NSBezierPath(roundedRect: cardRect, xRadius: size * 0.085, yRadius: size * 0.085)

    let shadow = NSShadow()
    shadow.shadowColor = NSColor(calibratedWhite: 0, alpha: 0.24)
    shadow.shadowOffset = NSSize(width: 0, height: -size * 0.02)
    shadow.shadowBlurRadius = size * 0.045
    shadow.set()

    NSColor(calibratedRed: 0.96, green: 0.98, blue: 1.0, alpha: 1).setFill()
    cardPath.fill()

    NSColor(calibratedRed: 0.84, green: 0.90, blue: 0.97, alpha: 1).setStroke()
    cardPath.lineWidth = size * 0.01
    cardPath.stroke()

    let imageInset = size * 0.045
    let imageRect = cardRect.insetBy(dx: imageInset, dy: imageInset)
    let imagePath = NSBezierPath(roundedRect: imageRect, xRadius: size * 0.05, yRadius: size * 0.05)
    imagePath.addClip()

    let skyGradient = NSGradient(
        colors: [
            NSColor(calibratedRed: 0.63, green: 0.86, blue: 0.99, alpha: 1),
            NSColor(calibratedRed: 0.83, green: 0.93, blue: 1.0, alpha: 1)
        ]
    )!
    skyGradient.draw(in: imagePath, angle: 90)

    let sunRect = NSRect(x: imageRect.maxX - size * 0.18, y: imageRect.maxY - size * 0.2, width: size * 0.1, height: size * 0.1)
    NSColor(calibratedRed: 1.0, green: 0.86, blue: 0.37, alpha: 1).setFill()
    NSBezierPath(ovalIn: sunRect).fill()

    let mountainBack = NSBezierPath()
    mountainBack.move(to: NSPoint(x: imageRect.minX - size * 0.04, y: imageRect.minY + size * 0.14))
    mountainBack.line(to: NSPoint(x: imageRect.minX + size * 0.16, y: imageRect.minY + size * 0.34))
    mountainBack.line(to: NSPoint(x: imageRect.minX + size * 0.34, y: imageRect.minY + size * 0.16))
    mountainBack.line(to: NSPoint(x: imageRect.minX + size * 0.52, y: imageRect.minY + size * 0.4))
    mountainBack.line(to: NSPoint(x: imageRect.maxX + size * 0.04, y: imageRect.minY + size * 0.16))
    mountainBack.line(to: NSPoint(x: imageRect.maxX + size * 0.04, y: imageRect.minY - size * 0.04))
    mountainBack.line(to: NSPoint(x: imageRect.minX - size * 0.04, y: imageRect.minY - size * 0.04))
    mountainBack.close()
    NSColor(calibratedRed: 0.31, green: 0.58, blue: 0.63, alpha: 1).setFill()
    mountainBack.fill()

    let mountainFront = NSBezierPath()
    mountainFront.move(to: NSPoint(x: imageRect.minX - size * 0.04, y: imageRect.minY + size * 0.02))
    mountainFront.line(to: NSPoint(x: imageRect.minX + size * 0.22, y: imageRect.minY + size * 0.22))
    mountainFront.line(to: NSPoint(x: imageRect.minX + size * 0.34, y: imageRect.minY + size * 0.12))
    mountainFront.line(to: NSPoint(x: imageRect.minX + size * 0.56, y: imageRect.minY + size * 0.34))
    mountainFront.line(to: NSPoint(x: imageRect.maxX + size * 0.04, y: imageRect.minY + size * 0.08))
    mountainFront.line(to: NSPoint(x: imageRect.maxX + size * 0.04, y: imageRect.minY - size * 0.04))
    mountainFront.line(to: NSPoint(x: imageRect.minX - size * 0.04, y: imageRect.minY - size * 0.04))
    mountainFront.close()
    NSColor(calibratedRed: 0.16, green: 0.43, blue: 0.44, alpha: 1).setFill()
    mountainFront.fill()

    let censorRect = NSRect(
        x: cardRect.minX + size * 0.14,
        y: cardRect.minY + size * 0.14,
        width: cardRect.width * 0.5,
        height: cardRect.height * 0.28
    )
    let censorPath = NSBezierPath(roundedRect: censorRect, xRadius: size * 0.04, yRadius: size * 0.04)
    NSColor(calibratedRed: 0.06, green: 0.10, blue: 0.16, alpha: 0.82).setFill()
    censorPath.fill()

    let gridRows = 5
    let gridCols = 7
    let gap = size * 0.008
    let tileWidth = (censorRect.width - CGFloat(gridCols + 1) * gap) / CGFloat(gridCols)
    let tileHeight = (censorRect.height - CGFloat(gridRows + 1) * gap) / CGFloat(gridRows)

    for row in 0..<gridRows {
        for col in 0..<gridCols {
            let x = censorRect.minX + gap + CGFloat(col) * (tileWidth + gap)
            let y = censorRect.minY + gap + CGFloat(row) * (tileHeight + gap)
            let tileRect = NSRect(x: x, y: y, width: tileWidth, height: tileHeight)
            let hue = 0.52 + CGFloat((row + col) % 3) * 0.05
            let brightness = 0.55 + CGFloat((row * 2 + col) % 4) * 0.08
            NSColor(calibratedHue: hue, saturation: 0.45, brightness: brightness, alpha: 1).setFill()
            NSBezierPath(roundedRect: tileRect, xRadius: size * 0.008, yRadius: size * 0.008).fill()
        }
    }

    let focusStroke = NSBezierPath(roundedRect: censorRect.insetBy(dx: -size * 0.018, dy: -size * 0.018), xRadius: size * 0.05, yRadius: size * 0.05)
    focusStroke.setLineDash([size * 0.018, size * 0.014], count: 2, phase: 0)
    NSColor.white.withAlphaComponent(0.85).setStroke()
    focusStroke.lineWidth = size * 0.012
    focusStroke.stroke()

    let handleSize = size * 0.048
    let handles = [
        NSPoint(x: censorRect.minX - size * 0.03, y: censorRect.maxY + size * 0.03),
        NSPoint(x: censorRect.maxX + size * 0.03, y: censorRect.maxY + size * 0.03),
        NSPoint(x: censorRect.minX - size * 0.03, y: censorRect.minY - size * 0.03),
        NSPoint(x: censorRect.maxX + size * 0.03, y: censorRect.minY - size * 0.03)
    ]
    for point in handles {
        let rect = NSRect(x: point.x - handleSize / 2, y: point.y - handleSize / 2, width: handleSize, height: handleSize)
        NSColor.white.setFill()
        NSBezierPath(ovalIn: rect).fill()
        NSColor(calibratedRed: 0.06, green: 0.10, blue: 0.16, alpha: 1).setStroke()
        let outline = NSBezierPath(ovalIn: rect)
        outline.lineWidth = size * 0.008
        outline.stroke()
    }

    image.unlockFocus()
    return image
}

for spec in specs {
    let image = drawIcon(size: CGFloat(spec.points))
    try savePNG(image, to: iconsetURL.appendingPathComponent(spec.filename))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", icnsURL.path]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    throw NSError(domain: "IconGeneration", code: Int(process.terminationStatus))
}

print("Generated \(icnsURL.path)")
