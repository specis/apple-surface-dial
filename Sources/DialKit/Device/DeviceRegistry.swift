// DeviceRegistry.swift
// Static registry of known devices.
//
// To add a new device: append one entry to knownDevices.
// Nothing else in the codebase needs to change.

import Foundation

// MARK: - Device Registry

/// Each entry maps a (vendorID, productID) pair to a factory closure.
/// DeviceManager iterates this list to find and instantiate the right driver.
let knownDevices: [(vendorID: Int, productID: Int, make: () -> any DialDevice)] = [
    (0x045E, 0x091B, { SurfaceDialDriver() }),   // Microsoft Surface Dial
    // (0x077D, 0x0410, { PowerMateDriver() }),  // Griffin PowerMate BT (future)
]
