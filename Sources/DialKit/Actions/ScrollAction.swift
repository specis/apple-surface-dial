// ScrollAction.swift
// Synthesises scroll wheel events via CGEvent.
//
// Uses CGEvent(scrollWheelEvent2Source:units:wheelCount:scroll1:scroll2:scroll3:)
// and posts via CGEvent.post(tap: .cghidEventTap).
// No special permissions required.

import CoreGraphics
import Foundation

// MARK: - ScrollAction

/// Handles ActionEvent.rotated by posting CGEvent scroll wheel events.
final class ScrollAction {
    // TODO: Read direction ("natural" vs "inverted") and multiplier from AppProfile.
    // TODO: Map normalised steps to a pixel/line scroll delta.
    // TODO: Create and post CGScrollWheelEvent on action.
}
