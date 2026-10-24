import Foundation
import ObjectiveC

/// Reads an Objective-C method that returns a primitive integer.
///
/// `perform(_:)` boxes the result as an object and drops primitive returns, so the
/// live AirPods getters go through `method_getImplementation` and a `@convention(c)` call.
protocol PrimitiveSelectorCalling {
    func integerValue(of object: AnyObject, selector: String) -> Int?
}

struct ObjCMethodImplementationCaller: PrimitiveSelectorCalling {
    func integerValue(of object: AnyObject, selector name: String) -> Int? {
        guard let object = object as? NSObject else { return nil }
        let selector = NSSelectorFromString(name)
        guard object.responds(to: selector) else { return nil }
        guard let cls = object_getClass(object),
              let method = class_getInstanceMethod(cls, selector),
              let encodingC = method_getTypeEncoding(method) else {
            return nil
        }
        guard let returnType = Self.returnType(in: String(cString: encodingC)) else { return nil }
        return Self.invoke(
            method_getImplementation(method),
            object: object,
            selector: selector,
            returnType: returnType
        )
    }

    /// First character of an Objective-C type encoding, after type qualifiers.
    static func returnType(in encoding: String) -> Character? {
        let qualifiers: Set<Character> = ["r", "n", "N", "o", "O", "R", "V"]
        guard let first = encoding.first else { return nil }
        if qualifiers.contains(first) {
            return returnType(in: String(encoding.dropFirst()))
        }
        return first
    }

    static func invoke(
        _ implementation: IMP,
        object: AnyObject,
        selector: Selector,
        returnType: Character
    ) -> Int? {
        switch returnType {
        case "c":
            let function = unsafeBitCast(implementation, to: (@convention(c) (AnyObject, Selector) -> Int8).self)
            return Int(function(object, selector))
        case "C":
            let function = unsafeBitCast(implementation, to: (@convention(c) (AnyObject, Selector) -> UInt8).self)
            return Int(function(object, selector))
        case "s":
            let function = unsafeBitCast(implementation, to: (@convention(c) (AnyObject, Selector) -> Int16).self)
            return Int(function(object, selector))
        case "S":
            let function = unsafeBitCast(implementation, to: (@convention(c) (AnyObject, Selector) -> UInt16).self)
            return Int(function(object, selector))
        case "i":
            let function = unsafeBitCast(implementation, to: (@convention(c) (AnyObject, Selector) -> Int32).self)
            return Int(function(object, selector))
        case "I":
            let function = unsafeBitCast(implementation, to: (@convention(c) (AnyObject, Selector) -> UInt32).self)
            return Int(function(object, selector))
        case "q":
            let function = unsafeBitCast(implementation, to: (@convention(c) (AnyObject, Selector) -> Int64).self)
            return Int(function(object, selector))
        case "Q":
            let function = unsafeBitCast(implementation, to: (@convention(c) (AnyObject, Selector) -> UInt64).self)
            let value = function(object, selector)
            guard value <= UInt64(Int.max) else { return nil }
            return Int(value)
        default:
            // Missing or non-integer selectors are skipped. The Bluetooth source
            // then falls through to system_profiler.
            return nil
        }
    }
}
