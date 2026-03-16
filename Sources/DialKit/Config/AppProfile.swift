// AppProfile.swift
// Per-bundle-ID profile struct.
//
// Stored in profiles.json under "defaultProfile" and "appProfiles".

import Foundation

// MARK: - ShortcutDefinition

/// A single shortcut binding: a triggering action + key combo + display label.
struct ShortcutDefinition: Codable {
    /// The dial action that triggers this shortcut ("rotate_cw", "rotate_ccw", "press", "select").
    let action: String
    /// Keys synthesised when this shortcut fires (e.g. ["cmd", "z"]).
    let keys: [String]
    /// Human-readable label shown in the overlay and HUD.
    let label: String
    /// Physical modifier keys the user must be holding for this shortcut to fire
    /// (e.g. ["shift"]). When nil or empty, fires when no relevant modifiers are held.
    let requiredModifiers: [String]?

    init(action: String, keys: [String], label: String, requiredModifiers: [String]? = nil) {
        self.action            = action
        self.keys              = keys
        self.label             = label
        self.requiredModifiers = requiredModifiers
    }
}

// MARK: - ScrollConfig

struct ScrollConfig: Codable {
    /// "natural" or "inverted".
    var direction: String
    var multiplier: Double
}

// MARK: - VolumeConfig

struct VolumeConfig: Codable {
    /// Volume change per logical step (0–100 scale).
    var stepSize: Int
}

// MARK: - AppOverlaySegment

/// A single custom segment in the radial overlay menu for a specific app profile.
struct AppOverlaySegment: Codable {
    /// Glyph shown in the segment (e.g. "⏮", "⏯", "⏭").
    var glyph: String
    /// Label shown below the glyph.
    var label: String
    /// Shortcuts fired when this segment is committed.
    var shortcuts: [ShortcutDefinition]
}

// MARK: - AppProfile

/// The full configuration for a specific app (or the default profile).
struct AppProfile: Codable {
    var mode: Mode
    var scroll: ScrollConfig?
    var volume: VolumeConfig?
    var shortcuts: [ShortcutDefinition]?
    /// Custom radial menu segments. When set, replaces the default Scroll/Volume/Shortcuts layout.
    var overlaySegments: [AppOverlaySegment]?
}
