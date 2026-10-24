import AppKit
import IOBluetooth
import AirPodsBattery

/// Polls ``AirPodsBatteryReader`` and asks again when the Mac wakes or Bluetooth changes.
///
/// A reading that did not need `system_profiler` is repeated about every 15 seconds.
/// A reading that had to run `system_profiler` waits about 60 seconds, because that
/// path is the slow one. Wake and connect or disconnect refresh immediately.
final class AirPodsMonitor: NSObject, @unchecked Sendable {
    var onUpdate: ((AirPodsBattery?) -> Void)?

    private var timer: Timer?
    private var inFlight = false
    private var queued = false
    private var usedProfiler = false
    private var connectNotification: IOBluetoothUserNotification?
    private var disconnectNotes: [String: IOBluetoothUserNotification] = [:]

    func start() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(self, selector: #selector(woke(_:)), name: NSWorkspace.didWakeNotification, object: nil)
        center.addObserver(self, selector: #selector(woke(_:)), name: NSWorkspace.screensDidWakeNotification, object: nil)
        connectNotification = IOBluetoothDevice.register(
            forConnectNotifications: self,
            selector: #selector(bluetoothConnected(_:device:))
        )
        let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []
        for device in paired where device.isConnected() {
            watchDisconnect(device)
        }
        refresh()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        connectNotification?.unregister()
        connectNotification = nil
        for note in disconnectNotes.values {
            note.unregister()
        }
        disconnectNotes.removeAll()
    }

    func refresh() {
        dispatchPrecondition(condition: .onQueue(.main))
        timer?.invalidate()
        timer = nil
        guard !inFlight else {
            queued = true
            return
        }
        inFlight = true
        let result = Self.fetch()
        inFlight = false
        usedProfiler = result.usedProfiler
        onUpdate?(result.battery)
        if queued {
            queued = false
            refresh()
            return
        }
        schedule()
    }

    /// Wraps the live reader so the caller can see whether `system_profiler` ran.
    static func fetch() -> (battery: AirPodsBattery?, usedProfiler: Bool) {
        let live = AirPodsBatteryReader.live()
        let flag = ProfilerFlag()
        let reader = AirPodsBatteryReader(
            loadSnapshots: live.loadSnapshots,
            loadProfilerJSON: {
                flag.used = true
                return live.loadProfilerJSON()
            },
            loadOutputDeviceName: live.loadOutputDeviceName
        )
        return (reader.currentBattery(), flag.used)
    }

    private func schedule() {
        let interval: TimeInterval = usedProfiler ? 60 : 15
        let timer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            self?.refresh()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func watchDisconnect(_ device: IOBluetoothDevice) {
        let address = device.addressString ?? ""
        guard !address.isEmpty, disconnectNotes[address] == nil else { return }
        guard let note = device.register(
            forDisconnectNotification: self,
            selector: #selector(bluetoothDisconnected(_:device:))
        ) else { return }
        disconnectNotes[address] = note
    }

    @objc private func woke(_ notification: Notification) {
        perform(#selector(refreshOnMain), on: Thread.main, with: nil, waitUntilDone: false)
    }

    @objc private func refreshOnMain() {
        refresh()
    }

    @objc private func bluetoothConnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        perform(#selector(connectOnMain(_:)), on: Thread.main, with: device, waitUntilDone: false)
    }

    @objc private func connectOnMain(_ device: IOBluetoothDevice) {
        watchDisconnect(device)
        refresh()
    }

    @objc private func bluetoothDisconnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        perform(#selector(disconnectOnMain(_:)), on: Thread.main, with: device, waitUntilDone: false)
    }

    @objc private func disconnectOnMain(_ device: IOBluetoothDevice) {
        if let address = device.addressString {
            disconnectNotes[address] = nil
        }
        refresh()
    }
}

/// Mutable flag captured by the profiler's non-Sendable loader.
private final class ProfilerFlag: @unchecked Sendable {
    var used = false
}
