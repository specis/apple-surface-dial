// main.swift
// DialKit — smoke-test entry point.
//
// Connects to the Surface Dial and prints raw DialEvents to stdout.
// No actions, routing, overlay, or haptics — just confirming the device works.

import AppKit

let driver = SurfaceDialDriver()

do {
    try driver.connect()
} catch DialDriverError.openFailed(let code) {
    fputs("Failed to open IOHIDManager (IOReturn \(code)). " +
          "Check Input Monitoring permission in System Settings → Privacy & Security.\n",
          stderr)
    exit(1)
}

print("Waiting for Surface Dial (VID 0x045E / PID 0x091B)…")
print("Rotate, press, or release the dial to see events. Ctrl-C to quit.\n")

Task {
    for await event in driver.eventStream {
        switch event {
        case .connected:
            print("[connected]")
        case .disconnected:
            print("[disconnected]")
        case .rotated(let delta):
            let direction = delta > 0 ? "clockwise" : "anticlockwise"
            print("rotated  delta=\(delta)  (\(direction))")
        case .pressed:
            print("pressed")
        case .released:
            print("released")
        }
    }
}

NSApplication.shared.run()
