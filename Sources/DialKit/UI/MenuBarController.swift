// MenuBarController.swift
// NSStatusItem and NSMenu for the DialKit menu bar presence.
//
// NSMenu structure:
//   Current mode        (disabled label — active mode name)
//   Active profile      (disabled label — app name or "Default")
//   ─────────────────────────────────────────────────────────
//   Mode submenu →      Scroll / Volume / Shortcuts (checkmark on active)
//   ─────────────────────────────────────────────────────────
//   Open Config File    → NSWorkspace.open(configFileURL)
//   Haptics: Enabled    (toggle; greyed out if device has no haptics)
//   ─────────────────────────────────────────────────────────
//   About DialKit
//   Quit
//
// No Dock icon: LSUIElement = true in Info.plist.
// Warning badge: shown when Accessibility is not granted and a shortcut profile is active.

import AppKit
import Foundation

// MARK: - MenuBarController

/// Manages the NSStatusItem and its associated NSMenu.
final class MenuBarController {
    // TODO: Create NSStatusItem with dial icon (SF Symbol "dial.medium" or template image).
    // TODO: Build the NSMenu with the structure described above.
    // TODO: Update the "Current mode" and "Active profile" labels when state changes.
    // TODO: Show/hide an Accessibility warning badge (e.g. "⚠" appended to icon).
    // TODO: Wire "Mode submenu" items to ModeRouter.currentMode changes.
    // TODO: Wire "Haptics: Enabled" toggle to HapticEngine.isSupported and ConfigStore.
    // TODO: Wire "Open Config File" to NSWorkspace.open with the config file URL.
}
