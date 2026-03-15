// SurfaceDialDriver.swift
// IOHIDManager-based driver for the Microsoft Surface Dial (VID 0x045E / PID 0x091B).
//
// HID input report byte layout (from mac-dial reverse engineering):
//   Byte 0: report ID
//   Byte 1: button state (bit 0 = pressed)
//   Bytes 2–3: rotation delta (signed Int16, little-endian)
//
// resolution = 3600 (3600 ticks per full 360° rotation)
//
// For haptic output: IOHIDDeviceSetReport() targeting the SimpleHapticsController
// collection (HID Page 0x0E, Usage 0x01).

import IOKit
import IOKit.hid
import Foundation

// MARK: - SurfaceDialDriver

/// Concrete DialDevice driver for the Microsoft Surface Dial.
/// Also conforms to HapticDialDevice since the Surface Dial supports HID haptic output.
final class SurfaceDialDriver: DialDevice, HapticDialDevice {

    // MARK: DialDevice

    let name = "Microsoft Surface Dial"
    let vendorID = 0x045E
    let productID = 0x091B
    /// 3600 ticks per full rotation.
    let resolution = 3600

    // Strong reference to the matched HID device (shared with SurfaceDialHapticEngine later).
    private(set) var hidDevice: IOHIDDevice?
    private var hidManager: IOHIDManager?

    // AsyncStream continuation — wired up in init so it is ready before connect() is called.
    private var continuation: AsyncStream<DialEvent>.Continuation?
    let eventStream: AsyncStream<DialEvent>

    // Report buffer kept alive on the instance — IOHIDDeviceRegisterInputReportCallback
    // holds a raw pointer to this memory for the lifetime of the connection.
    private var reportBuffer = [UInt8](repeating: 0, count: 64)

    // Track button state to emit pressed/released only on transitions.
    private var lastButtonState = false

    // MARK: - init

    init() {
        // Wire the continuation synchronously; AsyncStream calls the closure before returning.
        var capturedContinuation: AsyncStream<DialEvent>.Continuation?
        eventStream = AsyncStream { capturedContinuation = $0 }
        continuation = capturedContinuation
    }

    // MARK: - connect

    func connect() throws {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        hidManager = manager

        // Match exactly this VID/PID.
        let matching: [String: Any] = [
            kIOHIDVendorIDKey:  vendorID,
            kIOHIDProductIDKey: productID,
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        // Device-matched callback — fires when the dial is found.
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, _, _, device in
            guard let context else { return }
            Unmanaged<SurfaceDialDriver>.fromOpaque(context).takeUnretainedValue()
                .deviceMatched(device)
        }, selfPtr)

        // Device-removed callback.
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, _, _, _ in
            guard let context else { return }
            Unmanaged<SurfaceDialDriver>.fromOpaque(context).takeUnretainedValue()
                .continuation?.yield(.disconnected)
        }, selfPtr)

        IOHIDManagerScheduleWithRunLoop(
            manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            throw DialDriverError.openFailed(result)
        }
    }

    // MARK: - disconnect

    func disconnect() {
        if let manager = hidManager {
            IOHIDManagerUnscheduleFromRunLoop(
                manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
        hidManager = nil
        hidDevice = nil
        continuation?.finish()
    }

    // MARK: - Private — device matched

    private func deviceMatched(_ device: IOHIDDevice) {
        hidDevice = device
        continuation?.yield(.connected)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        // reportBuffer lives on the instance, so the pointer stays valid.
        IOHIDDeviceRegisterInputReportCallback(
            device,
            &reportBuffer,
            CFIndex(reportBuffer.count),
            { context, _, _, _, _, report, reportLength in
                guard let context else { return }
                Unmanaged<SurfaceDialDriver>.fromOpaque(context).takeUnretainedValue()
                    .handleReport(report, length: reportLength)
            },
            selfPtr
        )
    }

    // MARK: - Private — parse report

    private func handleReport(_ report: UnsafePointer<UInt8>, length: CFIndex) {
        // Byte 0: report ID (ignored)
        // Byte 1: button state — bit 0 = pressed
        // Bytes 2–3: rotation delta as signed Int16, little-endian
        guard length >= 4 else { return }

        let buttonPressed = (report[1] & 0x01) != 0
        if buttonPressed != lastButtonState {
            lastButtonState = buttonPressed
            continuation?.yield(buttonPressed ? .pressed : .released)
        }

        let delta = Int16(bitPattern: UInt16(report[2]) | (UInt16(report[3]) << 8))
        if delta != 0 {
            continuation?.yield(.rotated(delta: Int(delta)))
        }
    }

    // MARK: - HapticDialDevice (stubbed — not needed for smoke test)

    func playHaptic(waveformOrdinal: Int, intensity: Float, repeatCount: Int) {
        // TODO: Build and send HID output report via IOHIDDeviceSetReport().
    }

    func setAutoTrigger(enabled: Bool) {
        // TODO: Enable or disable the device's built-in auto-trigger haptics.
    }
}

// MARK: - Errors

enum DialDriverError: Error {
    case openFailed(IOReturn)
}
