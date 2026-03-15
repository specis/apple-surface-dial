// SurfaceDialHapticEngine.swift
// HapticEngine implementation that drives Surface Dial haptics via HID output reports.
//
// Calls HapticDialDevice.playHaptic() — the driver owns the IOHIDDevice reference
// and handles the actual IOHIDDeviceSetReport call.

import Foundation

// MARK: - SurfaceDialHapticEngine

/// Concrete HapticEngine for the Surface Dial.
/// Resolves semantic HapticEvents to waveform params via HapticEventMap and
/// forwards them to the device driver.
final class SurfaceDialHapticEngine: HapticEngine {

    let isSupported = true

    /// Set to false to suppress all haptic output without changing the wiring.
    var isEnabled: Bool = true

    private let driver: any HapticDialDevice
    private var eventMap: HapticEventMap

    /// Tracks the last time each event was played for retrigger throttling.
    private var lastPlayed: [String: TimeInterval] = [:]

    init(driver: any HapticDialDevice) {
        self.driver = driver
        self.eventMap = HapticEventMap()
    }

    // MARK: - HapticEngine

    func play(_ event: HapticEvent) async {
        guard isEnabled else { return }
        let params = eventMap.resolve(event)

        // Retrigger throttle: skip if fired too recently.
        if let ms = params.retriggerMs {
            let key = "\(event)"
            let now = Date().timeIntervalSinceReferenceDate
            let minInterval = Double(ms) / 1000.0
            if let last = lastPlayed[key], now - last < minInterval { return }
            lastPlayed[key] = now
        }

        driver.playHaptic(
            waveformOrdinal: params.waveformOrdinal,
            intensity:       params.intensity,
            repeatCount:     params.repeatCount
        )
    }

    func configure(with config: HapticConfig) {
        eventMap = HapticEventMap(config: config)
    }
}
