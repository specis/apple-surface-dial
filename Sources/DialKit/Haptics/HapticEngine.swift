// HapticEngine.swift
// Protocol and HapticEvent enum for the haptic feedback system.
//
// Only SurfaceDialHapticEngine maps HapticEvents to HID waveforms.
// App logic emits semantic HapticEvents — never raw waveform ordinals.

import Foundation

// MARK: - HapticEvent

/// Semantic haptic events emitted by app logic.
enum HapticEvent {
    /// One logical rotation step — the "detent" click.
    case detent
    /// A mode change was committed.
    case modeSwitch
    /// A shortcut action was executed.
    case shortcutFired
    /// A boundary was hit (e.g. volume at 0% or 100%).
    case boundaryReached
    /// The radial overlay menu was opened.
    case menuOpen
    /// The radial overlay menu was closed.
    case menuClose
}

// MARK: - HapticEngine Protocol

/// Abstracts haptic output so the rest of the app never references HID details.
protocol HapticEngine {
    /// True if this engine can produce haptic feedback on the current device.
    var isSupported: Bool { get }
    func play(_ event: HapticEvent) async
    func configure(with config: HapticConfig)
}
