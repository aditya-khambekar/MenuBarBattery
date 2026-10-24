import Foundation

/// Picks one connected AirPods reading.
///
/// Bluetooth snapshots win when any of them has a real level. All-zero snapshots
/// and an empty snapshot list fall through to `system_profiler` JSON. Devices that
/// are not connected, are not AirPods, and are not Apple headphones with a bud,
/// case, or single level are ignored.
public func selectAirPodsBattery(
    snapshots: [BluetoothBatterySnapshot] = [],
    profilerJSON: Data? = nil,
    outputDeviceName: String? = nil
) -> AirPodsBattery? {
    let fromBluetooth = snapshots.compactMap(bluetoothCandidate(from:))
    if let chosen = chooseAirPodsBattery(from: fromBluetooth, outputDeviceName: outputDeviceName) {
        return chosen
    }
    guard let profilerJSON else { return nil }
    let fromProfiler = SystemProfilerBluetoothParser.candidates(from: profilerJSON)
    return chooseAirPodsBattery(from: fromProfiler, outputDeviceName: outputDeviceName)
}

/// Chooses among AirPods candidates that report at least one level.
///
/// A current output-device name wins when it matches one candidate (apostrophes
/// and spacing ignored, and a shorter Bluetooth name may sit inside the audio
/// device name). With no match, the candidate reporting the most parts wins.
public func chooseAirPodsBattery(
    from candidates: [AirPodsBattery],
    outputDeviceName: String? = nil
) -> AirPodsBattery? {
    let usable = candidates.filter(\.hasReading)
    guard !usable.isEmpty else { return nil }
    if let output = outputDeviceName?.trimmingCharacters(in: .whitespacesAndNewlines),
       !output.isEmpty,
       let matched = bestNameMatch(among: usable, output: output) {
        return matched
    }
    return fullest(usable)
}

private func bluetoothCandidate(from snapshot: BluetoothBatterySnapshot) -> AirPodsBattery? {
    guard snapshot.isConnected else { return nil }
    let battery = AirPodsBattery(
        name: snapshot.name,
        left: snapshot.left,
        right: snapshot.right,
        caseLevel: snapshot.caseLevel,
        single: snapshot.single
    )
    if snapshot.name.range(of: "airpods", options: .caseInsensitive) != nil {
        return battery
    }
    if snapshot.vendorID == BluetoothBatterySnapshot.appleVendorID,
       snapshot.isHeadphones,
       battery.hasReading {
        return battery
    }
    return nil
}

private func bestNameMatch(among candidates: [AirPodsBattery], output: String) -> AirPodsBattery? {
    let matched = candidates.filter { namesMatch(output: output, candidate: $0.name) }
    guard !matched.isEmpty else { return nil }
    if matched.count == 1 { return matched[0] }
    let normalizedOutput = normalizedDeviceName(output)
    return matched.min { lhs, rhs in
        let leftDistance = abs(normalizedDeviceName(lhs.name).count - normalizedOutput.count)
        let rightDistance = abs(normalizedDeviceName(rhs.name).count - normalizedOutput.count)
        if leftDistance != rightDistance { return leftDistance < rightDistance }
        if lhs.reportedPartCount != rhs.reportedPartCount {
            return lhs.reportedPartCount > rhs.reportedPartCount
        }
        return false
    }
}

private func fullest(_ candidates: [AirPodsBattery]) -> AirPodsBattery? {
    candidates.max { lhs, rhs in
        lhs.reportedPartCount < rhs.reportedPartCount
    }
}

func normalizedDeviceName(_ name: String) -> String {
    var text = name.lowercased()
    let apostrophes = ["’", "‘", "`", "ʼ", "´"]
    for apostrophe in apostrophes {
        text = text.replacingOccurrences(of: apostrophe, with: "'")
    }
    text = text.replacingOccurrences(of: "\u{00a0}", with: " ")
    return text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
}

func namesMatch(output: String, candidate: String) -> Bool {
    let outputName = normalizedDeviceName(output)
    let candidateName = normalizedDeviceName(candidate)
    guard !outputName.isEmpty, !candidateName.isEmpty else { return false }
    return outputName == candidateName
        || outputName.contains(candidateName)
        || candidateName.contains(outputName)
}
