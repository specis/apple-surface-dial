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

/// HID SimpleHapticsController waveform identifiers.
enum Waveform: Int {
    case click = 0x01
    case buzz  = 0x02
    // TODO: Add additional waveform ordinals as discovered from HID descriptor.
}

// MARK: - HapticParams

/// Resolved parameters to pass to SurfaceDialHapticEngine.playHaptic().
struct HapticParams {
    let waveformOrdinal: Int
    let intensity: Float      // 0.0 – 1.0
    let repeatCount: Int
    let retriggerMs: Int?
}

// MARK: - HapticEventMap

/// Resolves a HapticEvent to HapticParams, applying user config overrides.
struct HapticEventMap {
    // TODO: Accept a HapticConfig and build a lookup table from defaults + overrides.
    // TODO: Expose resolve(_ event: HapticEvent) -> HapticParams.
    // TODO: Convert "click"/"buzz" waveform strings from config to Waveform ordinals.
}
