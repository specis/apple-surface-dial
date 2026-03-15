// main.swift
// DialKit — wired entry point for scroll smoke test.
//
// Surface Dial → SurfaceDialDriver → InputInterpreter → ActionEventBus → ScrollAction
// Tap and hold events are printed to stdout until the overlay and haptics are wired up.

import AppKit
import ApplicationServices

// MARK: - Accessibility permission
//
// CGEvent synthesis (scroll, keystrokes) requires the process to be trusted.
// Passing kAXTrustedCheckOptionPrompt: true opens the System Settings dialog
// automatically on first run. The user must add this app (or Terminal, when
// running via `swift run`) to Privacy & Security → Accessibility.

let axOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
let isTrusted = AXIsProcessTrustedWithOptions(axOptions as CFDictionary)
if isTrusted {
    print("Accessibility: granted ✓")
} else {
    print("Accessibility: NOT granted — scroll will not work.")
    print("Grant access in System Settings → Privacy & Security → Accessibility,")
    print("then restart DialKit.")
}

// MARK: - Bootstrap

let driver      = SurfaceDialDriver()
let bus         = ActionEventBus()
let volume      = VolumeAction()
let haptics     = SurfaceDialHapticEngine(driver: driver)
let interpreter = InputInterpreter(device: driver, bus: bus)
let menuBar     = MenuBarController(accessibilityGranted: isTrusted)

// Surface Dial reports 36 ticks/revolution (1 tick ≈ 10° of rotation).
// 2% per step × 36 steps/revolution = ~72% volume range per full turn.
volume.stepSize = 0.02

menuBar.currentMode = .volume
menuBar.hapticsAvailable = true

menuBar.onModeChange = { mode in
    print("mode → \(mode.displayName)")
}

menuBar.onHapticsToggle = { enabled in
    print("haptics → \(enabled ? "on" : "off")")
}

volume.onVolumeChanged = { level, hitBoundary in
    let pct = Int(level * 100)
    print("volume: \(pct)%\(hitBoundary ? " [boundary]" : "")")
}

do {
    try driver.connect()
} catch DialDriverError.openFailed(let code) {
    fputs("Failed to open IOHIDManager (IOReturn \(code)). " +
          "Check Input Monitoring in System Settings → Privacy & Security.\n", stderr)
    exit(1)
}

interpreter.start()

// MARK: - Event consumer

Task {
    for await event in bus.observe() {
        switch event {
        case .rotated(let steps):
            volume.adjust(steps: steps)
            await haptics.play(.detent)
        case .tap:
            print("tap")
        case .holdConfirmed:
            await haptics.play(.menuOpen)
            print("hold — open menu here eventually")
        case .menuRotated:
            await haptics.play(.detent)
        case .menuCommit:
            await haptics.play(.modeSwitch)
            print("menu commit")
        case .menuDismiss:
            await haptics.play(.menuClose)
            print("menu dismissed (inactivity)")
        }
    }
}

// MARK: - Run loop

NSApplication.shared.run()
