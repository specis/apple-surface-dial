// OverlayController.swift
// Show/hide state machine for the radial overlay menu.

import AppKit
import Foundation
import OSLog

// MARK: - OverlayController

final class OverlayController {

    // MARK: - Dependencies

    private let panel: OverlayPanel
    let model: RadialMenuModel
    private let config: OverlayConfig

    /// Called when the user commits a segment selection.
    var onSegmentCommitted: ((SegmentAction) -> Void)?

    // MARK: - State

    private var isVisible = false
    private var cursorPositionAtPress: CGPoint = .zero

    // MARK: - Init

    init(config: OverlayConfig = .default) {
        self.config = config
        self.model  = RadialMenuModel()
        self.panel  = OverlayPanel()

        panel.menuView.model = model
        panel.applyWindowLevel(config.windowLevel)
    }

    // MARK: - Public API

    /// Wire the controller to an ActionEventBus. Call once after init.
    func subscribe(to bus: ActionEventBus) {
        let stream = bus.observe()   // called synchronously on the main thread
        Task { [weak self] in
            for await event in stream {
                guard let self else { return }
                await MainActor.run { self.handle(event) }
            }
        }
    }

    /// Replace the overlay segments for the active app profile.
    /// Pass nil to restore the default Scroll / Volume / Shortcuts layout.
    func setSegments(_ appSegments: [AppOverlaySegment]?, centreLabel: String) {
        if let custom = appSegments, !custom.isEmpty {
            model.segments = custom.map { seg in
                RadialSegment(
                    action: .fireShortcuts(seg.shortcuts),
                    glyph:  seg.glyph,
                    label:  seg.label
                )
            }
        } else {
            model.segments = [.forMode(.scroll), .forMode(.volume), .forMode(.shortcut)]
        }
        model.centreLabel = centreLabel
        model.reset()
    }

    func show() {
        guard config.enabled, !isVisible else { return }
        isVisible = true
        model.reset()
        positionPanel()
        Log.overlay.info("Overlay shown at (\(Int(self.panel.frame.origin.x)), \(Int(self.panel.frame.origin.y)))")
        panel.orderFrontRegardless()
        panel.menuView.animateAppear()
    }

    func hide() {
        guard isVisible else { return }
        isVisible = false
        Log.overlay.info("Overlay hidden")
        panel.menuView.animateDismiss { [weak self] in
            self?.panel.orderOut(nil)
        }
    }

    // MARK: - Event handling

    private func handle(_ event: ActionEvent) {
        switch event {
        case .holdConfirmed:
            cursorPositionAtPress = NSEvent.mouseLocation
            show()

        case .menuRotated(let delta):
            guard isVisible else { return }
            // Update cumulative angle for progress arc
            let degreesPerTick = 360.0 / 36.0  // 36 ticks/rev default; close enough for display
            model.cumulativeAngle -= Double(delta) * degreesPerTick
            // Map current angle to segment
            model.highlightedIndex = segmentIndex(for: model.cumulativeAngle)

        case .menuCommit(let index):
            guard index < model.segments.count else { hide(); return }
            let action = model.segments[index].action
            Log.overlay.info("Segment committed: \(index)")
            hide()
            onSegmentCommitted?(action)

        case .menuDismiss:
            hide()

        default:
            break
        }
    }

    // MARK: - Segment math

    private func segmentIndex(for angleDeg: Double) -> Int {
        let count   = model.segments.count
        let arcSize = 360.0 / Double(count)
        let normalised = angleDeg.truncatingRemainder(dividingBy: 360)
        let positive = normalised < 0 ? normalised + 360 : normalised
        let raw = Int(positive / arcSize) % count
        // Segments are drawn counterclockwise in CG space; mirror the index so
        // clockwise physical rotation selects segments in clockwise visual order.
        return (count - raw) % count
    }

    // MARK: - Positioning

    private func positionPanel() {
        let size = panel.frame.size

        switch config.position {
        case .cursor:
            let origin = clampedOrigin(
                preferred: CGPoint(
                    x: cursorPositionAtPress.x - size.width  / 2,
                    y: cursorPositionAtPress.y - size.height / 2
                ),
                size: size
            )
            panel.setFrameOrigin(origin)

        case .fixedCorner:
            guard let screen = NSScreen.main else { return }
            let visFrame = screen.visibleFrame
            let inset    = config.cornerInset
            let origin: CGPoint

            switch config.corner {
            case .bottomRight:
                origin = CGPoint(x: visFrame.maxX - size.width  - inset,
                                 y: visFrame.minY + inset)
            case .bottomLeft:
                origin = CGPoint(x: visFrame.minX + inset,
                                 y: visFrame.minY + inset)
            case .topRight:
                origin = CGPoint(x: visFrame.maxX - size.width  - inset,
                                 y: visFrame.maxY - size.height - inset)
            case .topLeft:
                origin = CGPoint(x: visFrame.minX + inset,
                                 y: visFrame.maxY - size.height - inset)
            }
            panel.setFrameOrigin(origin)
        }
    }

    /// Clamps an origin so the panel stays fully on-screen.
    private func clampedOrigin(preferred: CGPoint, size: CGSize) -> CGPoint {
        // Find the screen that contains the cursor.
        let screen = NSScreen.screens.first {
            $0.frame.contains(cursorPositionAtPress)
        } ?? NSScreen.main ?? NSScreen.screens[0]

        let sf = screen.frame
        return CGPoint(
            x: min(max(preferred.x, sf.minX), sf.maxX - size.width),
            y: min(max(preferred.y, sf.minY), sf.maxY - size.height)
        )
    }
}

// MARK: - OverlayConfig default

extension OverlayConfig {
    static let `default` = OverlayConfig(
        enabled:             true,
        position:            .cursor,
        corner:              .bottomRight,
        cornerInset:         40,
        windowLevel:         "screenSaver",
        dismissAfterSeconds: 3.0,
        showModeChanges:     true,
        showShortcutLabels:  true
    )
}
