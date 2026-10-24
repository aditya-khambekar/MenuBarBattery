import XCTest
@testable import AirPodsBattery

/// Stand-in for IOBluetoothDevice. The suite calls this object, never a radio.
private final class SelectorStub: NSObject {
    @objc func batteryPercentLeft() -> UInt8 { 200 }
    @objc func batteryPercentRight() -> Int { 81 }
    @objc func batteryPercentCase() -> Int32 { 0 }
    @objc func vendorID() -> UInt16 { 0x004C }
}

final class PrimitiveSelectorCallerTests: XCTestCase {
    private let caller = ObjCMethodImplementationCaller()

    func testUnsignedCharAndIntegerGetters() {
        let device = SelectorStub()
        XCTAssertEqual(caller.integerValue(of: device, selector: "batteryPercentLeft"), 200)
        XCTAssertEqual(caller.integerValue(of: device, selector: "batteryPercentRight"), 81)
        XCTAssertEqual(caller.integerValue(of: device, selector: "batteryPercentCase"), 0)
        XCTAssertEqual(caller.integerValue(of: device, selector: "vendorID"), 0x004C)
    }

    func testMissingSelectorReturnsNil() {
        let device = SelectorStub()
        XCTAssertNil(caller.integerValue(of: device, selector: "batteryPercentSingle"))
        XCTAssertNil(caller.integerValue(of: device, selector: "noSuchGetter"))
    }

    func testReturnTypeEncoding() {
        XCTAssertEqual(ObjCMethodImplementationCaller.returnType(in: "C16@0:8"), "C")
        XCTAssertEqual(ObjCMethodImplementationCaller.returnType(in: "S16@0:8"), "S")
        XCTAssertEqual(ObjCMethodImplementationCaller.returnType(in: "q16@0:8"), "q")
        XCTAssertEqual(ObjCMethodImplementationCaller.returnType(in: "rC16@0:8"), "C")
        XCTAssertNil(ObjCMethodImplementationCaller.returnType(in: ""))
    }
}
