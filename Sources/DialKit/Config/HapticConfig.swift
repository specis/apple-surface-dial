// HapticConfig.swift
// Per-event haptic intensity and waveform settings.
//
// Stored in profiles.json under "haptics".

import Foundation

// MARK: - HapticEventConfig

/// Waveform and playback parameters for a single HapticEvent.
struct HapticEventConfig: Codable {
    /// "click" or "buzz".
    var waveform: String
    /// 0–100 intensity percentage.
    var intensity: Int
    /// Number of additional repeats after the first play (0 = play once).
    var `repeat`: Int
    /// Minimum milliseconds between repeated triggers (optional).
    var retriggerMs: Int?
}

// MARK: - HapticConfig

/// Top-level haptic configuration block.
struct HapticConfig: Codable {
    var enabled: Bool
    /// If false, the host takes full control of haptic output (disables device auto-trigger).
    var autoTriggerEnabled: Bool
    /// Per-event overrides. Keys match HapticEvent raw values.
    var events: [String: HapticEventConfig]
}
