// RadialMenuView.swift
// CoreGraphics-based NSView that draws the radial menu.
//
// Drawing layers (back to front):
//   1. Frosted glass background — handled by NSVisualEffectView (parent)
//   2. Segment fills — arcs clipped to annular ring (outer r=130pt, inner r=48pt)
//   3. Segment divider lines — radial lines from inner to outer radius
//   4. Outer progress arc — thin ring showing rotation amount since menu opened
//   5. Segment labels — glyph + mode name + live value (e.g. "72%")
//   6. Centre disc — active app profile name
//   7. Outer ring border — 1pt stroke
//
// Segment geometry (3 equal segments = 120° each):
//   Segment 0 (top):   270°–30°   — drawn at the top
//   Segment 1 (right):  30°–150°
//   Segment 2 (left):  150°–270°
//
// Highlighted segment fill: accent colour #534AB7; others: neutral.
//
// Animations (NSAnimationContext + CABasicAnimation, wantsLayer = true):
//   Appear:  scale 0.6→1.0, opacity 0→1, 150ms ease-out
//   Highlight change: fill crossfade, 80ms
//   Dismiss: scale 1.0→0.8, opacity 1→0, 120ms ease-in

import AppKit

// MARK: - RadialMenuView

/// Draws the radial menu using CoreGraphics. No Metal or SceneKit required.
final class RadialMenuView: NSView {
    // TODO: Accept a RadialMenuModel and observe it for changes.
    // TODO: Implement draw(_ dirtyRect:) with all seven layers.
    // TODO: Set wantsLayer = true to enable CABasicAnimation.
    // TODO: Implement appear() and dismiss() animation helpers.
    // TODO: Define accent colour constant (#534AB7) for highlighted segment.
}
