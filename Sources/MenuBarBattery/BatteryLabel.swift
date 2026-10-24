import AppKit
import CoreText
import AirPodsBattery

/// One glyph-and-percent pair drawn in the status item.
struct StatusPiece: Equatable {
    enum Glyph: Equatable {
        case pair
        case left
        case right
        case chargingCase
        case headphones
        case proPair
        case proLeft
        case proRight
        case proCase
        case maxHeadset

        var symbolName: String {
            switch self {
            case .pair: "airpods"
            case .left: "airpod.left"
            case .right: "airpod.right"
            case .chargingCase: "airpods.chargingcase"
            case .headphones: "headphones"
            case .proPair: "airpodspro"
            case .proLeft: "airpodpro.left"
            case .proRight: "airpodpro.right"
            case .proCase: "airpodspro.chargingcase.wireless"
            case .maxHeadset: "airpodsmax"
            }
        }

        /// Plain glyph used when the preferred symbol is not on this Mac.
        var fallbackSymbolName: String? {
            switch self {
            case .proPair: return "airpods"
            case .proLeft: return "airpod.left"
            case .proRight: return "airpod.right"
            case .proCase: return "airpods.chargingcase"
            case .maxHeadset: return "headphones"
            case .pair, .left, .right, .chargingCase, .headphones:
                return nil
            }
        }

        var accessibilityName: String {
            switch self {
            case .pair: "AirPods"
            case .left, .proLeft: "left"
            case .right, .proRight: "right"
            case .chargingCase, .proCase: "case"
            case .headphones: "headphones"
            case .proPair: "AirPods Pro"
            case .maxHeadset: "AirPods Max"
            }
        }

        func resolvedSymbolName(isAvailable: (String) -> Bool) -> String {
            if isAvailable(symbolName) { return symbolName }
            if let fallbackSymbolName { return fallbackSymbolName }
            return symbolName
        }
    }

    let glyph: Glyph
    let percent: Int
}

/// A labeled row in the click menu.
struct MenuLine: Equatable {
    let label: String
    /// `85%`, or an em dash when that part is not reporting.
    let value: String

    var title: String { "\(label): \(value)" }
}

/// Which glyphs the status item draws for a reading.
///
/// Matching buds, or a single bud, share the pair glyph, then the case.
/// Differing buds draw left, then right, then the case. A lone `single` level,
/// or a name containing "Max", uses the AirPods Max symbol. "Pro" in the name,
/// or product ID `0x2024`, uses the AirPods Pro symbols.
enum StatusLayout {
    static func pieces(for battery: AirPodsBattery) -> [StatusPiece] {
        let family = symbolFamily(for: battery)
        if family == .max {
            return maxPieces(for: battery)
        }
        if battery.left == nil, battery.right == nil {
            if let single = battery.single {
                var pieces = [StatusPiece(glyph: pairGlyph(family), percent: single)]
                if let caseLevel = battery.caseLevel {
                    pieces.append(StatusPiece(glyph: caseGlyph(family), percent: caseLevel))
                }
                return pieces
            }
            if let caseLevel = battery.caseLevel {
                return [StatusPiece(glyph: caseGlyph(family), percent: caseLevel)]
            }
            return []
        }

        if let left = battery.left, let right = battery.right, left != right {
            var pieces = [
                StatusPiece(glyph: leftGlyph(family), percent: left),
                StatusPiece(glyph: rightGlyph(family), percent: right),
            ]
            if let caseLevel = battery.caseLevel {
                pieces.append(StatusPiece(glyph: caseGlyph(family), percent: caseLevel))
            }
            return pieces
        }

        let budPercent = battery.left ?? battery.right ?? 0
        var pieces = [StatusPiece(glyph: pairGlyph(family), percent: budPercent)]
        if let caseLevel = battery.caseLevel {
            pieces.append(StatusPiece(glyph: caseGlyph(family), percent: caseLevel))
        }
        return pieces
    }

    private enum SymbolFamily {
        case pro
        case max
        case plain
    }

    private static func symbolFamily(for battery: AirPodsBattery) -> SymbolFamily {
        if battery.name.range(of: "pro", options: .caseInsensitive) != nil
            || battery.productID == AirPodsBattery.airPodsProProductID {
            return .pro
        }
        if battery.name.range(of: "max", options: .caseInsensitive) != nil
            || (battery.single != nil && battery.left == nil && battery.right == nil) {
            return .max
        }
        return .plain
    }

    private static func maxPieces(for battery: AirPodsBattery) -> [StatusPiece] {
        let percent = battery.single ?? battery.left ?? battery.right
        guard let percent else {
            if let caseLevel = battery.caseLevel {
                return [StatusPiece(glyph: .chargingCase, percent: caseLevel)]
            }
            return []
        }
        var pieces = [StatusPiece(glyph: .maxHeadset, percent: percent)]
        if let caseLevel = battery.caseLevel {
            pieces.append(StatusPiece(glyph: .chargingCase, percent: caseLevel))
        }
        return pieces
    }

    private static func pairGlyph(_ family: SymbolFamily) -> StatusPiece.Glyph {
        family == .pro ? .proPair : .pair
    }

    private static func leftGlyph(_ family: SymbolFamily) -> StatusPiece.Glyph {
        family == .pro ? .proLeft : .left
    }

    private static func rightGlyph(_ family: SymbolFamily) -> StatusPiece.Glyph {
        family == .pro ? .proRight : .right
    }

    private static func caseGlyph(_ family: SymbolFamily) -> StatusPiece.Glyph {
        family == .pro ? .proCase : .chargingCase
    }

    static func menuLines(for battery: AirPodsBattery) -> [MenuLine] {
        if battery.left == nil, battery.right == nil, battery.single != nil {
            var lines = [MenuLine(label: "Battery", value: percentText(battery.single))]
            if battery.caseLevel != nil {
                lines.append(MenuLine(label: "Case", value: percentText(battery.caseLevel)))
            }
            return lines
        }
        return [
            MenuLine(label: "Left", value: percentText(battery.left)),
            MenuLine(label: "Right", value: percentText(battery.right)),
            MenuLine(label: "Case", value: percentText(battery.caseLevel)),
        ]
    }

    static func accessibilityDescription(for battery: AirPodsBattery) -> String? {
        let pieces = pieces(for: battery)
        guard !pieces.isEmpty else { return nil }
        let body = pieces
            .map { "\($0.glyph.accessibilityName) \($0.percent)%" }
            .joined(separator: ", ")
        return "\(battery.name), \(body)"
    }

    private static func percentText(_ level: Int?) -> String {
        level.map { "\($0)%" } ?? "—"
    }
}

/// Template status image. Black ink on a clear background, marked as a template
/// so a light menu bar tints it black and a dark menu bar tints it white.
@MainActor
enum BatteryLabel {
    private static let symbolPointSize: CGFloat = 13
    private static let fontSize: CGFloat = 13
    private static let glyphTextGap: CGFloat = 2
    private static let segmentGap: CGFloat = 6

    static func image(for battery: AirPodsBattery) -> NSImage? {
        let pieces = StatusLayout.pieces(for: battery)
        guard !pieces.isEmpty else { return nil }

        let font = NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .regular)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black,
        ]
        let measured = pieces.map { piece in
            MeasuredPiece(
                symbol: symbolImage(piece.glyph),
                text: NSAttributedString(string: "\(piece.percent)%", attributes: attributes)
            )
        }

        var width: CGFloat = 0
        var height: CGFloat = 0
        for (index, piece) in measured.enumerated() {
            if index > 0 { width += segmentGap }
            width += ceil(piece.symbolSize.width) + glyphTextGap + ceil(piece.textSize.width)
            height = max(height, piece.symbolSize.height, piece.textSize.height)
        }
        let size = NSSize(width: max(ceil(width), 1), height: max(ceil(height), 1))
        let image = NSImage(size: size)
        image.lockFocus()
        var x: CGFloat = 0
        for (index, piece) in measured.enumerated() {
            if index > 0 { x += segmentGap }
            let symbolRect = NSRect(
                x: x,
                y: (size.height - piece.symbolSize.height) / 2,
                width: piece.symbolSize.width,
                height: piece.symbolSize.height
            )
            piece.symbol.draw(in: symbolRect, from: .zero, operation: .sourceOver, fraction: 1)
            x += ceil(piece.symbolSize.width) + glyphTextGap
            let line = CTLineCreateWithAttributedString(piece.text)
            let baseline = percentBaseline(line: line, symbol: piece.symbol, symbolRect: symbolRect)
            let context = NSGraphicsContext.current!.cgContext
            context.textMatrix = .identity
            context.textPosition = CGPoint(x: x, y: baseline)
            CTLineDraw(line, context)
            x += ceil(piece.textSize.width)
        }
        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    /// Baseline that centers the percent's glyph ink on the symbol's alignment rect.
    ///
    /// `draw(with:)` without `.usesLineFragmentOrigin` uses the rect origin as the
    /// baseline. Centering `text.size()` puts that baseline at the bottom of the
    /// line box, descender included, so the digits sit below the symbol.
    /// `draw(at:)` does not use the point as the baseline in this unflipped image
    /// context either. Core Text does. The alignment rect is the symbol's cap-height box.
    private static func percentBaseline(
        line: CTLine,
        symbol: NSImage,
        symbolRect: NSRect
    ) -> CGFloat {
        let alignment = symbol.alignmentRect
        let optical = (alignment.width > 1 && alignment.height > 1)
            ? alignment
            : NSRect(origin: .zero, size: symbol.size)
        let ink = CTLineGetImageBounds(line, nil)
        return symbolRect.minY + optical.midY - ink.midY
    }

    private static func symbolImage(_ glyph: StatusPiece.Glyph) -> NSImage {
        let name = glyph.resolvedSymbolName { systemSymbol($0) != nil }
        if let symbol = systemSymbol(name) {
            return symbol
        }
        if let fallback = glyph.fallbackSymbolName, let symbol = systemSymbol(fallback) {
            return symbol
        }
        let fallback = NSImage(size: NSSize(width: symbolPointSize, height: symbolPointSize))
        fallback.lockFocus()
        NSColor.black.setFill()
        NSBezierPath(ovalIn: NSRect(x: 1, y: 1, width: symbolPointSize - 2, height: symbolPointSize - 2)).fill()
        fallback.unlockFocus()
        return fallback
    }

    private static func systemSymbol(_ name: String) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: symbolPointSize, weight: .regular)
            .applying(NSImage.SymbolConfiguration(paletteColors: [.black]))
        guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration) else {
            return nil
        }
        symbol.isTemplate = false
        return symbol
    }
}

private struct MeasuredPiece {
    let symbol: NSImage
    let text: NSAttributedString

    var symbolSize: NSSize { symbol.size }
    var textSize: NSSize { text.size() }
}
