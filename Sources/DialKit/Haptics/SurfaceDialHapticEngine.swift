// SurfaceDialHapticEngine.swift
// HapticEngine implementation that sends HID output reports to the Surface Dial.
//
// Sends IOHIDDeviceSetReport() with report type .output targeting the
// SimpleHapticsController collection (HID Page 0x0E, Usage 0x01).
//
// Shares the IOHIDDeviceRef held by SurfaceDialDriver.

import IOKit
import IOKit.hid
import Foundation

// MARK: - SurfaceDialHapticEngine

/// Concrete HapticEngine that drives Surface Dial haptics via HID output reports.
final class SurfaceDialHapticEngine: HapticEngine {

    let isSupported = true

    // TODO: Accept a weak/unowned reference to the IOHIDDeviceRef from SurfaceDialDriver.
    // TODO: Hold a HapticEventMap for resolving HapticEvent → HapticParams.
    // TODO: Implement play(_ event:) — resolve params, build HID report, call IOHIDDeviceSetReport.
    // TODO: Implement configure(with:) — rebuild HapticEventMap from new config.
    // TODO: Respect retriggerMs to prevent over-triggering on rapid detent events.

    func play(_ event: HapticEvent) async {
        // TODO: Implement.
    }

    func configure(with config: HapticConfig) {
        // TODO: Implement.
    }
}
