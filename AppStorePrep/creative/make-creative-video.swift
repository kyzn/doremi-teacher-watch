//
//  make-creative-video.swift
//  Doremi Teacher iOS 27 product page header and search results videos: a drawn Apple Watch showing
//  the Listen screen (solfège names) on the app icon's navy. Glossy mint notes ride a treble staff in
//  from the left; as each note reaches the watch it sounds (mint rings leave the right side, one band
//  per note) and its name lights up green on the matching tile. No words beyond the app's own tiles.
//  Video only comes per placement (house notes: ~/Projects/apps/_books/README.md, "Header and search
//  image"), so this renders a 21:9 header (3840 x 1646) and a 3:2 search video (3840 x 2560), 9 s at
//  30 fps, muted (silent AAC track). The loop is seamless: six notes per 9 s, pattern period = loop.
//  The header keeps the watch inside the band iPhone actually shows (about x 846...2995,
//  y 336...1105 of the 21:9 frame); search results show it bigger, at phone size.
//  Run: swift make-creative-video.swift [header|search] [--still]
//       -> header-3840x1646.mp4, search-3840x2560.mp4 next to this file (+ a .png frame with --still)
//  Needs ffmpeg (brew install ffmpeg).
//

import AppKit
import CoreText
import Foundation

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let fps = 30, seconds = 9

struct Layout {
    var name: String, width: Int, height: Int
    /// Watch case center and height; everything else scales from the case height.
    var center: CGPoint, caseHeight: CGFloat
}

let layouts: [String: Layout] = [
    "header": Layout(name: "header", width: 3840, height: 1646, center: CGPoint(x: 1920, y: 720), caseHeight: 700),
    "search": Layout(name: "search", width: 3840, height: 2560, center: CGPoint(x: 1920, y: 1280), caseHeight: 1500),
]

// MARK: Melody

/// Notes as (tile name, staff step above the bottom line E4, in half line spacings). C5 is the third
/// space, F5 the top line, G5 just above it, A5 on a ledger line: the octave the app plays.
let steps: [String: CGFloat] = ["Do": 5, "Fa": 8, "Sol": 9, "La": 10]
let melody = ["Do", "Sol", "Fa", "La", "Sol", "Fa"]
let secondsPerNote = Double(seconds) / Double(melody.count)
/// How long a note keeps sounding after it reaches the watch.
let noteLength = 0.75

func colour(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

let mint: UInt32 = 0x66EBB8

struct Scene {
    let l: Layout
    var h: CGFloat { l.caseHeight }
    var caseWidth: CGFloat { h * 0.84 }
    var caseRect: CGRect { CGRect(x: l.center.x - caseWidth / 2, y: l.center.y - h / 2, width: caseWidth, height: h) }
    /// Staff line spacing in pixels.
    var space: CGFloat { h * 0.1 }
    /// Distance between neighbouring notes on the staff.
    var gap: CGFloat { space * 4.4 }
    var speed: CGFloat { gap / CGFloat(secondsPerNote) }
    /// The notes span steps 5...10; centre that range on the watch.
    var bottomLine: CGFloat { l.center.y + 7.5 * space / 2 }
    func y(step: CGFloat) -> CGFloat { bottomLine - step * space / 2 }

    /// Every note on screen at time t: its name and x. Note n reaches the watch at t = n * secondsPerNote.
    func notes(at t: Double) -> [(name: String, x: CGFloat)] {
        let current = Int((t / secondsPerNote).rounded(.down))
        var result: [(String, CGFloat)] = []
        for n in (current - 1)...(current + 12) {
            let x = caseRect.minX - CGFloat(Double(n) * secondsPerNote - t) * speed
            if x < -gap { break }
            let index = ((n % melody.count) + melody.count) % melody.count
            result.append((melody[index], x))
        }
        return result
    }

    /// The note that last reached the watch and how long ago.
    func lastNote(at t: Double) -> (name: String, since: Double) {
        let n = Int((t / secondsPerNote).rounded(.down))
        let index = ((n % melody.count) + melody.count) % melody.count
        return (melody[index], t - Double(n) * secondsPerNote)
    }

    func sounding(at t: Double) -> Bool {
        var since = lastNote(at: t).since
        if since < 0 { since += secondsPerNote }
        return since < noteLength
    }
}

// MARK: Drawing

func roundedPath(_ r: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func drawBackground(_ ctx: CGContext, _ s: Scene) {
    let space = CGColorSpaceCreateDeviceRGB()
    ctx.setFillColor(colour(0x020A36))
    ctx.fill(CGRect(x: 0, y: 0, width: s.l.width, height: s.l.height))
    let g = CGGradient(colorsSpace: space, colors: [colour(0x0A3AA6), colour(0x062684), colour(0x020A36)] as CFArray,
                       locations: [0, 0.45, 1])!
    ctx.drawRadialGradient(g, startCenter: s.l.center, startRadius: 0, endCenter: s.l.center,
                           endRadius: CGFloat(max(s.l.width, s.l.height)) * 0.62, options: [.drawsAfterEndLocation])
}

/// A glossy mint note head with its stem down, like the icon's clef.
func drawNote(_ ctx: CGContext, _ s: Scene, x: CGFloat, step: CGFloat) {
    let space = CGColorSpaceCreateDeviceRGB()
    let y = s.y(step: step), w = s.space * 1.36, hgt = s.space * 0.98
    // Ledger lines above the staff.
    var ledger: CGFloat = 10
    while ledger <= step {
        ctx.setStrokeColor(colour(mint, 0.55)); ctx.setLineWidth(s.space * 0.07); ctx.setLineCap(.round)
        ctx.move(to: CGPoint(x: x - w * 0.85, y: s.y(step: ledger))); ctx.addLine(to: CGPoint(x: x + w * 0.85, y: s.y(step: ledger)))
        ctx.strokePath()
        ledger += 2
    }
    let head = CGPath(ellipseIn: CGRect(x: -w / 2, y: -hgt / 2, width: w, height: hgt),
                      transform: [CGAffineTransform(rotationAngle: -0.38).concatenating(CGAffineTransform(translationX: x, y: y))])
    let stem = CGRect(x: x - w / 2 + s.space * 0.04, y: y, width: s.space * 0.13, height: s.space * 3.3)
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: s.space * 0.6, color: colour(0x3FF0B0, 0.5))
    ctx.setFillColor(colour(0x5FE8B4))
    ctx.addPath(head); ctx.fillPath()
    ctx.addPath(roundedPath(stem, stem.width / 2)); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(head); ctx.clip()
    let g = CGGradient(colorsSpace: space, colors: [colour(0x9CFAD6), colour(0x5FE8B4), colour(0x2FB988)] as CFArray,
                       locations: [0, 0.5, 1])!
    ctx.drawLinearGradient(g, start: CGPoint(x: x, y: y - hgt / 2), end: CGPoint(x: x, y: y + hgt / 2), options: [])
    let shine = CGRect(x: x - w * 0.3, y: y - hgt * 0.36, width: w * 0.38, height: hgt * 0.22)
    ctx.addPath(roundedPath(shine, shine.height / 2)); ctx.setFillColor(colour(0xFFFFFF, 0.45)); ctx.fillPath()
    ctx.restoreGState()
}

func drawStaff(_ ctx: CGContext, _ s: Scene, t: Double) {
    let edge = s.caseRect.minX + s.space
    ctx.saveGState()
    ctx.clip(to: CGRect(x: 0, y: 0, width: edge, height: CGFloat(s.l.height)))
    ctx.setStrokeColor(colour(mint, 0.32)); ctx.setLineWidth(s.space * 0.06)
    for line in 0..<5 {
        let y = s.y(step: CGFloat(line * 2))
        ctx.move(to: CGPoint(x: 0, y: y)); ctx.addLine(to: CGPoint(x: edge, y: y))
    }
    ctx.strokePath()
    for note in s.notes(at: t) where note.x < edge + s.space {
        drawNote(ctx, s, x: note.x, step: steps[note.name]!)
    }
    ctx.restoreGState()
}

/// Rings to the right of the watch. The ring at distance d shows the sound as it was d / c ago,
/// so each note leaves as one band.
func drawSound(_ ctx: CGContext, _ s: Scene, t: Double) {
    let c = s.speed * 2.2
    let start = s.caseWidth / 2 + s.h * 0.08, reach = s.h * 0.9
    let step = s.h * 0.024
    ctx.saveGState()
    ctx.setLineCap(.round)
    ctx.setLineWidth(s.h * 0.009)
    var d = (CGFloat(t) * c).truncatingRemainder(dividingBy: step)
    while d < reach {
        if s.sounding(at: t - Double(d / c)) {
            let fade = 1 - d / reach
            ctx.setStrokeColor(colour(mint, 0.95 * fade))
            ctx.addArc(center: s.l.center, radius: start + d, startAngle: -.pi * 0.16, endAngle: .pi * 0.16, clockwise: false)
            ctx.strokePath()
        }
        d += step
    }
    ctx.restoreGState()
}

func drawText(_ ctx: CGContext, _ text: String, size: CGFloat, weight: NSFont.Weight, colour c: CGColor,
              center: CGPoint? = nil, right: CGPoint? = nil) {
    let font = NSFont.systemFont(ofSize: size, weight: weight)
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [
        .font: font, .foregroundColor: NSColor(cgColor: c)!]))
    ctx.saveGState()
    ctx.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
    // Ink bounds count from the current text position: reset it before measuring.
    ctx.textPosition = .zero
    let ink = CTLineGetImageBounds(line, ctx)
    if let p = center {
        ctx.textPosition = CGPoint(x: p.x - ink.width / 2 - ink.minX, y: p.y + ink.height / 2 + ink.minY)
    } else if let p = right {
        ctx.textPosition = CGPoint(x: p.x - ink.width - ink.minX, y: p.y)
    }
    CTLineDraw(line, ctx)
    ctx.restoreGState()
}

func drawSymbol(_ ctx: CGContext, _ name: String, size: CGFloat, weight: NSFont.Weight, colour c: NSColor, center: CGPoint) {
    let config = NSImage.SymbolConfiguration(pointSize: size, weight: weight)
        .applying(NSImage.SymbolConfiguration(paletteColors: [c]))
    let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)!.withSymbolConfiguration(config)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)
    let r = CGRect(x: center.x - image.size.width / 2, y: center.y - image.size.height / 2,
                   width: image.size.width, height: image.size.height)
    image.draw(in: r, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    NSGraphicsContext.restoreGraphicsState()
}

func drawWatch(_ ctx: CGContext, _ s: Scene, t: Double) {
    let space = CGColorSpaceCreateDeviceRGB()
    let r = s.caseRect, h = s.h
    // Band, top and bottom, running off the frame.
    let bandWidth = s.caseWidth * 0.72
    let band = CGRect(x: s.l.center.x - bandWidth / 2, y: -10, width: bandWidth, height: CGFloat(s.l.height) + 20)
    ctx.saveGState()
    ctx.clip(to: band)
    let bg = CGGradient(colorsSpace: space, colors: [colour(0x15171C), colour(0x2A2D35), colour(0x15171C)] as CFArray,
                        locations: [0, 0.5, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: band.minX, y: 0), end: CGPoint(x: band.maxX, y: 0), options: [])
    ctx.restoreGState()
    // Crown and side button.
    let crown = CGRect(x: r.maxX - h * 0.012, y: r.minY + h * 0.24, width: h * 0.05, height: h * 0.15)
    ctx.addPath(roundedPath(crown, h * 0.018)); ctx.setFillColor(colour(0x3A3D44)); ctx.fillPath()
    let button = CGRect(x: r.maxX - h * 0.008, y: r.minY + h * 0.5, width: h * 0.022, height: h * 0.2)
    ctx.addPath(roundedPath(button, h * 0.01)); ctx.setFillColor(colour(0x2C2F36)); ctx.fillPath()
    // Case.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: h * 0.02), blur: h * 0.08, color: colour(0x000000, 0.6))
    ctx.addPath(roundedPath(r, h * 0.2)); ctx.setFillColor(colour(0x24272D)); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(roundedPath(r, h * 0.2)); ctx.clip()
    let cg = CGGradient(colorsSpace: space, colors: [colour(0x4A4E57), colour(0x22252B), colour(0x16181C)] as CFArray,
                        locations: [0, 0.4, 1])!
    ctx.drawLinearGradient(cg, start: CGPoint(x: r.minX, y: r.minY), end: CGPoint(x: r.maxX, y: r.maxY), options: [])
    ctx.restoreGState()
    // Screen.
    let inset = h * 0.045
    let screen = r.insetBy(dx: inset, dy: inset)
    ctx.addPath(roundedPath(screen, h * 0.16)); ctx.setFillColor(colour(0x000000)); ctx.fillPath()
    drawListenScreen(ctx, s, screen: screen, t: t)
}

/// The Listen screen, from the 416 x 496 screenshot's geometry.
func drawListenScreen(_ ctx: CGContext, _ s: Scene, screen: CGRect, t: Double) {
    let pad = screen.width * 0.06
    let content = screen.insetBy(dx: pad, dy: pad * 0.7)
    let k = min(content.width / 416, content.height / 496)
    let o = CGPoint(x: content.midX - 208 * k, y: content.midY - 248 * k)
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: o.x + x * k, y: o.y + y * k) }
    func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect { CGRect(x: o.x + x * k, y: o.y + y * k, width: w * k, height: h * k) }

    // Back button and clock.
    ctx.addEllipse(in: rect(31, 38, 68, 68)); ctx.setFillColor(colour(0x2C2C2E)); ctx.fillPath()
    ctx.setStrokeColor(colour(0xFFFFFF)); ctx.setLineWidth(5 * k); ctx.setLineCap(.round); ctx.setLineJoin(.round)
    ctx.move(to: p(71, 58)); ctx.addLine(to: p(58, 72)); ctx.addLine(to: p(71, 86)); ctx.strokePath()
    drawText(ctx, "9:41", size: 30 * k, weight: .semibold, colour: colour(0xFFFFFF), right: p(386, 62))

    // Replay pill: brighter while a note sounds.
    let on = s.sounding(at: t)
    let pill = rect(5, 125, 334, 73)
    ctx.addPath(roundedPath(pill, 22 * k)); ctx.setFillColor(on ? colour(0x245A47) : colour(0x183A30)); ctx.fillPath()
    drawSymbol(ctx, "arrow.counterclockwise", size: 30 * k, weight: .bold, colour: NSColor(cgColor: colour(mint))!, center: p(111, 161.5))
    drawText(ctx, "Replay", size: 34 * k, weight: .bold, colour: colour(mint), center: p(194, 161.5))
    // Speaker.
    ctx.addEllipse(in: rect(353, 134, 56, 56)); ctx.setStrokeColor(colour(0x3A3A3C)); ctx.setLineWidth(3 * k); ctx.strokePath()
    drawSymbol(ctx, "speaker.fill", size: 22 * k, weight: .regular, colour: NSColor(white: 0.68, alpha: 1), center: p(381, 162))

    // Answer tiles. The note that just reached the watch lights up green.
    let last = s.lastNote(at: t)
    let glow = last.since < 1.0 ? CGFloat(1 - last.since) : 0
    let tiles: [(String, CGRect)] = [("Sol", rect(5, 213, 196, 98)), ("La", rect(215, 213, 196, 98)),
                                     ("Fa", rect(5, 325, 196, 98)), ("Do", rect(215, 325, 196, 98))]
    for (name, r) in tiles {
        ctx.addPath(roundedPath(r, 22 * k)); ctx.setFillColor(colour(0x3A3A3C)); ctx.fillPath()
        if name == last.name, glow > 0 {
            ctx.addPath(roundedPath(r, 22 * k)); ctx.setFillColor(colour(0x30D158, glow)); ctx.fillPath()
        }
        drawText(ctx, name, size: 46 * k, weight: .bold, colour: colour(0xFFFFFF), center: CGPoint(x: r.midX, y: r.midY))
    }
}

func drawFrame(_ ctx: CGContext, _ s: Scene, t: Double) {
    drawBackground(ctx, s)
    drawSound(ctx, s, t: t)
    drawStaff(ctx, s, t: t)
    drawWatch(ctx, s, t: t)
}

// MARK: Render

let args = CommandLine.arguments.dropFirst()
let which = args.filter { !$0.hasPrefix("--") }
let still = args.contains("--still")
for key in which.isEmpty ? ["header", "search"] : Array(which) {
    guard let l = layouts[key] else { fatalError("unknown layout \(key)") }
    let ctx = CGContext(data: nil, width: l.width, height: l.height, bitsPerComponent: 8, bytesPerRow: l.width * 4,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    // Draw top-down like the screenshot geometry; text undoes the flip with its text matrix.
    ctx.translateBy(x: 0, y: CGFloat(l.height)); ctx.scaleBy(x: 1, y: -1)
    let scene = Scene(l: l)
    let base = "\(l.name)-\(l.width)x\(l.height)"
    if still {
        drawFrame(ctx, scene, t: 1.7)
        let url = root.appendingPathComponent(base + ".png")
        try! NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!.write(to: url)
        print("wrote \(url.lastPathComponent)")
        continue
    }
    let out = root.appendingPathComponent(base + ".mp4")
    let ffmpeg = Process()
    ffmpeg.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/ffmpeg")
    ffmpeg.arguments = ["-y", "-loglevel", "error",
                        "-f", "rawvideo", "-pix_fmt", "rgb0", "-s", "\(l.width)x\(l.height)", "-r", "\(fps)", "-i", "-",
                        "-f", "lavfi", "-i", "anullsrc=r=48000:cl=stereo", "-shortest", "-vf", "gradfun",
                        "-c:v", "libx264", "-profile:v", "high", "-pix_fmt", "yuv420p", "-crf", "16", "-preset", "slow",
                        "-c:a", "aac", "-b:a", "128k", "-movflags", "+faststart", out.path]
    let pipe = Pipe()
    ffmpeg.standardInput = pipe
    try! ffmpeg.run()
    for f in 0..<(seconds * fps) {
        drawFrame(ctx, scene, t: Double(f) / Double(fps))
        pipe.fileHandleForWriting.write(Data(bytes: ctx.data!, count: l.width * l.height * 4))
    }
    try! pipe.fileHandleForWriting.close()
    ffmpeg.waitUntilExit()
    print("wrote \(out.lastPathComponent)")
}
