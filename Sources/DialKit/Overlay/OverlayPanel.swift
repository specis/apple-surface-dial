// OverlayPanel.swift
// Non-activating, transparent NSPanel that hosts RadialMenuView.

import AppKit

// MARK: - OverlayPanel

final class OverlayPanel: NSPanel {

    let menuView: RadialMenuView

    init(size: CGFloat = 290) {
        let frame = NSRect(x: 0, y: 0, width: size, height: size)
        menuView = RadialMenuView(frame: NSRect(x: 0, y: 0, width: size, height: size))

        super.init(
            contentRect: frame,
            styleMask:   [.nonactivatingPanel, .borderless],
            backing:     .buffered,
            defer:       false
        )

        level              = .screenSaver
        ignoresMouseEvents = true
        isOpaque           = false
        backgroundColor    = .clear
        hasShadow          = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Frosted glass background
        let effect = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: size, height: size))
        effect.material     = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state        = .active
        effect.wantsLayer   = true
        effect.layer?.cornerRadius = size / 2
        effect.layer?.masksToBounds = true

        effect.addSubview(menuView)
        contentView = effect
    }

    /// Update the window level from a config string.
    func applyWindowLevel(_ levelString: String) {
        switch levelString {
        case "floating":    level = .floating
        case "normal":      level = .normal
        default:            level = .screenSaver
        }
    }
}
