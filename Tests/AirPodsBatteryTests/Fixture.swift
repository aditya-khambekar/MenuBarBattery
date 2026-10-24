import Foundation
import XCTest
@testable import AirPodsBattery

enum Fixture {
    static func data(_ name: String, file: StaticString = #filePath, line: UInt = #line) throws -> Data {
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        let typedExt = ext.isEmpty ? nil : ext
        if let url = Bundle.module.url(forResource: base, withExtension: typedExt, subdirectory: "Fixtures")
            ?? Bundle.module.url(forResource: base, withExtension: typedExt) {
            return try Data(contentsOf: url)
        }
        let fallback = URL(filePath: "\(file)")
            .deletingLastPathComponent()
            .appending(path: "Fixtures")
            .appending(path: name)
        return try Data(contentsOf: fallback)
    }

    static func string(_ name: String, file: StaticString = #filePath, line: UInt = #line) throws -> String {
        String(decoding: try data(name, file: file, line: line), as: UTF8.self)
    }
}

func profilerCandidates(
    _ name: String,
    file: StaticString = #filePath,
    line: UInt = #line
) throws -> [AirPodsBattery] {
    try SystemProfilerBluetoothParser.candidates(from: Fixture.data(name, file: file, line: line))
}

func selectedFixture(
    _ name: String,
    outputDeviceName: String? = nil,
    file: StaticString = #filePath,
    line: UInt = #line
) throws -> AirPodsBattery {
    let data = try Fixture.data(name, file: file, line: line)
    return try XCTUnwrap(
        selectAirPodsBattery(profilerJSON: data, outputDeviceName: outputDeviceName),
        file: file,
        line: line
    )
}

func makeSnapshot(
    name: String = "AirPods Pro",
    isConnected: Bool = true,
    vendorID: Int? = BluetoothBatterySnapshot.appleVendorID,
    isHeadphones: Bool = true,
    exposesBatterySelectors: Bool = true,
    left: Int? = nil,
    right: Int? = nil,
    caseLevel: Int? = nil,
    single: Int? = nil,
    productID: Int? = nil
) -> BluetoothBatterySnapshot {
    BluetoothBatterySnapshot(
        name: name,
        isConnected: isConnected,
        vendorID: vendorID,
        productID: productID,
        isHeadphones: isHeadphones,
        exposesBatterySelectors: exposesBatterySelectors,
        left: left,
        right: right,
        caseLevel: caseLevel,
        single: single
    )
}
