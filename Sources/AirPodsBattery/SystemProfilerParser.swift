import Foundation

/// Pure parser for `system_profiler SPBluetoothDataType -json`.
///
/// Accepts the classic `device_connected` array (also the shape this Mac returns),
/// a dictionary keyed by device name, a property bag with `device_name`, and the
/// older flat entry whose `device_connected` value is `"Yes"` / `"attrib_Yes"`.
/// Only the connected list is read. Percent fields may be `"85%"` or an integer.
/// `0` and `"0%"` become `nil`.
public enum SystemProfilerBluetoothParser {
    public static func candidates(from json: Data) -> [AirPodsBattery] {
        guard !json.isEmpty,
              let root = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
              let entries = root["SPBluetoothDataType"] as? [Any] else {
            return []
        }
        var batteries: [AirPodsBattery] = []
        for entry in entries {
            guard let dict = entry as? [String: Any] else { continue }
            for device in connectedDevices(in: dict) {
                if let battery = candidate(name: device.name, properties: device.properties) {
                    batteries.append(battery)
                }
            }
        }
        return batteries
    }

    public static func candidates(from json: String) -> [AirPodsBattery] {
        guard let data = json.data(using: .utf8) else { return [] }
        return candidates(from: data)
    }
}

private struct ProfilerDevice {
    let name: String
    let properties: [String: Any]
}

private let profilerPropertyKeys: Set<String> = [
    "device_address",
    "device_name",
    "device_title",
    "name",
    "device_minorType",
    "device_minorClassOfDevice",
    "device_vendorID",
    "device_productID",
    "device_batteryLevelLeft",
    "device_batteryLevelRight",
    "device_batteryLevelCase",
    "device_batteryLevelSingle",
    "device_batteryLevelCombined",
    "device_batteryLevel",
    "device_firmwareVersion",
    "device_connected",
    "device_isconnected",
]

private func connectedDevices(in entry: [String: Any]) -> [ProfilerDevice] {
    guard let connected = entry["device_connected"] else { return [] }
    if let flag = connected as? String {
        guard isConnectedFlag(flag), let device = flatDevice(entry) else { return [] }
        return [device]
    }
    return unwrapDeviceCollection(connected)
}

private func unwrapDeviceCollection(_ value: Any) -> [ProfilerDevice] {
    if let array = value as? [Any] {
        return array.flatMap { item -> [ProfilerDevice] in
            guard let dict = item as? [String: Any] else { return [] }
            return unwrapDeviceDictionary(dict)
        }
    }
    if let dict = value as? [String: Any] {
        return unwrapDeviceDictionary(dict)
    }
    return []
}

private func unwrapDeviceDictionary(_ dict: [String: Any]) -> [ProfilerDevice] {
    if isPropertyBag(dict) {
        return flatDevice(dict).map { [$0] } ?? []
    }
    var devices: [ProfilerDevice] = []
    for (key, value) in dict {
        guard let properties = value as? [String: Any], !key.isEmpty else { continue }
        devices.append(ProfilerDevice(name: key, properties: properties))
    }
    return devices
}

private func flatDevice(_ dict: [String: Any]) -> ProfilerDevice? {
    let name = stringValue(dict["device_title"])
        ?? stringValue(dict["device_name"])
        ?? stringValue(dict["name"])
    guard let name, !name.isEmpty else { return nil }
    return ProfilerDevice(name: name, properties: dict)
}

private func isPropertyBag(_ dict: [String: Any]) -> Bool {
    dict.keys.contains { profilerPropertyKeys.contains($0) }
}

private func isConnectedFlag(_ value: String) -> Bool {
    switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "yes", "attrib_yes", "true", "1":
        return true
    default:
        return false
    }
}

private func candidate(name: String, properties: [String: Any]) -> AirPodsBattery? {
    let battery = AirPodsBattery(
        name: name,
        left: parsePercent(properties["device_batteryLevelLeft"]),
        right: parsePercent(properties["device_batteryLevelRight"]),
        caseLevel: parsePercent(properties["device_batteryLevelCase"]),
        single: firstReportedLevel(
            parsePercent(properties["device_batteryLevelSingle"]),
            parsePercent(properties["device_batteryLevelCombined"])
        )
    )
    if name.range(of: "airpods", options: .caseInsensitive) != nil {
        return battery
    }
    if isAppleVendor(properties["device_vendorID"]), isHeadphones(properties), battery.hasReading {
        return battery
    }
    return nil
}

private func parsePercent(_ value: Any?) -> Int? {
    if value == nil || value is NSNull { return nil }
    if let number = value as? NSNumber {
        if CFGetTypeID(number) == CFBooleanGetTypeID() { return nil }
        // Reject fractional percents instead of truncating them.
        let double = number.doubleValue
        guard double.rounded() == double, double >= Double(Int.min), double <= Double(Int.max) else {
            return nil
        }
        return ReportedBattery.level(Int(double))
    }
    if let text = value as? String {
        let stripped = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "%", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let raw = Int(stripped) else { return nil }
        return ReportedBattery.level(raw)
    }
    return nil
}

private func isAppleVendor(_ value: Any?) -> Bool {
    if let number = value as? NSNumber {
        if CFGetTypeID(number) == CFBooleanGetTypeID() { return false }
        return number.intValue == BluetoothBatterySnapshot.appleVendorID
    }
    guard let raw = value as? String else { return false }
    let text = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if text.contains("0x004c") || text == "76" || text == "apple" {
        return true
    }
    if text.hasPrefix("0x") {
        let hex = text.dropFirst(2).prefix { $0.isHexDigit }
        return Int(hex, radix: 16) == BluetoothBatterySnapshot.appleVendorID
    }
    return Int(text) == BluetoothBatterySnapshot.appleVendorID
}

private func isHeadphones(_ properties: [String: Any]) -> Bool {
    for key in ["device_minorType", "device_minorClassOfDevice"] {
        if let text = properties[key] as? String {
            let lower = text.lowercased()
            if lower.contains("headphone") || lower.contains("headset") || lower == "audio" {
                return true
            }
        }
        if let number = properties[key] as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() {
            let minor = number.intValue & 0x3F
            if minor == 0x01 || minor == 0x02 || minor == 0x06 || minor == 0x07 {
                return true
            }
        }
    }
    return false
}

private func stringValue(_ value: Any?) -> String? {
    guard let text = value as? String else { return nil }
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}
