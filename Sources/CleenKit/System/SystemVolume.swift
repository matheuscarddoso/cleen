import AudioToolbox
import CoreAudio
import Foundation

/// The default output's volume and mute, through Core Audio. The level is the device's
/// "virtual main volume", the single knob the menu bar slider moves whatever the
/// device's channel layout. Core Audio is thread-safe and these calls are quick, so they
/// run straight from the media-key tap's thread.
public enum SystemVolume {
    public static func defaultOutput() -> AudioObjectID? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var device = AudioObjectID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device) == noErr,
              device != kAudioObjectUnknown
        else { return nil }
        return device
    }

    /// False for outputs whose volume lives elsewhere (most HDMI and some USB
    /// interfaces): their keys are left to macOS.
    public static func canSetVolume(_ device: AudioObjectID) -> Bool {
        var address = volumeAddress
        guard AudioObjectHasProperty(device, &address) else { return false }
        var settable: DarwinBoolean = false
        return AudioObjectIsPropertySettable(device, &address, &settable) == noErr && settable.boolValue
    }

    public static func canMute(_ device: AudioObjectID) -> Bool {
        var address = muteAddress
        guard AudioObjectHasProperty(device, &address) else { return false }
        var settable: DarwinBoolean = false
        return AudioObjectIsPropertySettable(device, &address, &settable) == noErr && settable.boolValue
    }

    public static func read(_ device: AudioObjectID) -> VolumeState? {
        var address = volumeAddress
        var level: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &level) == noErr else { return nil }
        var muteAddress = muteAddress
        var muted: UInt32 = 0
        size = UInt32(MemoryLayout<UInt32>.size)
        if AudioObjectGetPropertyData(device, &muteAddress, 0, nil, &size, &muted) != noErr { muted = 0 }
        return VolumeState(level: Double(level), isMuted: muted != 0)
    }

    /// Writes only what changed, so a mute toggle never nudges the level.
    @discardableResult
    public static func write(_ state: VolumeState, to device: AudioObjectID, from old: VolumeState) -> Bool {
        var succeeded = true
        if state.isMuted != old.isMuted, canMute(device) {
            var address = muteAddress
            var muted: UInt32 = state.isMuted ? 1 : 0
            succeeded = AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &muted) == noErr
        }
        if abs(state.level - old.level) > 0.0001 {
            var address = volumeAddress
            var level = Float32(min(1, max(0, state.level)))
            succeeded = AudioObjectSetPropertyData(device, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &level) == noErr && succeeded
        }
        return succeeded
    }

    private static var volumeAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private static var muteAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
    }
}
