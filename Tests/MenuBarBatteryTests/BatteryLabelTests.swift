import AppKit
import XCTest
import AirPodsBattery
@testable import MenuBarBattery

final class StatusLayoutTests: XCTestCase {
    func testMatchingBudsUsePairGlyphThenCase() {
        let pieces = StatusLayout.pieces(for: AirPodsBattery(
            name: "AirPods", left: 85, right: 85, caseLevel: 62
        ))
        XCTAssertEqual(pieces, [
            StatusPiece(glyph: .pair, percent: 85),
            StatusPiece(glyph: .chargingCase, percent: 62),
        ])
    }

    func testOneBudUsesPairGlyphAndKeepsCase() {
        let leftOnly = StatusLayout.pieces(for: AirPodsBattery(
            name: "AirPods", left: 85, right: nil, caseLevel: 62
        ))
        XCTAssertEqual(leftOnly, [
            StatusPiece(glyph: .pair, percent: 85),
            StatusPiece(glyph: .chargingCase, percent: 62),
        ])
        let rightOnly = StatusLayout.pieces(for: AirPodsBattery(
            name: "AirPods", left: nil, right: 40, caseLevel: nil
        ))
        XCTAssertEqual(rightOnly, [
            StatusPiece(glyph: .pair, percent: 40),
        ])
    }

    func testUnequalBudsLayOutLeftThenRightThenCase() {
        let pieces = StatusLayout.pieces(for: AirPodsBattery(
            name: "AirPods", left: 85, right: 71, caseLevel: 62
        ))
        XCTAssertEqual(pieces, [
            StatusPiece(glyph: .left, percent: 85),
            StatusPiece(glyph: .right, percent: 71),
            StatusPiece(glyph: .chargingCase, percent: 62),
        ])
    }

    func testNilCaseStaysHidden() {
        let pieces = StatusLayout.pieces(for: AirPodsBattery(
            name: "AirPods", left: 85, right: 71, caseLevel: nil
        ))
        XCTAssertEqual(pieces, [
            StatusPiece(glyph: .left, percent: 85),
            StatusPiece(glyph: .right, percent: 71),
        ])
        let slept = StatusLayout.pieces(for: AirPodsBattery(
            name: "AirPods", left: 50, right: 50, caseLevel: 0
        ))
        XCTAssertEqual(slept, [StatusPiece(glyph: .pair, percent: 50)])
    }

    func testAirPodsMaxUsesHeadphonesAndSinglePercent() {
        let pieces = StatusLayout.pieces(for: AirPodsBattery(
            name: "AirPods Max", single: 64
        ))
        XCTAssertEqual(pieces, [StatusPiece(glyph: .maxHeadset, percent: 64)])
    }

    func testNoLevelsProducesNothing() {
        let pieces = StatusLayout.pieces(for: AirPodsBattery(name: "AirPods Pro"))
        XCTAssertTrue(pieces.isEmpty)
        XCTAssertNil(StatusLayout.accessibilityDescription(for: AirPodsBattery(name: "AirPods Pro")))
    }

    func testCaseOnlyShowsTheCase() {
        let pieces = StatusLayout.pieces(for: AirPodsBattery(name: "AirPods", caseLevel: 15))
        XCTAssertEqual(pieces, [StatusPiece(glyph: .chargingCase, percent: 15)])
    }

    func testMenuWritesLeftRightCaseAndDashForMissing() {
        let lines = StatusLayout.menuLines(for: AirPodsBattery(
            name: "AirPods Pro", left: 85, right: nil, caseLevel: 62
        ))
        XCTAssertEqual(lines.map(\.title), ["Left: 85%", "Right: —", "Case: 62%"])
    }

    func testMenuWritesSingleBatteryForMax() {
        let lines = StatusLayout.menuLines(for: AirPodsBattery(name: "AirPods Max", single: 64))
        XCTAssertEqual(lines.map(\.title), ["Battery: 64%"])
    }

    func testAccessibilityDescriptionMatchesVisiblePieces() {
        let same = StatusLayout.accessibilityDescription(for: AirPodsBattery(
            name: "AirPods Pro", left: 85, right: 85, caseLevel: 62
        ))
        XCTAssertEqual(same, "AirPods Pro, AirPods Pro 85%, case 62%")
        let split = StatusLayout.accessibilityDescription(for: AirPodsBattery(
            name: "AirPods Pro", left: 85, right: 71, caseLevel: 62
        ))
        XCTAssertEqual(split, "AirPods Pro, left 85%, right 71%, case 62%")
        let max = StatusLayout.accessibilityDescription(for: AirPodsBattery(name: "AirPods Max", single: 64))
        XCTAssertEqual(max, "AirPods Max, AirPods Max 64%")
    }

    func testProByNameUsesProSymbols() {
        let pieces = StatusLayout.pieces(for: AirPodsBattery(
            name: "AirPods Pro", left: 100, right: 100, caseLevel: 100
        ))
        XCTAssertEqual(pieces, [
            StatusPiece(glyph: .proPair, percent: 100),
            StatusPiece(glyph: .proCase, percent: 100),
        ])
        let hiddenCase = StatusLayout.pieces(for: AirPodsBattery(
            name: "Aditya’s AirPods Pro", left: 90, right: 90, caseLevel: nil
        ))
        XCTAssertEqual(hiddenCase, [StatusPiece(glyph: .proPair, percent: 90)])
    }

    func testProByProductIDUsesProSymbolsWithoutProInTheName() {
        let pieces = StatusLayout.pieces(for: AirPodsBattery(
            name: "AirPods",
            left: 85,
            right: 85,
            caseLevel: 62,
            productID: 0x2024
        ))
        XCTAssertEqual(pieces, [
            StatusPiece(glyph: .proPair, percent: 85),
            StatusPiece(glyph: .proCase, percent: 62),
        ])
    }

    func testUnequalProBudsLayOutLeftRightThenCase() {
        let pieces = StatusLayout.pieces(for: AirPodsBattery(
            name: "AirPods Pro", left: 85, right: 71, caseLevel: 62
        ))
        XCTAssertEqual(pieces, [
            StatusPiece(glyph: .proLeft, percent: 85),
            StatusPiece(glyph: .proRight, percent: 71),
            StatusPiece(glyph: .proCase, percent: 62),
        ])
        let noCase = StatusLayout.pieces(for: AirPodsBattery(
            name: "AirPods Pro", left: 85, right: 71, productID: 0x2024
        ))
        XCTAssertEqual(noCase, [
            StatusPiece(glyph: .proLeft, percent: 85),
            StatusPiece(glyph: .proRight, percent: 71),
        ])
    }

    func testMaxByNameUsesMaxSymbol() {
        let pieces = StatusLayout.pieces(for: AirPodsBattery(name: "AirPods Max", single: 64))
        XCTAssertEqual(pieces, [StatusPiece(glyph: .maxHeadset, percent: 64)])
    }

    func testMaxBySingleBatteryUsesMaxSymbol() {
        let pieces = StatusLayout.pieces(for: AirPodsBattery(name: "Headphones", single: 40))
        XCTAssertEqual(pieces, [StatusPiece(glyph: .maxHeadset, percent: 40)])
    }

    func testPlainAirPodsKeepTheOriginalSymbols() {
        let pieces = StatusLayout.pieces(for: AirPodsBattery(
            name: "AirPods", left: 85, right: 85, caseLevel: 62
        ))
        XCTAssertEqual(pieces, [
            StatusPiece(glyph: .pair, percent: 85),
            StatusPiece(glyph: .chargingCase, percent: 62),
        ])
    }

    func testMissingModelSymbolsFallBackToPlainNames() {
        let missing: (String) -> Bool = { _ in false }
        XCTAssertEqual(StatusPiece.Glyph.proPair.resolvedSymbolName(isAvailable: missing), "airpods")
        XCTAssertEqual(StatusPiece.Glyph.proLeft.resolvedSymbolName(isAvailable: missing), "airpod.left")
        XCTAssertEqual(StatusPiece.Glyph.proRight.resolvedSymbolName(isAvailable: missing), "airpod.right")
        XCTAssertEqual(StatusPiece.Glyph.proCase.resolvedSymbolName(isAvailable: missing), "airpods.chargingcase.fill")
        XCTAssertEqual(StatusPiece.Glyph.maxHeadset.resolvedSymbolName(isAvailable: missing), "headphones")
        XCTAssertEqual(
            StatusPiece.Glyph.proPair.resolvedSymbolName { $0 == "airpodspro" },
            "airpodspro"
        )
    }

    func testOutlineCaseSymbols() {
        let missing: (String) -> Bool = { _ in false }
        XCTAssertEqual(
            StatusPiece.Glyph.chargingCase.resolvedSymbolName(filledChargingCase: false, isAvailable: missing),
            "airpods.chargingcase"
        )
        XCTAssertEqual(
            StatusPiece.Glyph.proCase.resolvedSymbolName(filledChargingCase: false, isAvailable: missing),
            "airpods.chargingcase"
        )
        XCTAssertEqual(
            StatusPiece.Glyph.proCase.resolvedSymbolName(filledChargingCase: false) {
                $0 == "airpodspro.chargingcase.wireless"
            },
            "airpodspro.chargingcase.wireless"
        )
        XCTAssertEqual(
            StatusPiece.Glyph.chargingCase.symbolName(filledChargingCase: true),
            "airpods.chargingcase.fill"
        )
    }
}

@MainActor
final class BatteryLabelDrawingTests: XCTestCase {
    func testSymbolsExist() {
        for name in [
            "airpods", "airpod.left", "airpod.right", "airpods.chargingcase.fill", "airpods.chargingcase",
            "headphones",
            "airpodspro", "airpodpro.left", "airpodpro.right", "airpodspro.chargingcase.wireless.fill",
            "airpodspro.chargingcase.wireless",
            "airpodsmax",
        ] {
            XCTAssertNotNil(NSImage(systemSymbolName: name, accessibilityDescription: nil), name)
        }
    }

    func testTemplateImageDrawsInkAndHidesWhenEmpty() throws {
        let battery = AirPodsBattery(name: "AirPods Pro", left: 85, right: 85, caseLevel: 62)
        let image = try XCTUnwrap(BatteryLabel.image(for: battery))
        XCTAssertTrue(image.isTemplate)
        XCTAssertGreaterThan(image.size.width, 40)
        let ink = try inkStats(image)
        XCTAssertGreaterThan(ink.count, 40)
        XCTAssertGreaterThan(ink.bounds.height, 8)
        XCTAssertLessThan(ink.bounds.maxY, image.size.height + 0.5)

        let split = try XCTUnwrap(BatteryLabel.image(for: AirPodsBattery(
            name: "AirPods Pro", left: 85, right: 71, caseLevel: 62
        )))
        XCTAssertGreaterThan(split.size.width, image.size.width)

        XCTAssertNil(BatteryLabel.image(for: AirPodsBattery(name: "AirPods Pro")))
    }

    func testPercentInkLinesUpWithTheSymbol() throws {
        let image = try XCTUnwrap(BatteryLabel.image(for: AirPodsBattery(
            name: "AirPods Max", single: 64
        )))
        let segments = try inkSegments(image, minimumGap: 1.5)
        XCTAssertGreaterThanOrEqual(segments.count, 2)
        XCTAssertEqual(segments[0].midY, segments[1].midY, accuracy: 1.25)
    }

    func testMonospacedDigitsKeepWidthWhenTheTensDigitChanges() throws {
        let eighty = try XCTUnwrap(BatteryLabel.image(for: AirPodsBattery(
            name: "AirPods Pro", left: 81, right: 81, caseLevel: 62
        )))
        let eleven = try XCTUnwrap(BatteryLabel.image(for: AirPodsBattery(
            name: "AirPods Pro", left: 11, right: 11, caseLevel: 11
        )))
        XCTAssertEqual(eighty.size.width, eleven.size.width)
    }

    func testMatchIconsPercentIsWiderThanSmaller() throws {
        let battery = AirPodsBattery(name: "AirPods Max", single: 64)
        let smaller = try XCTUnwrap(BatteryLabel.image(for: battery))
        let matched = try XCTUnwrap(BatteryLabel.image(
            for: battery,
            appearance: Appearance(percentSize: .matchIcons, iconStyle: .hierarchical, filledChargingCase: true)
        ))
        // The symbol box already sets the image height. Larger digits show up as width.
        XCTAssertGreaterThan(matched.size.width, smaller.size.width)
        XCTAssertGreaterThanOrEqual(matched.size.height, smaller.size.height)
    }

    func testMonochromeOutlineStillDrawsATemplateImage() throws {
        let image = try XCTUnwrap(BatteryLabel.image(
            for: AirPodsBattery(name: "AirPods", left: 85, right: 85, caseLevel: 62),
            appearance: Appearance(percentSize: .smaller, iconStyle: .monochrome, filledChargingCase: false)
        ))
        XCTAssertTrue(image.isTemplate)
        XCTAssertGreaterThan(image.size.width, 40)
    }

    private func inkStats(_ image: NSImage) throws -> (count: Int, bounds: NSRect) {
        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else {
            XCTFail("No bitmap")
            return (0, .zero)
        }
        var count = 0
        var minX = rep.pixelsWide
        var minY = rep.pixelsHigh
        var maxX = 0
        var maxY = 0
        for y in 0..<rep.pixelsHigh {
            for x in 0..<rep.pixelsWide {
                guard let color = rep.colorAt(x: x, y: y), color.alphaComponent > 0.2 else { continue }
                count += 1
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }
        let scale = image.size.width > 0 ? CGFloat(rep.pixelsWide) / image.size.width : 1
        let bounds = NSRect(
            x: CGFloat(minX) / scale,
            y: CGFloat(minY) / scale,
            width: CGFloat(max(maxX - minX + 1, 0)) / scale,
            height: CGFloat(max(maxY - minY + 1, 0)) / scale
        )
        return (count, bounds)
    }

    private struct InkSegment {
        let midY: CGFloat
    }

    /// Ink columns grouped into runs. Gaps narrower than `minimumGap` points stay
    /// inside a segment so a symbol's interior holes are not separate pieces.
    private func inkSegments(_ image: NSImage, minimumGap: CGFloat) throws -> [InkSegment] {
        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else {
            XCTFail("No bitmap")
            return []
        }
        let scale = image.size.width > 0 ? CGFloat(rep.pixelsWide) / image.size.width : 1
        var columns: [(minY: Int, maxY: Int)?] = []
        columns.reserveCapacity(rep.pixelsWide)
        for x in 0..<rep.pixelsWide {
            var minY = rep.pixelsHigh
            var maxY = -1
            for y in 0..<rep.pixelsHigh {
                guard let color = rep.colorAt(x: x, y: y), color.alphaComponent > 0.2 else { continue }
                minY = min(minY, y)
                maxY = max(maxY, y)
            }
            columns.append(maxY < 0 ? nil : (minY, maxY))
        }
        let gapPixels = max(Int((minimumGap * scale).rounded(.down)), 1)
        var segments: [InkSegment] = []
        var runStart: Int?
        var gap = 0
        func close(_ end: Int) {
            guard let start = runStart else { return }
            let boxes = columns[start..<end].compactMap { $0 }
            if let first = boxes.first {
                let minY = boxes.reduce(first.minY) { min($0, $1.minY) }
                let maxY = boxes.reduce(first.maxY) { max($0, $1.maxY) }
                segments.append(InkSegment(midY: (CGFloat(minY + maxY) / 2) / scale))
            }
            runStart = nil
        }
        for (index, column) in columns.enumerated() {
            if column == nil {
                gap += 1
                if runStart != nil, gap >= gapPixels {
                    close(index - gap + 1)
                }
            } else {
                if runStart == nil { runStart = index }
                gap = 0
            }
        }
        close(columns.count)
        return segments
    }
}

@MainActor
final class SettingsWindowTests: XCTestCase {
    func testAppearanceSettingsRoundTrip() {
        let name = "MenuBarBatteryAppearanceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        let settings = AppearanceSettings(defaults: defaults)
        XCTAssertEqual(settings.appearance, .standard)
        settings.appearance = Appearance(
            percentSize: .matchIcons,
            iconStyle: .monochrome,
            filledChargingCase: false
        )
        let reloaded = AppearanceSettings(defaults: defaults)
        XCTAssertEqual(reloaded.appearance, settings.appearance)
        defaults.removePersistentDomain(forName: name)
    }

    func testSettingsWindowShowsGeneralAndAppearance() throws {
        let settings = AppearanceSettings(defaults: UserDefaults(suiteName: UUID().uuidString)!)
        let controller = SettingsWindowController(appearance: settings)
        let window = try XCTUnwrap(controller.window)
        XCTAssertEqual(window.title, "Settings")
        XCTAssertFalse(window.styleMask.contains(.resizable))
        XCTAssertGreaterThan(window.contentView?.fittingSize.width ?? 0, 240)
        XCTAssertGreaterThan(window.contentView?.fittingSize.height ?? 0, 100)

        let labels = window.contentView.map(controlLabels(in:)) ?? []
        XCTAssertTrue(labels.contains("General"))
        XCTAssertTrue(labels.contains("Appearance"))
        XCTAssertTrue(labels.contains("Launch at Login"))
        XCTAssertTrue(labels.contains("Percent size"))
        XCTAssertTrue(labels.contains("Icons"))
        XCTAssertTrue(labels.contains("Filled charging case"))
        XCTAssertTrue(labels.contains("Smaller"))
        XCTAssertTrue(labels.contains("Same as icons"))
        XCTAssertTrue(labels.contains("Hierarchical"))
        XCTAssertTrue(labels.contains("Monochrome"))
        let popups = window.contentView.map(popupTitles(in:)) ?? []
        XCTAssertEqual(popups, ["Smaller", "Hierarchical"])
        XCTAssertEqual(filledState(in: window.contentView), .on)
    }

    private func popupTitles(in view: NSView) -> [String] {
        var titles: [String] = []
        if let popup = view as? NSPopUpButton {
            titles.append(popup.titleOfSelectedItem ?? "")
        }
        for subview in view.subviews {
            titles.append(contentsOf: popupTitles(in: subview))
        }
        return titles
    }

    private func filledState(in view: NSView?) -> NSControl.StateValue {
        guard let view else { return .off }
        if let button = view as? NSButton, button.title == "Filled charging case" {
            return button.state
        }
        for subview in view.subviews {
            let state = filledState(in: subview)
            if state == .on { return state }
        }
        return .off
    }

    private func controlLabels(in view: NSView) -> [String] {
        var found: [String] = []
        if let field = view as? NSTextField, !field.stringValue.isEmpty {
            found.append(field.stringValue)
        }
        if let popup = view as? NSPopUpButton {
            found.append(contentsOf: popup.itemTitles)
        } else if let button = view as? NSButton, !button.title.isEmpty {
            found.append(button.title)
        }
        for subview in view.subviews {
            found.append(contentsOf: controlLabels(in: subview))
        }
        return found
    }
}
