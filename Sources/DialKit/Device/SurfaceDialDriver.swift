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
import OSLog

// MARK: - SurfaceDialDriver

/// Concrete DialDevice driver for the Microsoft Surface Dial.
/// Also conforms to HapticDialDevice since the Surface Dial supports HID haptic output.
final class SurfaceDialDriver: DialDevice, HapticDialDevice {

    // MARK: DialDevice

    let name = "Microsoft Surface Dial"
    let vendorID = 0x045E
    let productID = 0x091B
    /// Ticks per full 360° revolution, read from the device's Resolution Multiplier
    /// feature element (HID Page 1, Usage 0x48) after connection.
    /// Falls back to 360 if the feature report is unavailable.
    private(set) var resolution: Int = 360

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
            let driver = Unmanaged<SurfaceDialDriver>.fromOpaque(context).takeUnretainedValue()
            Log.device.warning("Surface Dial disconnected")
            driver.continuation?.yield(.disconnected)
        }, selfPtr)

        IOHIDManagerScheduleWithRunLoop(
            manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            Log.device.error("IOHIDManagerOpen failed: IOReturn 0x\(String(UInt32(bitPattern: result), radix: 16))")
            throw DialDriverError.openFailed(result)
        }
        Log.device.info("HID manager opened — scanning for Surface Dial (VID 0x\(String(self.vendorID, radix: 16)) / PID 0x\(String(self.productID, radix: 16)))")
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

    // MARK: - Private — resolution multiplier

    /// Reads the Resolution Multiplier feature element (Generic Desktop, Usage 0x48)
    /// which reports the device's ticks-per-revolution. Updates `resolution` if found.
    private func readResolutionMultiplier(from device: IOHIDDevice) {
        let matching: [String: Any] = [
            kIOHIDElementUsagePageKey: 1,   // Generic Desktop
            kIOHIDElementUsageKey:    72,   // Resolution Multiplier (0x48)
        ]
        guard let cfArr = IOHIDDeviceCopyMatchingElements(
                device, matching as CFDictionary, IOOptionBits(kIOHIDOptionsTypeNone)),
              let elements = cfArr as? [IOHIDElement] else { return }

        for element in elements {
            guard IOHIDElementGetType(element) == kIOHIDElementTypeFeature else { continue }
            var valueRef = Unmanaged<IOHIDValue>.passRetained(IOHIDValueCreateWithIntegerValue(
                kCFAllocatorDefault, element, 0, 0))
            guard IOHIDDeviceGetValue(device, element, &valueRef) == kIOReturnSuccess else { continue }
            let multiplier = Int(IOHIDValueGetIntegerValue(valueRef.takeRetainedValue()))
            if multiplier > 0 {
                resolution = multiplier
                Log.device.info("Resolution Multiplier: \(multiplier) ticks/revolution")
                return
            }
        }
    }

    // MARK: - Private — device matched

    private func deviceMatched(_ device: IOHIDDevice) {
        hidDevice = device
        Log.device.info("Surface Dial matched — reading resolution multiplier")
        readResolutionMultiplier(from: device)
        Log.device.info("Surface Dial connected (resolution: \(self.resolution) ticks/rev)")
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
        guard length >= 4 else {
            Log.device.warning("Short HID report (\(length) bytes) — ignoring")
            return
        }

        let buttonPressed = (report[1] & 0x01) != 0
        if buttonPressed != lastButtonState {
            lastButtonState = buttonPressed
            Log.device.debug("Button \(buttonPressed ? "pressed" : "released")")
            continuation?.yield(buttonPressed ? .pressed : .released)
        }

        let delta = Int16(bitPattern: UInt16(report[2]) | (UInt16(report[3]) << 8))
        if delta != 0 {
            Log.device.debug("Rotation delta: \(delta) ticks")
            continuation?.yield(.rotated(delta: Int(delta)))
        }
    }

    // MARK: - HapticDialDevice (stubbed — not needed for smoke test)

    func playHaptic(waveformOrdinal: Int, intensity: Float, repeatCount: Int) {
        guard let device = hidDevice else { return }

        // SimpleHapticsController output report — Surface Dial (HID Page 0x0E, Usage 0x01).
        // Report ID 1. Byte layout from HID descriptor (ioreg analysis):
        //   [0]: RetriggerPeriod (8-bit, 0 = one-shot / no retrigger)
        //   [1]: AutoTriggerAssociatedControl (8-bit, 1 = manual trigger)
        //   [2]: WaveformVendorPage low byte (uint16 LE — ordinal into WaveformList)
        //   [3]: WaveformVendorPage high byte
        //
        // WaveformList ordinals (from Feature Report 2):
        //   3 = Click, 4 = Buzz Continuous, 5 = (third waveform)
        var report: [UInt8] = [
            0x00,                                    // RetriggerPeriod: 0 = one-shot
            0x01,                                    // AutoTriggerAssociatedControl: 1
            UInt8(waveformOrdinal & 0xFF),           // Waveform ordinal low byte
            UInt8((waveformOrdinal >> 8) & 0xFF),    // Waveform ordinal high byte
        ]
        IOHIDDeviceSetReport(
            device,
            kIOHIDReportTypeOutput,
            CFIndex(1),  // Report ID
            &report,
            CFIndex(report.count)
        )
    }

    func setAutoTrigger(enabled: Bool) {
        // The Surface Dial auto-triggers haptic detents by default.
        // Sending a feature report to Page 0x0E with AutoTrigger=0 disables this
        // so the host takes full control. Not implemented yet — detent haptics
        // currently rely on the device's built-in auto-trigger behaviour.
    }
}

// MARK: - Errors

enum DialDriverError: Error {
    case openFailed(IOReturn)
}
