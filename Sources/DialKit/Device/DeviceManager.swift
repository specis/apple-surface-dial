// DeviceManager.swift
// Owns the Surface Dial driver and haptic engine, and exposes connection state changes.
//
// Reconnection is automatic: IOHIDManager keeps scanning after a disconnect and
// fires deviceMatched again when the dial wakes up. InputInterpreter receives the
// .connected event and the pipeline resumes transparently.
//
// DeviceRegistry / multi-device support is scaffolded but not yet wired — the
// driver is instantiated directly here to avoid existential indirection issues.

import Foundation
import OSLog

// MARK: - DeviceManagerError

enum DeviceManagerError: Error {
    case openFailed(IOReturn)
}

// MARK: - DeviceManager

final class DeviceManager {

    // MARK: - Public outputs

    /// The Surface Dial HID driver. Always non-nil after start().
    let driver: SurfaceDialDriver

    /// Haptic engine for the driver. SurfaceDialHapticEngine after start().
    let hapticEngine: SurfaceDialHapticEngine

    // MARK: - Protocol-typed accessors (used by the rest of the pipeline)

    var primaryDevice: any DialDevice { driver }
    var haptics: any HapticEngine { hapticEngine }

    // MARK: - Init

    init() {
        driver = SurfaceDialDriver()
        hapticEngine = SurfaceDialHapticEngine(driver: driver)
    }

    // MARK: - Start

    /// Opens the IOHIDManager. Throws if Input Monitoring permission is denied.
    func start() throws {
        do {
            try driver.connect()
            Log.device.info("DeviceManager: IOHIDManager open — scanning for \(self.driver.name)")
        } catch DialDriverError.openFailed(let code) {
            Log.device.error("DeviceManager: IOHIDManager open failed (IOReturn 0x\(String(UInt32(bitPattern: code), radix: 16)))")
            throw DeviceManagerError.openFailed(code)
        }
    }
}
