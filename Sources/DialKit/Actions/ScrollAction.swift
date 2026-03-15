// ScrollAction.swift
// Synthesises scroll wheel events via CGEvent.
//
// Posting strategy (tried in order):
//   1. .cghidEventTap   — injected before the HID stack; most reliable. Requires Accessibility.
//   2. .cgSessionEventTap — session-level inject; no Accessibility needed; works in most apps.
//   3. Pixel-unit fallback — some apps ignore line-unit events but respond to pixel deltas.
//
// The event has no explicit location set so the OS delivers it to the window under the cursor,
// which is the correct behaviour for a dial device. (postToPid bypasses hit-testing and is
// unreliable for scroll events — removed.)

import AppKit
import CoreGraphics
import OSLog

// MARK: - ScrollAction

final class ScrollAction {

    /// Lines scrolled per logical step.
    var linesPerStep: Int32 = 3

    /// Pixels per line for the pixel-unit fallback. 28px ≈ one standard macOS scroll line.
    var pixelsPerLine: Int32 = 28

    /// When true, clockwise rotation scrolls content down (macOS natural scrolling).
    var isNaturalScrolling: Bool = true

    // MARK: - Public

    func scroll(steps: Int) {
        guard steps != 0 else { return }

        var delta = Int32(clamping: steps) * linesPerStep
        if isNaturalScrolling { delta = -delta }

        if postLineEvent(delta: delta) { return }

        // Pixel fallback — some Electron/web apps ignore line-unit events.
        let pixelDelta = delta * pixelsPerLine
        postPixelEvent(delta: pixelDelta)
    }

    // MARK: - Private

    @discardableResult
    private func postLineEvent(delta: Int32) -> Bool {
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .line,
            wheelCount: 1,
            wheel1: delta,
            wheel2: 0,
            wheel3: 0
        ) else {
            Log.volume.error("Failed to create line-unit scroll CGEvent")
            return false
        }

        post(event)
        Log.volume.debug("Scroll line delta=\(delta)")
        return true
    }

    private func postPixelEvent(delta: Int32) {
        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 1,
            wheel1: delta,
            wheel2: 0,
            wheel3: 0
        ) else { return }

        post(event)
        Log.volume.debug("Scroll pixel delta=\(delta) (fallback)")
    }

    private func post(_ event: CGEvent) {
        // No explicit location — OS delivers to the window currently under the cursor.
        if AXIsProcessTrusted() {
            // HID tap: injected before the HID processing stack. Most reliable.
            event.post(tap: .cghidEventTap)
        } else {
            // Session tap: no Accessibility needed. Works for most native apps.
            event.post(tap: .cgSessionEventTap)
        }
    }
}
