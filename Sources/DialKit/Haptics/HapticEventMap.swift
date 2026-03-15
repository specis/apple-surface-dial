// HapticEventMap.swift
// Maps HapticEvent values to HID waveform ordinals, intensity, and repeat counts.
//
// Default mapping (all values user-configurable via HapticConfig):
//
//   HapticEvent        Waveform         Intensity  RepeatCount  RetriggerPeriod
//   ─────────────────  ───────────────  ─────────  ───────────  ───────────────
//   .detent            WAVEFORM_CLICK   60%        0            —
//   .modeSwitch        WAVEFORM_BUZZ    90%        0            —
//   .shortcutFired     WAVEFORM_CLICK   70%        1            80ms
//   .boundaryReached   WAVEFORM_BUZZ    100%       0            —
//   .menuOpen          WAVEFORM_CLICK   40%        0            —
//   .menuClose         WAVEFORM_CLICK   30%        0            —

import Foundation

// MARK: - Waveform

/// HID SimpleHapticsController waveform ordinals for the Surface Dial.
/// These are WaveformList indices from Feature Report 2 in the HID descriptor.
/// (Not HID Usage values — ordinals 3/4/5 are device-specific entries.)
enum Waveform: Int {
    case click = 3  // WaveformList[3] — Click
    case buzz  = 4  // WaveformList[4] — Buzz Continuous
    case third = 5  // WaveformList[5] — third available waveform
}

// MARK: - HapticParams

/// Resolved parameters passed to HapticDialDevice.playHaptic().
struct HapticParams {
    let waveformOrdinal: Int
    let intensity: Float      // 0.0 – 1.0
    let repeatCount: Int
    let retriggerMs: Int?
}

// MARK: - HapticEventMap

/// Resolves a HapticEvent to HapticParams, applying optional user config overrides.
struct HapticEventMap {

    private let overrides: [String: HapticEventConfig]

    init(config: HapticConfig? = nil) {
        overrides = config?.events ?? [:]
    }

    func resolve(_ event: HapticEvent) -> HapticParams {
        let key = eventKey(for: event)
        if let cfg = overrides[key] {
            return HapticParams(
                waveformOrdinal: waveformOrdinal(from: cfg.waveform),
                intensity:       Float(cfg.intensity) / 100.0,
                repeatCount:     cfg.repeat,
                retriggerMs:     cfg.retriggerMs
            )
        }
        return defaults(for: event)
    }

    // MARK: - Private

    private func defaults(for event: HapticEvent) -> HapticParams {
        switch event {
        case .detent:
            return HapticParams(waveformOrdinal: Waveform.click.rawValue,
                                intensity: 0.60, repeatCount: 0, retriggerMs: nil)
        case .modeSwitch:
            return HapticParams(waveformOrdinal: Waveform.buzz.rawValue,
                                intensity: 0.90, repeatCount: 0, retriggerMs: nil)
        case .shortcutFired:
            return HapticParams(waveformOrdinal: Waveform.click.rawValue,
                                intensity: 0.70, repeatCount: 1, retriggerMs: 80)
        case .boundaryReached:
            return HapticParams(waveformOrdinal: Waveform.buzz.rawValue,
                                intensity: 1.00, repeatCount: 0, retriggerMs: nil)
        case .menuOpen:
            return HapticParams(waveformOrdinal: Waveform.click.rawValue,
                                intensity: 0.40, repeatCount: 0, retriggerMs: nil)
        case .menuClose:
            return HapticParams(waveformOrdinal: Waveform.click.rawValue,
                                intensity: 0.30, repeatCount: 0, retriggerMs: nil)
        }
    }

    private func eventKey(for event: HapticEvent) -> String {
        switch event {
        case .detent:         return "detent"
        case .modeSwitch:     return "modeSwitch"
        case .shortcutFired:  return "shortcutFired"
        case .boundaryReached:return "boundaryReached"
        case .menuOpen:       return "menuOpen"
        case .menuClose:      return "menuClose"
        }
    }

    private func waveformOrdinal(from name: String) -> Int {
        name.lowercased() == "buzz" ? Waveform.buzz.rawValue : Waveform.click.rawValue
    }
}
