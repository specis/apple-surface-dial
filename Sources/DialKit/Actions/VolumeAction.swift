// VolumeAction.swift
// Adjusts system volume via CoreAudio with a media-key fallback.
//
// Write strategy (tried in order):
//   1. kVirtualMainVolume ('virt') via AudioObjectSetPropertyData — works on most devices.
//   2. kAudioDevicePropertyVolumeScalar per-channel — works on USB / BT headsets.
//   3. NX_KEYTYPE_SOUND_UP/DOWN media key simulation — works on ALL devices including
//      Apple Silicon built-in audio (M1/M2/M3), which exposes no settable scalar property.
//
// Read strategy:
//   Same CoreAudio probes. When media-key fallback is used for writing, reads are best-effort;
//   if unavailable the reported percentage is estimated from accumulated steps.
//
// No special permissions required (media keys do not need Accessibility).

import AppKit
import CoreAudio
import Foundation

// MARK: - VolumeAction

/// Adjusts the default output device's volume in response to normalised rotation steps.
final class VolumeAction {

    /// Volume change per logical step, 0.0–1.0 scale. Default 0.05 = 5%.
    /// When falling back to media keys (6.25% per keypress), steps are rounded to
    /// the nearest whole number of keypresses.
    var stepSize: Float = 0.05

    /// Called after each change with the estimated new volume (0.0–1.0) and whether
    /// a boundary was hit. Wire to HapticEngine later.
    var onVolumeChanged: ((_ volume: Float, _ hitBoundary: Bool) -> Void)?

    // 'virt' — kAudioHardwareServiceDeviceProperty_VirtualMainVolume
    private let kVirtualMainVolume: AudioObjectPropertySelector = 0x76697274

    // Running estimate used when media keys are the only write path and CoreAudio
    // read also fails (so we have something plausible to report).
    private var estimatedVolume: Float = 0.5

    // MARK: - Public

    func adjust(steps: Int) {
        guard steps != 0, let deviceID = defaultOutputDevice() else { return }

        let current     = readVolume(for: deviceID) ?? estimatedVolume
        let raw         = current + Float(steps) * stepSize
        let clamped     = max(0.0, min(1.0, raw))
        let hitBoundary = raw != clamped
        estimatedVolume = clamped

        if !writeViaCoreAudio(clamped, for: deviceID) {
            writeViaMediaKeys(steps: steps)
        }
        onVolumeChanged?(clamped, hitBoundary)
    }

    // MARK: - Private — device lookup

    private func defaultOutputDevice() -> AudioDeviceID? {
        var deviceID = AudioDeviceID(0)
        var size     = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address  = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope:    kAudioObjectPropertyScopeGlobal,
            mElement:  kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
        return status == noErr ? deviceID : nil
    }

    // MARK: - Private — CoreAudio read

    /// Returns the current volume, or nil if no readable property was found.
    private func readVolume(for deviceID: AudioDeviceID) -> Float? {
        // Try virtual main volume.
        var address = AudioObjectPropertyAddress(
            mSelector: kVirtualMainVolume,
            mScope:    kAudioDevicePropertyScopeOutput,
            mElement:  kAudioObjectPropertyElementMain
        )
        if let v = readFloat(deviceID: deviceID, address: &address) { return v }

        // Try per-channel scalar on channels 0, 1, 2.
        address.mSelector = kAudioDevicePropertyVolumeScalar
        for ch: UInt32 in [0, 1, 2] {
            address.mElement = ch
            if let v = readFloat(deviceID: deviceID, address: &address) { return v }
        }
        return nil
    }

    private func readFloat(deviceID: AudioDeviceID,
                           address: inout AudioObjectPropertyAddress) -> Float? {
        guard AudioObjectHasProperty(deviceID, &address) else { return nil }
        var value: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectGetPropertyData(deviceID, &address, 0, nil, &size, &value) == noErr
        else { return nil }
        return value
    }

    // MARK: - Private — CoreAudio write

    /// Returns true if a property was found and set successfully.
    @discardableResult
    private func writeViaCoreAudio(_ volume: Float, for deviceID: AudioDeviceID) -> Bool {
        // Try virtual main volume.
        var address = AudioObjectPropertyAddress(
            mSelector: kVirtualMainVolume,
            mScope:    kAudioDevicePropertyScopeOutput,
            mElement:  kAudioObjectPropertyElementMain
        )
        if writeFloat(volume, deviceID: deviceID, address: &address) { return true }

        // Try per-channel scalar on channels 0, 1, 2.
        address.mSelector = kAudioDevicePropertyVolumeScalar
        var wrote = false
        for ch: UInt32 in [0, 1, 2] {
            address.mElement = ch
            if writeFloat(volume, deviceID: deviceID, address: &address) { wrote = true }
        }
        return wrote
    }

    private func writeFloat(_ value: Float, deviceID: AudioDeviceID,
                            address: inout AudioObjectPropertyAddress) -> Bool {
        var settable: DarwinBoolean = false
        guard AudioObjectHasProperty(deviceID, &address),
              AudioObjectIsPropertySettable(deviceID, &address, &settable) == noErr,
              settable.boolValue
        else { return false }
        var v = Float32(value)
        return AudioObjectSetPropertyData(
            deviceID, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &v) == noErr
    }

    // MARK: - Private — media key fallback

    /// Simulate volume-key presses. Each press moves volume by 1/16 (6.25%).
    /// NX_KEYTYPE_SOUND_UP = 0, NX_KEYTYPE_SOUND_DOWN = 1.
    private func writeViaMediaKeys(steps: Int) {
        let keyType: Int = steps > 0 ? 0 : 1
        let presses = max(1, Int((abs(Float(steps) * stepSize) / (1.0 / 16.0)).rounded()))

        for _ in 0 ..< presses {
            postMediaKey(keyType: keyType, down: true)
            postMediaKey(keyType: keyType, down: false)
        }
    }

    private func postMediaKey(keyType: Int, down: Bool) {
        let flags: NSEvent.ModifierFlags = down
            ? NSEvent.ModifierFlags(rawValue: 0xa00)
            : NSEvent.ModifierFlags(rawValue: 0xb00)
        let data1 = (keyType << 16) | ((down ? 0xa : 0xb) << 8)
        NSEvent.otherEvent(
            with: .systemDefined, location: .zero, modifierFlags: flags,
            timestamp: 0, windowNumber: 0, context: nil,
            subtype: 8, data1: data1, data2: -1
        )?.cgEvent?.post(tap: .cgAnnotatedSessionEventTap)
    }
}
