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
        let combined = selectAirPodsBattery(snapshots: snapshots, profilerJSON: profilerData)
        let live = try XCTUnwrap(AirPodsBatteryReader.connectedAirPods())
        XCTAssertTrue(live.hasReading)
        XCTAssertNotNil(live.name.range(of: "airpods", options: .caseInsensitive))
        if let fromBluetooth, fromBluetooth.hasReading {
            XCTAssertTrue(snapshots.contains(where: \.exposesBatterySelectors))
        }
        // Percents can tick between the probe and the live read. Name, and whether
        // case or single is reporting, identify the source the selector kept.
        let expected = try XCTUnwrap(combined)
        XCTAssertEqual(live.name, expected.name)
        XCTAssertEqual(live.caseLevel == nil, expected.caseLevel == nil)
        XCTAssertEqual(live.single == nil, expected.single == nil)
    }
}
