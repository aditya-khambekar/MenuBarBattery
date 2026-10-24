import Foundation

/// Live AirPods battery read.
///
/// Asks IOBluetooth first. `system_profiler` runs when that reading is not
/// complete (left, right, and case, or a single headset level).
public struct AirPodsBatteryReader {
    public let loadSnapshots: () -> [BluetoothBatterySnapshot]
    public let loadProfilerJSON: () -> Data?
    public let loadOutputDeviceName: () -> String?

    public init(
        loadSnapshots: @escaping () -> [BluetoothBatterySnapshot],
        loadProfilerJSON: @escaping () -> Data?,
        loadOutputDeviceName: @escaping () -> String?
    ) {
        self.loadSnapshots = loadSnapshots
        self.loadProfilerJSON = loadProfilerJSON
        self.loadOutputDeviceName = loadOutputDeviceName
    }

    /// Reader wired to IOBluetooth, then `system_profiler`.
    ///
    /// Pass `outputDeviceName` to skip the Core Audio lookup. `nil` uses the
    /// current default output device so two connected sets follow what is playing.
    public static func live(outputDeviceName: String? = nil) -> AirPodsBatteryReader {
        AirPodsBatteryReader(
            loadSnapshots: { IOBluetoothBatterySource.snapshots() },
            loadProfilerJSON: { SystemProfilerProcess.bluetoothData() },
            loadOutputDeviceName: { outputDeviceName ?? DefaultAudioOutput.name() }
        )
    }

    public func currentBattery() -> AirPodsBattery? {
        let outputName = loadOutputDeviceName()
        let snapshots = loadSnapshots()
        if let battery = selectAirPodsBattery(
            snapshots: snapshots,
            profilerJSON: nil,
            outputDeviceName: outputName
        ), isCompleteAirPodsReading(battery) {
            return battery
        }
        return selectAirPodsBattery(
            snapshots: snapshots,
            profilerJSON: loadProfilerJSON(),
            outputDeviceName: outputName
        )
    }

    public static func connectedAirPods(outputDeviceName: String? = nil) -> AirPodsBattery? {
        live(outputDeviceName: outputDeviceName).currentBattery()
    }
}
