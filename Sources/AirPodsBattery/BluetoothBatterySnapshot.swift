import Foundation

/// Hardware-free snapshot of one Bluetooth device.
///
/// Live IOBluetooth objects stay behind ``IOBluetoothBatterySource``. Tests and
/// ``selectAirPodsBattery(snapshots:profilerJSON:outputDeviceName:)`` only see this value.
public struct BluetoothBatterySnapshot: Equatable, Sendable {
    public static let appleVendorID = 0x004C

    public let name: String
    public let isConnected: Bool
    /// Bluetooth company ID. Apple audio devices use `0x004C`.
    public let vendorID: Int?
    /// USB product ID. AirPods Pro on this Mac report `0x2024`. `0` is kept raw.
    public let productID: Int?
    public let isHeadphones: Bool
    /// True when the process actually has the private battery selectors.
    public let exposesBatterySelectors: Bool
    /// Raw getter results. `0` is preserved here and becomes `nil` on ``AirPodsBattery``.
    public let left: Int?
    public let right: Int?
    public let caseLevel: Int?
    public let single: Int?

    public init(
        name: String,
        isConnected: Bool,
        vendorID: Int?,
        productID: Int? = nil,
        isHeadphones: Bool,
        exposesBatterySelectors: Bool,
        left: Int?,
        right: Int?,
        caseLevel: Int?,
        single: Int?
    ) {
        self.name = name
        self.isConnected = isConnected
        self.vendorID = vendorID
        self.productID = productID
        self.isHeadphones = isHeadphones
        self.exposesBatterySelectors = exposesBatterySelectors
        self.left = left
        self.right = right
        self.caseLevel = caseLevel
        self.single = single
    }
}
