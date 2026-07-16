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

// Quartz injects volatile metadata; equal-length replacements preserve PDF offsets.
private let stablePDFDate = "D:20000101000000Z00'00'"
private let stablePDFID = "4461682056696e6369204c61756e6368" // "Dah Vinci Launch"

private enum PDFNormalizationError: LocalizedError {
    case invalidLatin1
    case unexpectedMatchCount(field: String, count: Int)
    case byteCountChanged

    var errorDescription: String? {
        switch self {
        case .invalidLatin1:
            return "Could not round-trip the generated PDF as ISO Latin-1"
        case let .unexpectedMatchCount(field, count):
            return "Expected one \(field) field in the generated PDF, found \(count)"
        case .byteCountChanged:
            return "PDF metadata normalization changed the byte count"
        }
    }
}

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

private func replaceSingleMatch(
    field: String,
    pattern: String,
    with template: String,
    in source: String
) throws -> String {
    let expression = try NSRegularExpression(pattern: pattern)
    let range = NSRange(source.startIndex..<source.endIndex, in: source)
    let matchCount = expression.numberOfMatches(in: source, range: range)
    guard matchCount == 1 else {
        throw PDFNormalizationError.unexpectedMatchCount(field: field, count: matchCount)
    }
    return expression.stringByReplacingMatches(
        in: source,
        range: range,
        withTemplate: template
    )
}

private func normalizePDFMetadata(at url: URL) throws {
    let originalData = try Data(contentsOf: url)
    guard var pdf = String(data: originalData, encoding: .isoLatin1) else {
        throw PDFNormalizationError.invalidLatin1
    }

    pdf = try replaceSingleMatch(
        field: "CreationDate",
        pattern: #"/CreationDate \(D:\d{14}Z00'00'\)"#,
        with: "/CreationDate (\(stablePDFDate))",
        in: pdf
    )
    pdf = try replaceSingleMatch(
        field: "ModDate",
        pattern: #"/ModDate \(D:\d{14}Z00'00'\)"#,
        with: "/ModDate (\(stablePDFDate))",
        in: pdf
    )
    pdf = try replaceSingleMatch(
        field: "document ID",
        pattern: #"/ID \[ <[0-9A-Fa-f]{32}>(\s*)<[0-9A-Fa-f]{32}> \]"#,
        with: "/ID [ <\(stablePDFID)>$1<\(stablePDFID)> ]",
        in: pdf
    )

    guard let normalizedData = pdf.data(using: .isoLatin1) else {
        throw PDFNormalizationError.invalidLatin1
    }
    guard normalizedData.count == originalData.count else {
        throw PDFNormalizationError.byteCountChanged
    }
    try normalizedData.write(to: url, options: .atomic)
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
try normalizePDFMetadata(at: outputURL)

print("Generated \(outputPath)")
