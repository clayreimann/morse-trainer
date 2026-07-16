import AppKit
import CoreGraphics
import CoreText
import Foundation

private enum Mark: Equatable {
    case dit
    case dah
}

private let canvasSize = CGSize(width: 320, height: 300)
private let markThickness: CGFloat = 8
private let dahWidth = markThickness * 3
private let intraLetterSpacing = markThickness * 0.5
private let interLetterSpacing = markThickness * 1.7

private let dahCode = "-.. .- ...."
private let vinciCode = "...- .. -. -.-. .."

private func parse(_ code: String) -> [[Mark]] {
    code.split(separator: " ").map { letter in
        letter.map { symbol in
            switch symbol {
            case ".": return .dit
            case "-": return .dah
            default: fatalError("Unsupported Morse symbol: \(symbol)")
            }
        }
    }
}

private func rgb(_ hex: UInt32) -> CGColor {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let red = CGFloat((hex >> 16) & 0xFF) / 255
    let green = CGFloat((hex >> 8) & 0xFF) / 255
    let blue = CGFloat(hex & 0xFF) / 255
    return CGColor(
        colorSpace: colorSpace,
        components: [red, green, blue, 1]
    )!
}

private func drawGradient(in context: CGContext) {
    let colors = [rgb(0x756EE8), rgb(0x377FF1), rgb(0x16B8D8)] as CFArray
    let locations: [CGFloat] = [0, 0.45, 1]
    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: colors,
        locations: locations
    )!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: canvasSize.height),
        end: CGPoint(x: canvasSize.width, y: 0),
        options: []
    )
}

private func roundedHeavyFont(size: CGFloat) -> NSFont {
    let system = NSFont.systemFont(ofSize: size, weight: .heavy)
    let descriptor = system.fontDescriptor.withDesign(.rounded) ?? system.fontDescriptor
    return NSFont(descriptor: descriptor, size: size)!
}

private func drawWord(
    _ word: String,
    centeredIn rect: CGRect,
    context: CGContext
) {
    let attributed = NSAttributedString(
        string: word,
        attributes: [.font: roundedHeavyFont(size: 68)]
    )
    let line = CTLineCreateWithAttributedString(attributed)
    let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)

    context.saveGState()
    context.textPosition = CGPoint(
        x: rect.midX - bounds.midX,
        y: rect.midY - bounds.midY
    )
    context.setTextDrawingMode(.clip)
    CTLineDraw(line, context)
    drawGradient(in: context)
    context.restoreGState()
}

private func width(of letter: [Mark]) -> CGFloat {
    let markWidths = letter.reduce(CGFloat.zero) { partial, mark in
        partial + (mark == .dit ? markThickness : dahWidth)
    }
    return markWidths + CGFloat(max(0, letter.count - 1)) * intraLetterSpacing
}

private func drawMorse(
    _ code: String,
    centerY: CGFloat,
    context: CGContext
) {
    let letters = parse(code)
    let totalWidth = letters.reduce(CGFloat.zero) { $0 + width(of: $1) }
        + CGFloat(max(0, letters.count - 1)) * interLetterSpacing
    var x = (canvasSize.width - totalWidth) / 2
    let y = centerY - markThickness / 2

    context.saveGState()
    context.beginPath()

    for (letterIndex, letter) in letters.enumerated() {
        for (markIndex, mark) in letter.enumerated() {
            let markWidth = mark == .dit ? markThickness : dahWidth
            let rect = CGRect(x: x, y: y, width: markWidth, height: markThickness)

            if mark == .dit {
                context.addEllipse(in: rect)
            } else {
                context.addPath(
                    CGPath(
                        roundedRect: rect,
                        cornerWidth: markThickness / 2,
                        cornerHeight: markThickness / 2,
                        transform: nil
                    )
                )
            }

            x += markWidth
            if markIndex < letter.count - 1 {
                x += intraLetterSpacing
            }
        }

        if letterIndex < letters.count - 1 {
            x += interLetterSpacing
        }
    }

    context.clip()
    drawGradient(in: context)
    context.restoreGState()
}

precondition(dahCode == "-.. .- ....")
precondition(vinciCode == "...- .. -. -.-. ..")

let outputPath = CommandLine.arguments.dropFirst().first
    ?? "App/Assets.xcassets/LaunchWordmark.imageset/LaunchWordmark.pdf"
let outputURL = URL(fileURLWithPath: outputPath)
try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)

var mediaBox = CGRect(origin: .zero, size: canvasSize)
guard let consumer = CGDataConsumer(url: outputURL as CFURL),
      let context = CGContext(
        consumer: consumer,
        mediaBox: &mediaBox,
        [kCGPDFContextTitle as String: "Dah Vinci Launch Wordmark"] as CFDictionary
      ) else {
    fatalError("Could not create PDF context at \(outputPath)")
}

context.beginPDFPage(nil)
drawWord("Dah", centeredIn: CGRect(x: 20, y: 220, width: 280, height: 72), context: context)
drawMorse(dahCode, centerY: 190, context: context)
drawWord("Vinci", centeredIn: CGRect(x: 8, y: 85, width: 304, height: 72), context: context)
drawMorse(vinciCode, centerY: 55, context: context)
context.endPDFPage()
context.closePDF()

print("Generated \(outputPath)")
