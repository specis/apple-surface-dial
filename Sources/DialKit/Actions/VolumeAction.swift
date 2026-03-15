// VolumeAction.swift
// Adjusts system volume via CoreAudio.
//
// Reads/writes kAudioHardwareServiceDeviceProperty_VirtualMainVolume.
// Media key events (play/pause/next) via CGEvent with NX_KEYTYPE_SOUND_UP/DOWN.
// No special permissions required.

import CoreAudio
import CoreGraphics
import Foundation

// MARK: - VolumeAction

/// Handles ActionEvent.rotated by adjusting the system output volume.
final class VolumeAction {
    // TODO: Locate the default output audio device via AudioHardwareServiceGetPropertyData.
    // TODO: Read current volume level.
    // TODO: Apply stepSize (from AppProfile.volume.stepSize) per normalised step.
    // TODO: Clamp to [0.0, 1.0] and write back via AudioHardwareServiceSetPropertyData.
    // TODO: Emit .boundaryReached HapticEvent when clamped at 0% or 100%.
}
