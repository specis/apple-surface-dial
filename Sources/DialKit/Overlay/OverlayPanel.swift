// OverlayPanel.swift
// NSPanel subclass configured as a non-activating, transparent floating window.
//
// Panel configuration:
//   level              = .screenSaver  (configurable; shows above full-screen apps)
//   styleMask          = .nonactivatingPanel
//   ignoresMouseEvents = true
//   isOpaque           = false
//   backgroundColor    = .clear
//   hasShadow          = false
//
// Content is wrapped in NSVisualEffectView:
//   material     = .hudWindow
//   blendingMode = .behindWindow
//   state        = .active

import AppKit

// MARK: - OverlayPanel

/// Transparent, non-activating NSPanel that hosts the RadialMenuView.
final class OverlayPanel: NSPanel {
    // TODO: Override init to apply all panel configuration flags.
    // TODO: Add NSVisualEffectView as the content view.
    // TODO: Add RadialMenuView as a subview of the effect view.
    // TODO: Expose a method to update the window level from OverlayConfig.windowLevel.
}
