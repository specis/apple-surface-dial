// RadialMenuModel.swift
// Data model backing the radial menu view.

import Foundation
import AppKit

// MARK: - SegmentAction

/// What happens when a radial menu segment is committed.
enum SegmentAction {
    /// Switch the active dial mode.
    case switchMode(Mode)
    /// Fire a set of shortcuts.
    case fireShortcuts([ShortcutDefinition])
}

// MARK: - RadialSegment

struct RadialSegment {
    let action: SegmentAction
    let glyph: String
    let label: String
    var liveValue: String?

    /// Convenience for the default mode-switching segments.
    static func forMode(_ mode: Mode) -> RadialSegment {
        RadialSegment(action: .switchMode(mode), glyph: mode.glyph, label: mode.displayName)
    }
}

// MARK: - RadialMenuModel

final class RadialMenuModel {

    // MARK: - Segments

    /// Current segments. Defaults to the three standard modes; replaced per app profile.
    var segments: [RadialSegment] = [
        .forMode(.scroll),
        .forMode(.volume),
        .forMode(.shortcut),
    ]

    // MARK: - Observable state

    /// Index of the segment currently highlighted by dial rotation.
    var highlightedIndex: Int = 0 {
        didSet { notifyView() }
    }

    /// Running dial rotation in degrees since the menu was opened.
    var cumulativeAngle: Double = 0 {
        didSet { notifyView() }
    }

    /// Label shown in the centre disc — active app profile name or "Default".
    var centreLabel: String = "Default" {
        didSet { notifyView() }
    }

    // MARK: - View reference

    weak var view: NSView?

    // MARK: - Helpers

    func reset() {
        highlightedIndex = 0
        cumulativeAngle  = 0
    }

    /// Update liveValue for a given mode (e.g. "72%" for volume).
    func setLiveValue(_ value: String?, for mode: Mode) {
        guard let idx = segments.firstIndex(where: {
            if case .switchMode(let m) = $0.action { return m == mode }
            return false
        }) else { return }
        segments[idx].liveValue = value
        notifyView()
    }

    private func notifyView() {
        DispatchQueue.main.async { [weak self] in
            self?.view?.needsDisplay = true
        }
    }
}
