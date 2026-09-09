// Renders the 1024×1024 app icon with no alpha channel.
//   swift scripts/make-icon.swift DoremiTeacher/Assets.xcassets/AppIcon.appiconset/AppIcon.png
// The same file is copied into the container catalog; the two must stay identical.
import AppKit
import CoreGraphics
import Foundation

let size: CGFloat = 1024
let cs = CGColorSpaceCreateDeviceRGB()
guard let ctx = CGContext(data: nil, width: Int(size), height: Int(size),
                          bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { exit(1) }

func rgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [r, g, b, a])!
}

// Deep indigo ground with a warm glow rising from the bottom.
ctx.setFillColor(rgb(0.07, 0.06, 0.12))
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
let glow = CGGradient(colorsSpace: cs,
                      colors: [rgb(0.42, 0.28, 0.10), rgb(0.07, 0.06, 0.12, 0)] as CFArray,
                      locations: [0, 1])!
ctx.drawRadialGradient(glow,
                       startCenter: CGPoint(x: size * 0.5, y: size * 0.15), startRadius: 0,
                       endCenter: CGPoint(x: size * 0.5, y: size * 0.15), endRadius: size * 0.8,
                       options: [])

// Three rising pills, Do Re Mi, in the amber accent. Sized to survive the circular crop.
let accent = rgb(0.98, 0.72, 0.30)
let pillWidth = size * 0.17
let pillHeight = size * 0.11
let gap = size * 0.05
let totalWidth = pillWidth * 3 + gap * 2
let originX = (size - totalWidth) / 2
let baseY = size * 0.36
let rise = size * 0.10
for step in 0..<3 {
    let x = originX + CGFloat(step) * (pillWidth + gap)
    let y = baseY + CGFloat(step) * rise
    let rect = CGRect(x: x, y: y, width: pillWidth, height: pillHeight)
    ctx.setFillColor(step == 2 ? rgb(1, 0.86, 0.55) : accent)
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: pillHeight / 2, cornerHeight: pillHeight / 2, transform: nil))
    ctx.fillPath()
}

guard let image = ctx.makeImage() else { exit(1) }
let rep = NSBitmapImageRep(cgImage: image)
guard let data = rep.representation(using: .png, properties: [:]) else { exit(1) }
try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
print("wrote \(CommandLine.arguments[1])")
