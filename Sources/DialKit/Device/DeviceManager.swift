// DeviceManager.swift
// Scans for known VID/PID pairs and instantiates the appropriate driver.
//
// Consults DeviceRegistry for the list of known devices.
// Assigns a HapticEngine based on whether the device conforms to HapticDialDevice.

import Foundation

// MARK: - DeviceManager

/// Responsible for discovering and managing DialDevice instances.
final class DeviceManager {
    // TODO: Hold a reference to the currently active DialDevice.
    // TODO: On start(), iterate knownDevices from DeviceRegistry and attempt connection.
    // TODO: Assign SurfaceDialHapticEngine or NullHapticEngine depending on HapticDialDevice conformance.
    // TODO: Expose the active device's eventStream for InputInterpreter to consume.
    // TODO: Handle device disconnection and reconnection.
}
