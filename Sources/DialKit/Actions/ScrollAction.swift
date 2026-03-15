// ScrollAction.swift
// Synthesises scroll wheel events via CGEvent.
//
// Posts directly to the frontmost application's PID so that scroll goes to
// wherever the user is working, regardless of cursor position.
// No special permissions required.

import AppKit
import CoreGraphics

// MARK: - ScrollAction

/// Posts CGEvent scroll wheel events in response to normalised rotation steps.
final class ScrollAction {

    /// Lines scrolled per logical step. Tune for feel.
    var linesPerStep: Int32 = 3

    /// When true, clockwise rotation scrolls down (matches macOS natural scrolling).
    /// When false, clockwise rotation scrolls up (classic/inverted).
    var isNaturalScrolling: Bool = true

    /// Synthesise and post a scroll wheel event for the given step count.
    /// Positive steps = clockwise rotation.
    func scroll(steps: Int) {
        guard steps != 0 else { return }

        var delta = Int32(clamping: steps) * linesPerStep
        // Natural scrolling: clockwise (positive steps) scrolls content down,
        // which means a negative wheel1 value.
        if isNaturalScrolling { delta = -delta }

        guard let event = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .line,
            wheelCount: 1,
            wheel1: delta,
            wheel2: 0,
            wheel3: 0
        ) else { return }

        // Deliver to the frontmost app directly — cursor position is irrelevant.
        if let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier {
            event.postToPid(pid)
        } else {
            event.post(tap: .cgAnnotatedSessionEventTap)
        }
    }
}
