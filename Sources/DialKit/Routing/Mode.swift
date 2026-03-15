// Mode.swift
// Enum representing the three dial operating modes.

import Foundation

// MARK: - Mode

/// The active operating mode determines which action handler processes dial input.
enum Mode: String, Codable, CaseIterable {
    case scroll
    case volume
    case shortcut

    /// Human-readable display name shown in the overlay and menu bar.
    var displayName: String {
        switch self {
        case .scroll:   return "Scroll"
        case .volume:   return "Volume"
        case .shortcut: return "Shortcuts"
        }
    }

    /// SF Symbol or glyph displayed in the radial menu segment.
    var glyph: String {
        switch self {
        case .scroll:   return "⇅"
        case .volume:   return "▶"
        case .shortcut: return "⌘"
        }
    }
}
