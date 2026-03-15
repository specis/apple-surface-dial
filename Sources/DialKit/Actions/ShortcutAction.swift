// ShortcutAction.swift
// Synthesises keystrokes via CGEvent.
//
// Requires Accessibility permission.
// On first use, prompt via AXIsProcessTrustedWithOptions(kAXTrustedCheckOptionPrompt: true).
// MenuBarController shows a warning badge if Accessibility is not granted
// and a shortcut profile is active.

import ApplicationServices
import CoreGraphics
import Foundation

// MARK: - ShortcutAction

/// Handles ActionEvent.rotated and ActionEvent.tap by synthesising CGEvent keystrokes.
final class ShortcutAction {
    // TODO: Check AXIsProcessTrusted() before attempting to post events.
    // TODO: If not trusted, call AXIsProcessTrustedWithOptions to prompt the user.
    // TODO: Map ShortcutDefinition (keys + modifiers) to CGEventFlags + CGKeyCode.
    // TODO: Post keyDown + keyUp pair via CGEvent.post(tap: .cghidEventTap).
    // TODO: Notify MenuBarController to show/hide the Accessibility warning badge.
}
