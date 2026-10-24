import XCTest
@testable import AirPodsBattery

final class AirPodsSelectorTests: XCTestCase {
    func testOutputDeviceNameWinsOverFullerReading() throws {
        let office = try selectedFixture("two-sets.json", outputDeviceName: "Office AirPods")
        XCTAssertEqual(
            office,
            AirPodsBattery(name: "Office AirPods", left: 40, right: 40, caseLevel: nil, single: nil)
        )
        XCTAssertEqual(office.reportedPartCount, 2)
    }

    func testStraightApostropheMatchesCurlyDeviceName() throws {
        let pro = try selectedFixture("two-sets.json", outputDeviceName: "Name's AirPods Pro")
        XCTAssertEqual(pro.name, "Name’s AirPods Pro")
        XCTAssertEqual(pro.left, 90)
        XCTAssertEqual(pro.right, 80)
        XCTAssertEqual(pro.caseLevel, 70)
    }

    func testFullerReadingWinsWithoutOutputName() throws {
        let battery = try selectedFixture("two-sets.json")
        XCTAssertEqual(battery.name, "Name’s AirPods Pro")
        XCTAssertEqual(battery.reportedPartCount, 3)
    }

    func testUnrelatedOutputNameFallsThroughToFullerReading() throws {
        let battery = try selectedFixture("two-sets.json", outputDeviceName: "MacBook Speakers")
        XCTAssertEqual(battery.name, "Name’s AirPods Pro")
    }

    func testChoosePrefersOutputNameInsideOwnedAudioDevice() {
        let office = AirPodsBattery(name: "Office AirPods", left: 10, right: 10, caseLevel: 10)
        let pro = AirPodsBattery(name: "AirPods Pro", left: 89, right: 81)
        let chosen = chooseAirPodsBattery(
            from: [office, pro],
            outputDeviceName: "Ada’s AirPods Pro"
        )
        XCTAssertEqual(chosen, pro)
        let fullest = chooseAirPodsBattery(from: [office, pro], outputDeviceName: nil)
        XCTAssertEqual(fullest, office)
    }

    func testChoosePrefersClosestNameWhenSeveralContainTheOutput() {
        let pro = AirPodsBattery(name: "Ada’s AirPods Pro", left: 90)
        let max = AirPodsBattery(name: "Ada’s AirPods Pro Max", left: 1, right: 2, caseLevel: 3, single: 4)
        let byShortName = chooseAirPodsBattery(from: [max, pro], outputDeviceName: "AirPods Pro")
        XCTAssertEqual(byShortName, pro)
        let byFullName = chooseAirPodsBattery(from: [pro, max], outputDeviceName: "Ada’s AirPods Pro Max")
        XCTAssertEqual(byFullName, max)
    }

    func testBluetoothLevelsShortCircuitAndIgnoreProfilerJSON() throws {
        let snapshot = makeSnapshot(left: 11, right: 22, caseLevel: 33, single: 0)
        let garbage = Data("not-json".utf8)
        let battery = selectAirPodsBattery(
            snapshots: [snapshot],
            profilerJSON: garbage,
            outputDeviceName: nil
        )
        XCTAssertEqual(
            battery,
            AirPodsBattery(name: "AirPods Pro", left: 11, right: 22, caseLevel: 33, single: nil)
        )

        let withoutJSON = selectAirPodsBattery(snapshots: [snapshot], profilerJSON: nil)
        XCTAssertEqual(withoutJSON, battery)
    }

    func testCompleteBluetoothReadingWinsOverDifferentProfilerReading() throws {
        let snapshot = makeSnapshot(left: 11, right: 22, caseLevel: 33, single: 0)
        let battery = selectAirPodsBattery(
            snapshots: [snapshot],
            profilerJSON: try Fixture.data("classic-connected.json"),
            outputDeviceName: nil
        )
        XCTAssertEqual(
            battery,
            AirPodsBattery(name: "AirPods Pro", left: 11, right: 22, caseLevel: 33, single: nil)
        )
    }

    func testBluetoothBudsWithoutCaseLoseToCompleteProfilerReading() throws {
        let snapshot = makeSnapshot(left: 90, right: 80, caseLevel: 0, single: 0)
        let battery = selectAirPodsBattery(
            snapshots: [snapshot],
            profilerJSON: try Fixture.data("classic-connected.json"),
            outputDeviceName: nil
        )
        XCTAssertEqual(
            battery,
            AirPodsBattery(name: "Name’s AirPods Pro", left: 85, right: 80, caseLevel: 62, single: nil)
        )
    }

    func testBothSourcesMissingCaseKeepsBluetoothBuds() throws {
        let snapshot = makeSnapshot(left: 90, right: 80, caseLevel: 0, single: 0)
        let battery = selectAirPodsBattery(
            snapshots: [snapshot],
            profilerJSON: try Fixture.data("left-right-no-case.json"),
            outputDeviceName: nil
        )
        XCTAssertEqual(
            battery,
            AirPodsBattery(name: "AirPods Pro", left: 90, right: 80, caseLevel: nil, single: nil)
        )
    }

    func testBluetoothSingleIsCompleteWithoutBudsOrCase() throws {
        let snapshot = makeSnapshot(
            name: "AirPods Max",
            left: 0,
            right: 0,
            caseLevel: 0,
            single: 64
        )
        let battery = selectAirPodsBattery(
            snapshots: [snapshot],
            profilerJSON: try Fixture.data("classic-connected.json"),
            outputDeviceName: nil
        )
        XCTAssertEqual(
            battery,
            AirPodsBattery(name: "AirPods Max", left: nil, right: nil, caseLevel: nil, single: 64)
        )
    }

    func testIncompleteBluetoothBudsLoseToProfilerSingle() throws {
        let snapshot = makeSnapshot(left: 90, right: 80, caseLevel: 0, single: 0)
        let battery = selectAirPodsBattery(
            snapshots: [snapshot],
            profilerJSON: try Fixture.data("airpods-max.json"),
            outputDeviceName: nil
        )
        XCTAssertEqual(
            battery,
            AirPodsBattery(name: "Name’s AirPods Max", left: nil, right: nil, caseLevel: nil, single: 64)
        )
    }

    func testAllZeroBluetoothSnapshotFallsThroughToProfiler() throws {
        let snapshot = makeSnapshot(left: 0, right: 0, caseLevel: 0, single: 0)
        let battery = selectAirPodsBattery(
            snapshots: [snapshot],
            profilerJSON: try Fixture.data("classic-connected.json"),
            outputDeviceName: nil
        )
        XCTAssertEqual(
            battery,
            AirPodsBattery(name: "Name’s AirPods Pro", left: 85, right: 80, caseLevel: 62, single: nil)
        )
    }

    func testDisconnectedBluetoothDeviceFallsThroughToProfiler() throws {
        let snapshot = makeSnapshot(isConnected: false, left: 99, right: 98, caseLevel: 97)
        let battery = selectAirPodsBattery(
            snapshots: [snapshot],
            profilerJSON: try Fixture.data("classic-connected.json")
        )
        XCTAssertEqual(battery?.name, "Name’s AirPods Pro")
        XCTAssertEqual(battery?.left, 85)
    }

    func testKeyboardSnapshotIsIgnored() {
        let keyboard = makeSnapshot(name: "Magic Keyboard", isHeadphones: false, left: 55)
        XCTAssertNil(selectAirPodsBattery(snapshots: [keyboard], profilerJSON: nil))
    }

    func testAppleHeadphonesSnapshotWithSingleLevelQualifies() {
        let beats = makeSnapshot(name: "Beats Solo", left: 0, right: 0, caseLevel: 0, single: 44)
        let battery = selectAirPodsBattery(snapshots: [beats], profilerJSON: nil)
        XCTAssertEqual(battery?.name, "Beats Solo")
        XCTAssertEqual(battery?.single, 44)
        XCTAssertNil(battery?.left)
    }

    func testReaderSkipsProfilerWhenBluetoothHasLevels() {
        var profilerCalled = false
        let reader = AirPodsBatteryReader(
            loadSnapshots: { [makeSnapshot(left: 91, right: 81, caseLevel: 70)] },
            loadProfilerJSON: {
                profilerCalled = true
                return nil
            },
            loadOutputDeviceName: { nil }
        )
        let battery = reader.currentBattery()
        XCTAssertEqual(battery?.left, 91)
        XCTAssertEqual(battery?.right, 81)
        XCTAssertEqual(battery?.caseLevel, 70)
        XCTAssertFalse(profilerCalled)
    }

    func testReaderSkipsProfilerWhenBluetoothReportsSingle() {
        var profilerCalled = false
        let reader = AirPodsBatteryReader(
            loadSnapshots: {
                [makeSnapshot(name: "AirPods Max", left: 0, right: 0, caseLevel: 0, single: 64)]
            },
            loadProfilerJSON: {
                profilerCalled = true
                return nil
            },
            loadOutputDeviceName: { nil }
        )
        let battery = reader.currentBattery()
        XCTAssertEqual(battery?.single, 64)
        XCTAssertNil(battery?.left)
        XCTAssertFalse(profilerCalled)
    }

    func testReaderUsesProfilerWhenBluetoothBudsLackACase() throws {
        var profilerCalled = false
        let profiler = try Fixture.data("classic-connected.json")
        let reader = AirPodsBatteryReader(
            loadSnapshots: { [makeSnapshot(left: 90, right: 80, caseLevel: 0, single: 0)] },
            loadProfilerJSON: {
                profilerCalled = true
                return profiler
            },
            loadOutputDeviceName: { nil }
        )
        let battery = reader.currentBattery()
        XCTAssertTrue(profilerCalled)
        XCTAssertEqual(
            battery,
            AirPodsBattery(name: "Name’s AirPods Pro", left: 85, right: 80, caseLevel: 62, single: nil)
        )
    }

    func testReaderKeepsBluetoothBudsWhenProfilerAlsoLacksACase() throws {
        let profiler = try Fixture.data("left-right-no-case.json")
        let reader = AirPodsBatteryReader(
            loadSnapshots: { [makeSnapshot(left: 90, right: 80, caseLevel: 0, single: 0)] },
            loadProfilerJSON: { profiler },
            loadOutputDeviceName: { nil }
        )
        let battery = reader.currentBattery()
        XCTAssertEqual(
            battery,
            AirPodsBattery(name: "AirPods Pro", left: 90, right: 80, caseLevel: nil, single: nil)
        )
    }

    func testReaderUsesProfilerWhenBluetoothIsAllZeros() throws {
        var profilerCalled = false
        let profiler = try Fixture.data("classic-connected.json")
        let reader = AirPodsBatteryReader(
            loadSnapshots: { [makeSnapshot(left: 0, right: 0, caseLevel: 0, single: 0)] },
            loadProfilerJSON: {
                profilerCalled = true
                return profiler
            },
            loadOutputDeviceName: { nil }
        )
        let battery = reader.currentBattery()
        XCTAssertTrue(profilerCalled)
        XCTAssertEqual(battery?.left, 85)
        XCTAssertEqual(battery?.caseLevel, 62)
    }

    func testReaderUsesProfilerWhenSnapshotsAreEmpty() throws {
        var profilerCalled = false
        let profiler = try Fixture.data("airpods-max.json")
        let reader = AirPodsBatteryReader(
            loadSnapshots: { [] },
            loadProfilerJSON: {
                profilerCalled = true
                return profiler
            },
            loadOutputDeviceName: { "Name's AirPods Max" }
        )
        let battery = reader.currentBattery()
        XCTAssertTrue(profilerCalled)
        XCTAssertEqual(battery?.single, 64)
        XCTAssertEqual(battery?.name, "Name’s AirPods Max")
    }
}
