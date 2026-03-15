// ValueHUDController.swift
// Small frosted-glass HUD that shows a live value (e.g. "▶  72%") briefly
// after each dial rotation, then fades out after 1.5 s of inactivity.
//
// Positioned at the bottom-centre of the main screen, clear of the Dock.

import AppKit

// MARK: - ValueHUDController

final class ValueHUDController {

    // MARK: - UI

    private let panel: NSPanel
    private let glyphField: NSTextField
    private let valueField: NSTextField
    private let barTrack: NSView
    private let barFill: NSView

    // MARK: - State

    private var dismissTimer: DispatchWorkItem?
    private var isVisible = false

    // MARK: - Init

    init() {
        // Panel
        panel = NSPanel(
            contentRect:  NSRect(x: 0, y: 0, width: 200, height: 64),
            styleMask:    [.nonactivatingPanel, .fullSizeContentView],
            backing:      .buffered,
            defer:        false
        )
        panel.level               = .screenSaver
        panel.isOpaque            = false
        panel.backgroundColor     = .clear
        panel.hasShadow           = true
        panel.ignoresMouseEvents  = true
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior  = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        // Frosted background
        let effect = NSVisualEffectView(frame: panel.contentView!.bounds)
        effect.autoresizingMask   = [.width, .height]
        effect.material           = .hudWindow
        effect.blendingMode       = .behindWindow
        effect.state              = .active
        effect.wantsLayer         = true
        effect.layer?.cornerRadius = 14
        effect.layer?.masksToBounds = true
        panel.contentView!.addSubview(effect)

        // Glyph (mode icon)
        glyphField = NSTextField(labelWithString: "")
        glyphField.font      = .systemFont(ofSize: 20)
        glyphField.textColor = NSColor.labelColor
        glyphField.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(glyphField)

        // Value text
        valueField = NSTextField(labelWithString: "")
        valueField.font      = .monospacedDigitSystemFont(ofSize: 22, weight: .semibold)
        valueField.textColor = NSColor.labelColor
        valueField.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(valueField)

        // Progress bar track
        barTrack = NSView()
        barTrack.wantsLayer = true
        barTrack.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.15).cgColor
        barTrack.layer?.cornerRadius = 2
        barTrack.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(barTrack)

        // Progress bar fill
        barFill = NSView()
        barFill.wantsLayer = true
        barFill.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.6).cgColor
        barFill.layer?.cornerRadius = 2
        barFill.translatesAutoresizingMaskIntoConstraints = false
        barTrack.addSubview(barFill)

        // Layout
        NSLayoutConstraint.activate([
            glyphField.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 16),
            glyphField.centerYAnchor.constraint(equalTo: effect.centerYAnchor, constant: -6),

            valueField.leadingAnchor.constraint(equalTo: glyphField.trailingAnchor, constant: 8),
            valueField.centerYAnchor.constraint(equalTo: glyphField.centerYAnchor),
            valueField.trailingAnchor.constraint(lessThanOrEqualTo: effect.trailingAnchor, constant: -16),

            barTrack.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 16),
            barTrack.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -16),
            barTrack.bottomAnchor.constraint(equalTo: effect.bottomAnchor, constant: -12),
            barTrack.heightAnchor.constraint(equalToConstant: 4),

            barFill.leadingAnchor.constraint(equalTo: barTrack.leadingAnchor),
            barFill.topAnchor.constraint(equalTo: barTrack.topAnchor),
            barFill.bottomAnchor.constraint(equalTo: barTrack.bottomAnchor),
        ])
    }

    // MARK: - Public

    /// Show the HUD with a glyph, text value, and 0–1 fill fraction.
    func show(glyph: String, value: String, fraction: Float) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.glyphField.stringValue = glyph
            self.valueField.stringValue = value
            self.updateBar(fraction: Double(fraction))
            self.schedulePosition()

            if !self.isVisible {
                self.isVisible = true
                self.panel.alphaValue = 0
                self.panel.orderFrontRegardless()
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.12
                    self.panel.animator().alphaValue = 1
                }
            }

            self.scheduleDismiss()
        }
    }

    // MARK: - Private

    private func updateBar(fraction: Double) {
        let clamped = Double(max(0, min(1, fraction)))
        // Defer constraint update until layout is known
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let trackWidth = self.barTrack.bounds.width
            // Remove old width constraint on barFill if present
            self.barFill.constraints.filter { $0.firstAttribute == .width }.forEach {
                self.barFill.removeConstraint($0)
            }
            let fill = self.barFill.widthAnchor.constraint(equalToConstant: trackWidth * clamped)
            fill.isActive = true
        }
    }

    private func schedulePosition() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size    = panel.frame.size
        let x       = visible.midX - size.width / 2
        let y       = visible.minY + 40
        panel.setFrameOrigin(CGPoint(x: x, y: y))
    }

    private func scheduleDismiss() {
        dismissTimer?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.dismiss() }
        dismissTimer = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: item)
    }

    private func dismiss() {
        guard isVisible else { return }
        isVisible = false
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.panel.orderOut(nil)
        })
    }
}
