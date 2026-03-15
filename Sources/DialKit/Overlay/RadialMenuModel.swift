// RadialMenuModel.swift
// Data model backing the radial menu view.
//
// Holds segment definitions, the currently highlighted segment index,
// a live value string for the active mode, and the running rotation angle.

import Foundation

// MARK: - RadialSegment

/// Data for a single menu segment.
struct RadialSegment {
    let mode: Mode
    /// Glyph or SF Symbol name displayed in the segment.
    let glyph: String
    /// Human-readable mode name.
    let label: String
    /// Optional live value shown beneath the label (e.g. "72%" for volume).
    var liveValue: String?
}

// MARK: - RadialMenuModel

/// Observable model for RadialMenuView.
/// Updated by OverlayController; read by RadialMenuView during draw.
final class RadialMenuModel {
    // TODO: Define the three default segments (scroll, volume, shortcut) in order.
    // TODO: Track highlightedIndex (0–2) — the segment currently selected by rotation.
    // TODO: Track cumulativeAngle — running rotation since menu opened (for progress arc).
    // TODO: Track centreLabel — active app profile name (e.g. "Photoshop" or "Default").
    // TODO: Notify RadialMenuView via setNeedsDisplay when any value changes.
}
