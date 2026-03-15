// DialDevice.swift
// Device abstraction protocol and DialEvent enum.
//
// Every supported device driver must conform to DialDevice.
// Nothing outside Device/ should reference a concrete driver type.

import Foundation

// MARK: - DialEvent

/// Raw events emitted by any DialDevice driver.
enum DialEvent {
    case connected
    case disconnected
    /// Rotation delta in raw device ticks. Negative = anticlockwise.
    case rotated(delta: Int)
    case pressed
    case released
}

// MARK: - DialDevice Protocol

/// Core protocol every dial device driver must implement.
protocol DialDevice: AnyObject {
    var name: String { get }
    var vendorID: Int { get }
    var productID: Int { get }
    /// Ticks emitted per full 360° rotation. Used by InputInterpreter for normalisation.
    var resolution: Int { get }
    func connect() throws
    func disconnect()
    var eventStream: AsyncStream<DialEvent> { get }
}

// MARK: - Optional Capability Protocols

/// Devices conform to this only if they support haptic output.
/// Check availability with: `if let h = device as? HapticDialDevice { ... }`
protocol HapticDialDevice: DialDevice {
    func playHaptic(waveformOrdinal: Int, intensity: Float, repeatCount: Int)
    func setAutoTrigger(enabled: Bool)
}

/// Devices conform to this only if they have a controllable LED ring.
protocol IlluminatedDialDevice: DialDevice {
    func setLED(brightness: Float)
}

/// Devices conform to this only if they expose more than one button.
protocol MultiButtonDialDevice: DialDevice {
    var buttonCount: Int { get }
    var buttonStream: AsyncStream<ButtonEvent> { get }
}

// MARK: - Supporting Types

/// Button event for devices with multiple buttons.
struct ButtonEvent {
    let index: Int
    let isPressed: Bool
}
