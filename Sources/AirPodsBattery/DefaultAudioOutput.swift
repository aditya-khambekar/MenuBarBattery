import CoreAudio
import Foundation

enum DefaultAudioOutput {
    /// Name of the current default output device, used to pick among several AirPods sets.
    static func name() -> String? {
        let system = AudioObjectID(kAudioObjectSystemObject)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &deviceID) == noErr,
              deviceID != kAudioObjectUnknown else {
            return nil
        }

        address.mSelector = kAudioDevicePropertyDeviceNameCFString
        var rawName: Unmanaged<CFString>?
        size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &rawName) == noErr,
              let rawName else {
            return nil
        }
        return rawName.takeRetainedValue() as String
    }
}
