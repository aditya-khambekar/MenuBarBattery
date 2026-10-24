import XCTest
@testable import AirPodsBattery

final class SystemProfilerParserTests: XCTestCase {
    func testClassicConnectedPercents() throws {
        let battery = try selectedFixture("classic-connected.json")
        XCTAssertEqual(
            battery,
            AirPodsBattery(name: "Name’s AirPods Pro", left: 85, right: 80, caseLevel: 62, single: nil)
        )
    }

    func testStringAndDataParsersMatch() throws {
        let data = try Fixture.data("classic-connected.json")
        let text = try Fixture.string("classic-connected.json")
        XCTAssertEqual(
            SystemProfilerBluetoothParser.candidates(from: data),
            SystemProfilerBluetoothParser.candidates(from: text)
        )
    }

    func testLiveConnectedShape() throws {
        let parsed = try profilerCandidates("live-connected.json")
        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(
            parsed[0],
            AirPodsBattery(
                name: "Studio AirPods Pro",
                left: 90,
                right: 82,
                caseLevel: 72,
                single: nil,
                productID: 0x2024
            )
        )
    }

    func testIntegerPercentFields() throws {
        let battery = try selectedFixture("integer-percents.json")
        XCTAssertEqual(
            battery,
            AirPodsBattery(name: "Name’s AirPods Pro", left: 85, right: 80, caseLevel: 62, single: nil)
        )
    }

    func testCaseZeroPercentStringBecomesNil() throws {
        let battery = try selectedFixture("case-zero-string.json")
        XCTAssertEqual(battery.left, 70)
        XCTAssertEqual(battery.right, 65)
        XCTAssertNil(battery.caseLevel)
        XCTAssertNil(battery.single)
    }

    func testCaseZeroIntegerBecomesNil() throws {
        let battery = try selectedFixture("case-zero-integer.json")
        XCTAssertEqual(battery.left, 70)
        XCTAssertEqual(battery.right, 65)
        XCTAssertNil(battery.caseLevel)
    }

    func testCaseOnlyZeroDoesNotReportZeroPercent() throws {
        let parsed = try profilerCandidates("case-only-zero.json")
        XCTAssertEqual(parsed.count, 1)
        XCTAssertNil(parsed[0].caseLevel)
        XCTAssertFalse(parsed[0].hasReading)
        XCTAssertNil(selectAirPodsBattery(profilerJSON: try Fixture.data("case-only-zero.json")))
    }

    func testBudZeroPercentStringBecomesNil() throws {
        let battery = try selectedFixture("bud-zero.json")
        XCTAssertNil(battery.left)
        XCTAssertEqual(battery.right, 66)
        XCTAssertEqual(battery.caseLevel, 40)
    }

    func testBudZeroIntegerBecomesNil() throws {
        let battery = try selectedFixture("bud-zero-integer.json")
        XCTAssertNil(battery.left)
        XCTAssertEqual(battery.right, 66)
        XCTAssertEqual(battery.caseLevel, 40)
    }

    func testLeftAndRightWithCaseAbsent() throws {
        let battery = try selectedFixture("left-right-no-case.json")
        XCTAssertEqual(battery.left, 70)
        XCTAssertEqual(battery.right, 65)
        XCTAssertNil(battery.caseLevel)
        XCTAssertNil(battery.single)
        XCTAssertEqual(battery.reportedPartCount, 2)
    }

    func testAirPodsMaxSingleBattery() throws {
        let battery = try selectedFixture("airpods-max.json")
        XCTAssertEqual(battery.name, "Name’s AirPods Max")
        XCTAssertNil(battery.left)
        XCTAssertNil(battery.right)
        XCTAssertNil(battery.caseLevel)
        XCTAssertEqual(battery.single, 64)
    }

    func testCombinedLevelAndMinorClassOfDevice() throws {
        let battery = try selectedFixture("airpods-max-combined.json")
        XCTAssertEqual(battery.single, 64)
        XCTAssertNil(battery.caseLevel)
        XCTAssertNil(battery.left)
        XCTAssertNil(battery.right)
    }

    func testSingleLevelWinsOverCombined() {
        let json = """
        {
          "SPBluetoothDataType": [
            {
              "device_connected": [
                {
                  "Name’s AirPods Max": {
                    "device_batteryLevelSingle": "70%",
                    "device_batteryLevelCombined": "10%"
                  }
                }
              ]
            }
          ]
        }
        """
        let battery = SystemProfilerBluetoothParser.candidates(from: json).first
        XCTAssertEqual(battery?.single, 70)
    }

    func testZeroSingleFallsThroughToCombined() {
        let json = """
        {
          "SPBluetoothDataType": [
            {
              "device_connected": [
                {
                  "Name’s AirPods Max": {
                    "device_batteryLevelSingle": 0,
                    "device_batteryLevelCombined": "64%"
                  }
                }
              ]
            }
          ]
        }
        """
        XCTAssertEqual(SystemProfilerBluetoothParser.candidates(from: json).first?.single, 64)
    }

    func testSpacedAndBarePercentStrings() {
        let json = """
        {
          "SPBluetoothDataType": [
            {
              "device_connected": [
                {
                  "Name’s AirPods Pro": {
                    "device_batteryLevelLeft": "85 %",
                    "device_batteryLevelRight": "80",
                    "device_batteryLevelCase": " 62% "
                  }
                }
              ]
            }
          ]
        }
        """
        let battery = SystemProfilerBluetoothParser.candidates(from: json).first
        XCTAssertEqual(battery?.left, 85)
        XCTAssertEqual(battery?.right, 80)
        XCTAssertEqual(battery?.caseLevel, 62)
    }

    func testOutOfRangePercentsBecomeNil() {
        let json = """
        {
          "SPBluetoothDataType": [
            {
              "device_connected": [
                {
                  "Name’s AirPods Pro": {
                    "device_batteryLevelLeft": "101%",
                    "device_batteryLevelRight": -1,
                    "device_batteryLevelCase": "50%"
                  }
                }
              ]
            }
          ]
        }
        """
        let battery = SystemProfilerBluetoothParser.candidates(from: json).first
        XCTAssertNil(battery?.left)
        XCTAssertNil(battery?.right)
        XCTAssertEqual(battery?.caseLevel, 50)
    }

    func testNotConnectedAirPodsAreIgnored() throws {
        XCTAssertTrue(try profilerCandidates("not-connected.json").isEmpty)
        XCTAssertNil(selectAirPodsBattery(profilerJSON: try Fixture.data("not-connected.json")))
    }

    func testKeyboardIsIgnoredEvenWithBatteryKeys() throws {
        XCTAssertTrue(try profilerCandidates("keyboard.json").isEmpty)
        XCTAssertNil(selectAirPodsBattery(profilerJSON: try Fixture.data("keyboard.json")))
    }

    func testAppleHeadphonesWithALevelQualifyAndOtherHeadphonesDoNot() throws {
        let parsed = try profilerCandidates("other-headphones.json")
        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(
            parsed[0],
            AirPodsBattery(name: "Beats Solo", left: nil, right: nil, caseLevel: nil, single: 44)
        )
    }

    func testDictionaryConnectedShape() throws {
        let battery = try selectedFixture("dictionary-connected.json")
        XCTAssertEqual(
            battery,
            AirPodsBattery(name: "Name’s AirPods Pro", left: 85, right: 80, caseLevel: 62, single: nil)
        )
    }

    func testPropertyBagConnectedShape() throws {
        let battery = try selectedFixture("property-bag.json")
        XCTAssertEqual(
            battery,
            AirPodsBattery(name: "Name’s AirPods Pro", left: 85, right: 80, caseLevel: 62, single: nil)
        )
    }

    func testFlatConnectedShapeIgnoresDisconnectedEntry() throws {
        let parsed = try profilerCandidates("flat-connected.json")
        XCTAssertEqual(parsed.count, 1)
        XCTAssertEqual(
            parsed[0],
            AirPodsBattery(name: "Name’s AirPods Pro", left: 85, right: 80, caseLevel: 62, single: nil)
        )
    }

    func testEmptyMalformedAndNoDevicesReturnNil() throws {
        for name in ["empty.json", "malformed.json", "no-devices.json"] {
            XCTAssertTrue(try profilerCandidates(name).isEmpty, name)
            XCTAssertNil(selectAirPodsBattery(profilerJSON: try Fixture.data(name)), name)
        }
        XCTAssertNil(selectAirPodsBattery(profilerJSON: Data()))
        XCTAssertNil(selectAirPodsBattery(profilerJSON: nil))
    }

    func testZeroAndMissingAreNilOnTheModel() {
        let silent = AirPodsBattery(name: "AirPods", left: 0, right: nil, caseLevel: 0, single: 0)
        XCTAssertNil(silent.left)
        XCTAssertNil(silent.right)
        XCTAssertNil(silent.caseLevel)
        XCTAssertNil(silent.single)
        XCTAssertFalse(silent.hasReading)

        let full = AirPodsBattery(name: "AirPods", left: 100, right: 1, caseLevel: nil, single: nil)
        XCTAssertEqual(full.left, 100)
        XCTAssertEqual(full.right, 1)
        XCTAssertEqual(full.reportedPartCount, 2)
    }
}
