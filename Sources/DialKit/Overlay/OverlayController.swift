// OverlayController.swift
// State machine that controls overlay visibility and positioning.
//
// Subscribes to ActionEventBus for:
//   .holdConfirmed  → show()
//   .menuRotated    → update highlighted segment in RadialMenuModel
//   .menuCommit     → commit mode change, hide()
//   .menuDismiss    → hide() (inactivity timeout)
//
// Positioning:
//   cursor mode      — NSEvent.mouseLocation at time of press, clamped to screen
//   fixedCorner mode — calculated from OverlayConfig.corner + cornerInset
//
// Multi-monitor: use NSScreen.screens to find the screen containing the position.

import AppKit
import Foundation

// MARK: - OverlayController

/// Manages the lifecycle and screen position of the radial menu overlay.
final class OverlayController {
    // TODO: Hold a reference to OverlayPanel and RadialMenuModel.
    // TODO: Subscribe to ActionEventBus.
    // TODO: Implement show() — position panel, trigger appear animation, start inactivity timer.
    // TODO: Implement hide() — trigger dismiss animation, then orderOut after animation.
    // TODO: Implement positionPanel(for screen: NSScreen) respecting OverlayConfig.position.
    // TODO: Clamp panel frame so menu never bleeds off screen edges (diameter ~290pt).
    // TODO: Reset inactivity timer on each .menuRotated event.
}
