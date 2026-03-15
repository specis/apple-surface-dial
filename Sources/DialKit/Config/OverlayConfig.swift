// OverlayConfig.swift
// Overlay position strategy and display settings.
//
// Stored in profiles.json under "overlay".

import Foundation

// MARK: - Corner

enum Corner: String, Codable {
    case topLeft, topRight, bottomLeft, bottomRight
}

// MARK: - OverlayPosition

enum OverlayPosition: String, Codable {
    /// Show the overlay centred on the cursor position at the time of the press.
    case cursor
    /// Show the overlay at a fixed screen corner with an inset.
    case fixedCorner
}

// MARK: - OverlayConfig

/// Controls where and how the radial menu overlay appears.
struct OverlayConfig: Codable {
    var enabled: Bool
    var position: OverlayPosition
    /// Used when position == .fixedCorner.
    var corner: Corner
    /// Inset (in points) from the screen corner. Default 40pt.
    var cornerInset: CGFloat
    /// NSWindow.Level string ("screenSaver", "floating", etc.).
    var windowLevel: String
    /// Seconds of inactivity before the menu auto-dismisses.
    var dismissAfterSeconds: Double
    var showModeChanges: Bool
    var showShortcutLabels: Bool
}
