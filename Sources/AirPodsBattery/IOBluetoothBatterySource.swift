import Foundation
import IOBluetooth

/// Reads connected devices through IOBluetooth's private battery getters.
///
/// Selectors are `batteryPercentLeft`, `batteryPercentRight`, `batteryPercentCase`,
/// and `batteryPercentSingle` (with `batteryPercentCombined` filling in when single
/// is missing or zero). They return `unsigned char`, so this goes through
/// ``PrimitiveSelectorCalling`` instead of `perform(_:)`. If those selectors are
/// not on the device class, the source is skipped and the caller uses system_profiler.
enum IOBluetoothBatterySource {
    static func snapshots(
        caller: PrimitiveSelectorCalling = ObjCMethodImplementationCaller()
    ) -> [BluetoothBatterySnapshot] {
        guard let devices = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
            return []
        }
        let leftSelector = NSSelectorFromString("batteryPercentLeft")
        guard devices.contains(where: { $0.responds(to: leftSelector) }) else {
            return []
        }
        return devices.compactMap { snapshot(of: $0, caller: caller) }
    }

    private static func snapshot(
        of device: IOBluetoothDevice,
        caller: PrimitiveSelectorCalling
    ) -> BluetoothBatterySnapshot? {
        guard device.isConnected() else { return nil }
        let name = device.name ?? device.nameOrAddress ?? ""
        guard !name.isEmpty else { return nil }
        let single = firstReportedLevel(
            caller.integerValue(of: device, selector: "batteryPercentSingle"),
            caller.integerValue(of: device, selector: "batteryPercentCombined")
        )
        return BluetoothBatterySnapshot(
            name: name,
            isConnected: true,
            vendorID: caller.integerValue(of: device, selector: "vendorID"),
            isHeadphones: isHeadphonesClass(major: device.deviceClassMajor, minor: device.deviceClassMinor),
            exposesBatterySelectors: true,
            left: caller.integerValue(of: device, selector: "batteryPercentLeft"),
            right: caller.integerValue(of: device, selector: "batteryPercentRight"),
            caseLevel: caller.integerValue(of: device, selector: "batteryPercentCase"),
            single: single
        )
    }

    /// Audio major class, and a headphones / headset / hands-free / portable minor class.
    private static func isHeadphonesClass(major: UInt32, minor: UInt32) -> Bool {
        guard major == 0x04 else { return false }
        switch minor & 0x3F {
        case 0x01, 0x02, 0x06, 0x07:
            return true
        default:
            return false
        }
    }
}
