import XCTest
@testable import AirPodsBattery

final class LiveAirPodsBatteryTests: XCTestCase {
    /// Runs against this Mac. Skips when system_profiler or a connected AirPods set is absent,
    /// so `swift test` still passes with nothing paired.
    func testLiveFetchWhenAirPodsAreConnected() throws {
        let profilerData = SystemProfilerProcess.bluetoothData()
        try XCTSkipIf(profilerData == nil, "system_profiler did not return Bluetooth JSON")
        let profilerReading = SystemProfilerBluetoothParser.candidates(from: profilerData ?? Data())
            .contains(where: \.hasReading)
        try XCTSkipIf(!profilerReading, "No connected AirPods in system_profiler output")

        let snapshots = IOBluetoothBatterySource.snapshots()
        let fromBluetooth = selectAirPodsBattery(snapshots: snapshots, profilerJSON: nil)
        let live = try XCTUnwrap(AirPodsBatteryReader.connectedAirPods())
        XCTAssertTrue(live.hasReading)
        XCTAssertNotNil(live.name.range(of: "airpods", options: .caseInsensitive))
        // Names differ between IOBluetooth and system_profiler, so a matching name
        // means the live read stopped on the Bluetooth snapshots. Percents are not
        // compared: a bud can tick between the two reads.
        if let fromBluetooth, fromBluetooth.hasReading {
            XCTAssertTrue(snapshots.contains(where: \.exposesBatterySelectors))
            XCTAssertEqual(live.name, fromBluetooth.name)
            XCTAssertEqual(live.reportedPartCount, fromBluetooth.reportedPartCount)
        }
    }
}
