#!/usr/bin/env swift
import AppKit
import CoreGraphics

// Generates the iGlance app icon: a deep-space squircle with an aurora glow,
// a liquid-glass gauge ring, and a glossy iris.
//
// Run from the repo root: swift tools/generate-icon.swift
// Then: iconutil -c icns Assets/AppIcon.iconset -o Assets/AppIcon.icns

let canvasSize: CGFloat = 1024
let supersample: CGFloat = 4
let pixelSize = Int(canvasSize * supersample)
let outputDirectory = "Assets"

func rgba(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

func makeGradient(_ colors: [CGColor], _ locations: [CGFloat]) -> CGGradient {
    CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: locations)!
}

/// Superellipse ("squircle") path, matching the shape language of macOS icons.
func squircle(center: CGPoint, halfSize: CGFloat, exponent: CGFloat = 5) -> CGPath {
    let path = CGMutablePath()
    let steps = 1440
    for index in 0...steps {
        let t = CGFloat(index) / CGFloat(steps) * 2 * .pi
        let c = cos(t)
        let s = sin(t)
        let x = halfSize * copysign(pow(abs(c), 2 / exponent), c)
        let y = halfSize * copysign(pow(abs(s), 2 / exponent), s)
        let point = CGPoint(x: center.x + x, y: center.y + y)
        if index == 0 {
            path.move(to: point)
        } else {
            path.addLine(to: point)
        }
    }
    path.closeSubpath()
    return path
}

func sparkle(center: CGPoint, radius: CGFloat) -> CGPath {
    let path = CGMutablePath()
    path.move(to: CGPoint(x: center.x, y: center.y + radius))
    path.addQuadCurve(to: CGPoint(x: center.x + radius, y: center.y), control: center)
    path.addQuadCurve(to: CGPoint(x: center.x, y: center.y - radius), control: center)
    path.addQuadCurve(to: CGPoint(x: center.x - radius, y: center.y), control: center)
    path.addQuadCurve(to: CGPoint(x: center.x, y: center.y + radius), control: center)
    path.closeSubpath()
    return path
}

func interpolatedColor(_ stops: [(CGFloat, CGColor)], at t: CGFloat) -> CGColor {
    let clamped = min(max(t, 0), 1)
    for index in 0..<(stops.count - 1) {
        let (position0, color0) = stops[index]
        let (position1, color1) = stops[index + 1]
        guard clamped >= position0, clamped <= position1, position1 > position0 else { continue }

        let fraction = (clamped - position0) / (position1 - position0)
        let a = color0.components ?? [0, 0, 0, 1]
        let b = color1.components ?? [0, 0, 0, 1]
        return CGColor(
            red: a[0] + (b[0] - a[0]) * fraction,
            green: a[1] + (b[1] - a[1]) * fraction,
            blue: a[2] + (b[2] - a[2]) * fraction,
            alpha: a[3] + (b[3] - a[3]) * fraction
        )
    }
    return stops.last?.1 ?? rgba(0xFFFFFF)
}

func makeMasterImage() -> CGImage {
    let context = CGContext(
        data: nil,
        width: pixelSize,
        height: pixelSize,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!

    context.scaleBy(x: supersample, y: supersample)
    context.setAllowsAntialiasing(true)
    context.interpolationQuality = .high

    let center = CGPoint(x: 512, y: 512)
    let body = squircle(center: center, halfSize: 412)

    // Soft drop shadow.
    context.saveGState()
    context.setShadow(
        offset: CGSize(width: 0, height: -20),
        blur: 44,
        color: rgba(0x000000, 0.38)
    )
    context.addPath(body)
    context.setFillColor(rgba(0x0B1026))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(body)
    context.clip()

    // Background: deep indigo gradient with an aurora at both corners.
    let background = makeGradient(
        [rgba(0x2B3B8F), rgba(0x141C4A), rgba(0x080B1C)],
        [0, 0.55, 1]
    )
    context.drawLinearGradient(
        background,
        start: CGPoint(x: 200, y: 930),
        end: CGPoint(x: 820, y: 90),
        options: []
    )

    context.setBlendMode(.plusLighter)

    let cyanGlow = makeGradient([rgba(0x38D9FF, 0.30), rgba(0x38D9FF, 0)], [0, 1])
    context.drawRadialGradient(
        cyanGlow,
        startCenter: CGPoint(x: 310, y: 780),
        startRadius: 0,
        endCenter: CGPoint(x: 310, y: 780),
        endRadius: 470,
        options: []
    )

    let violetGlow = makeGradient([rgba(0x8A5CFF, 0.38), rgba(0x8A5CFF, 0)], [0, 1])
    context.drawRadialGradient(
        violetGlow,
        startCenter: CGPoint(x: 760, y: 260),
        startRadius: 0,
        endCenter: CGPoint(x: 760, y: 260),
        endRadius: 500,
        options: []
    )

    context.setBlendMode(.normal)

    // Top sheen.
    let sheen = makeGradient(
        [rgba(0xFFFFFF, 0.16), rgba(0xFFFFFF, 0.03), rgba(0xFFFFFF, 0)],
        [0, 0.45, 1]
    )
    context.drawLinearGradient(
        sheen,
        start: CGPoint(x: 260, y: 924),
        end: CGPoint(x: 620, y: 430),
        options: []
    )

    // Bottom vignette.
    let vignette = makeGradient([rgba(0x000000, 0), rgba(0x02040E, 0.35)], [0, 1])
    context.drawLinearGradient(
        vignette,
        start: CGPoint(x: 512, y: 420),
        end: CGPoint(x: 512, y: 100),
        options: []
    )

    context.restoreGState()

    // Rim light.
    context.saveGState()
    context.addPath(body)
    context.setLineWidth(2.4)
    context.replacePathWithStrokedPath()
    context.clip()
    let rim = makeGradient(
        [rgba(0xFFFFFF, 0.65), rgba(0xFFFFFF, 0.20), rgba(0xFFFFFF, 0.05)],
        [0, 0.5, 1]
    )
    context.drawLinearGradient(
        rim,
        start: CGPoint(x: 180, y: 900),
        end: CGPoint(x: 840, y: 160),
        options: []
    )
    context.restoreGState()

    // Gauge geometry.
    let gaugeCenter = CGPoint(x: 512, y: 512)
    let gaugeRadius: CGFloat = 252
    let lineWidth: CGFloat = 76
    let startAngle = -CGFloat.pi / 4
    let sweep = CGFloat.pi * 1.5
    let progress: CGFloat = 0.82
    let progressEnd = startAngle + sweep * progress

    // Track.
    context.saveGState()
    context.setLineWidth(lineWidth)
    context.setLineCap(.round)
    context.addArc(
        center: gaugeCenter,
        radius: gaugeRadius,
        startAngle: startAngle,
        endAngle: startAngle + sweep,
        clockwise: false
    )
    context.setStrokeColor(rgba(0xFFFFFF, 0.07))
    context.strokePath()
    context.restoreGState()

    // Glowing progress arc.
    context.saveGState()
    context.setShadow(
        offset: .zero,
        blur: 44,
        color: rgba(0x5CE1FF, 0.55)
    )
    context.setLineWidth(lineWidth)
    context.setLineCap(.round)
    context.addArc(
        center: gaugeCenter,
        radius: gaugeRadius,
        startAngle: startAngle,
        endAngle: progressEnd,
        clockwise: false
    )
    context.setStrokeColor(rgba(0x59D8FF))
    context.strokePath()
    context.restoreGState()

    let endPoint = CGPoint(
        x: gaugeCenter.x + cos(progressEnd) * gaugeRadius,
        y: gaugeCenter.y + sin(progressEnd) * gaugeRadius
    )

    // Conic-looking gradient along the arc, drawn as short overlapping
    // segments so it works without a public conic-gradient CG API.
    let arcStops: [(CGFloat, CGColor)] = [
        (0.00, rgba(0x5CE1FF)),
        (0.30, rgba(0x3D7BFF)),
        (0.60, rgba(0x8A5CFF)),
        (0.84, rgba(0xFF6FD8)),
        (1.00, rgba(0x5CE1FF))
    ]

    context.saveGState()
    context.setLineWidth(lineWidth)
    context.setLineCap(.butt)

    let segmentCount = 180
    for index in 0..<segmentCount {
        let fraction0 = CGFloat(index) / CGFloat(segmentCount)
        let fraction1 = CGFloat(index + 1) / CGFloat(segmentCount)
        let angle0 = startAngle + sweep * progress * fraction0
        // Extend each segment slightly to hide hairline seams.
        let angle1 = startAngle + sweep * progress * fraction1 + 0.003

        context.addArc(
            center: gaugeCenter,
            radius: gaugeRadius,
            startAngle: angle0,
            endAngle: angle1,
            clockwise: false
        )
        context.setStrokeColor(interpolatedColor(arcStops, at: fraction0))
        context.strokePath()
    }

    // Round caps at both ends.
    let capRadius = lineWidth / 2
    let startPoint = CGPoint(
        x: gaugeCenter.x + cos(startAngle) * gaugeRadius,
        y: gaugeCenter.y + sin(startAngle) * gaugeRadius
    )
    context.setFillColor(interpolatedColor(arcStops, at: 0))
    context.fillEllipse(in: CGRect(
        x: startPoint.x - capRadius,
        y: startPoint.y - capRadius,
        width: capRadius * 2,
        height: capRadius * 2
    ))
    context.setFillColor(interpolatedColor(arcStops, at: 1))
    context.fillEllipse(in: CGRect(
        x: endPoint.x - capRadius,
        y: endPoint.y - capRadius,
        width: capRadius * 2,
        height: capRadius * 2
    ))
    context.restoreGState()

    // End point dot.
    context.saveGState()
    context.setShadow(offset: .zero, blur: 14, color: rgba(0xFFFFFF, 0.6))
    context.setFillColor(rgba(0xFFFFFF, 0.95))
    context.fillEllipse(in: CGRect(
        x: endPoint.x - 8,
        y: endPoint.y - 8,
        width: 16,
        height: 16
    ))
    context.restoreGState()

    // Iris glow.
    context.saveGState()
    let irisGlow = makeGradient([rgba(0x5CE1FF, 0.40), rgba(0x5CE1FF, 0)], [0, 1])
    context.drawRadialGradient(
        irisGlow,
        startCenter: gaugeCenter,
        startRadius: 0,
        endCenter: gaugeCenter,
        endRadius: 190,
        options: []
    )
    context.restoreGState()

    // Plain luminous disc in the center.
    let discRadius: CGFloat = 108
    let discRect = CGRect(
        x: gaugeCenter.x - discRadius,
        y: gaugeCenter.y - discRadius,
        width: discRadius * 2,
        height: discRadius * 2
    )

    context.saveGState()
    context.addEllipse(in: discRect)
    context.clip()
    let disc = makeGradient(
        [rgba(0xB6F6FF), rgba(0x57D8FF), rgba(0x2B66F0), rgba(0x0D1E56)],
        [0, 0.42, 0.78, 1]
    )
    context.drawLinearGradient(
        disc,
        start: CGPoint(x: gaugeCenter.x - 80, y: gaugeCenter.y + 80),
        end: CGPoint(x: gaugeCenter.x + 90, y: gaugeCenter.y - 90),
        options: []
    )
    context.restoreGState()

    // Disc rim.
    context.saveGState()
    context.setLineWidth(2)
    context.setStrokeColor(rgba(0xFFFFFF, 0.28))
    context.strokeEllipse(in: discRect.insetBy(dx: 1, dy: 1))
    context.restoreGState()

    // Small sparkle accent.
    context.saveGState()
    context.setShadow(offset: .zero, blur: 16, color: rgba(0xFFFFFF, 0.6))
    context.addPath(sparkle(center: CGPoint(x: 745, y: 760), radius: 26))
    context.setFillColor(rgba(0xFFFFFF, 0.92))
    context.fillPath()
    context.addPath(sparkle(center: CGPoint(x: 795, y: 705), radius: 10))
    context.setFillColor(rgba(0xFFFFFF, 0.70))
    context.fillPath()
    context.restoreGState()

    return context.makeImage()!
}

func resize(_ image: CGImage, to size: Int) -> CGImage {
    let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.interpolationQuality = .high
    context.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
    return context.makeImage()!
}

func writePNG(_ image: CGImage, to path: String) {
    let representation = NSBitmapImageRep(cgImage: image)
    guard let data = representation.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode PNG at \(path)")
    }
    try! data.write(to: URL(fileURLWithPath: path))
}

let master = makeMasterImage()
let iconSet = "\(outputDirectory)/AppIcon.iconset"
try! FileManager.default.createDirectory(atPath: iconSet, withIntermediateDirectories: true)

writePNG(resize(master, to: 1024), to: "\(outputDirectory)/AppIcon-1024.png")

let sizes: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, size) in sizes {
    writePNG(resize(master, to: size), to: "\(iconSet)/\(name)")
}

print("Wrote \(outputDirectory)/AppIcon-1024.png and \(iconSet)")
