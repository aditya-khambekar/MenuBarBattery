import Foundation

/// Battery reading for one connected AirPods set.
///
/// `nil` means that part is not reporting. `0` is treated as not reporting:
/// a sleeping case often comes back as `0` and must not surface as 0%.
public struct AirPodsBattery: Equatable, Sendable, CustomStringConvertible {
    /// USB product ID for the AirPods Pro set this Mac reports (`0x2024`).
    public static let airPodsProProductID = 0x2024

    public let name: String
    public let left: Int?
    public let right: Int?
    public let caseLevel: Int?
    public let single: Int?
    /// Bluetooth product ID from the same source as the levels. `nil` if that source had none.
    public let productID: Int?

    public init(
        name: String,
        left: Int? = nil,
        right: Int? = nil,
        caseLevel: Int? = nil,
        single: Int? = nil,
        productID: Int? = nil
    ) {
        self.name = name
        self.left = ReportedBattery.level(left)
        self.right = ReportedBattery.level(right)
        self.caseLevel = ReportedBattery.level(caseLevel)
        self.single = ReportedBattery.level(single)
        self.productID = (productID == 0) ? nil : productID
    }

    /// How many of left, right, case, and single are actually reporting.
    public var reportedPartCount: Int {
        [left, right, caseLevel, single].compactMap { $0 }.count
    }

    public var hasReading: Bool {
        reportedPartCount > 0
    }

    public var description: String {
        let parts = [
            "productID: \(Self.describeProductID(productID))",
            "left: \(Self.describe(left))",
            "right: \(Self.describe(right))",
            "case: \(Self.describe(caseLevel))",
            "single: \(Self.describe(single))",
        ].joined(separator: ", ")
        return "AirPodsBattery(name: \(name), \(parts))"
    }

    private static func describe(_ level: Int?) -> String {
        level.map(String.init) ?? "nil"
    }

    private static func describeProductID(_ productID: Int?) -> String {
        guard let productID else { return "nil" }
        return String(format: "0x%04X", productID)
    }
}

enum ReportedBattery {
    /// Levels outside 1...100, including 0 and missing, are not a reading.
    static func level(_ raw: Int?) -> Int? {
        guard let raw, (1...100).contains(raw) else { return nil }
        return raw
    }
}

/// First value in `rawValues` that is a real percent. Zero and missing are skipped.
func firstReportedLevel(_ rawValues: Int?...) -> Int? {
    for raw in rawValues {
        if let level = ReportedBattery.level(raw) {
            return level
        }
    }
    return nil
}
