// InputInterpreter.swift
// Sits between the raw DialEvent stream and the ActionEventBus.
//
// Responsibilities:
//   - Accumulate raw rotation ticks; emit normalised rotated(steps:) events
//     debounced at ~16ms (60fps cadence).
//   - Detect press-and-hold via HoldGestureRecogniser (200ms threshold).
//   - Route rotation events to OverlayController while the menu is open,
//     rather than passing them to ModeRouter.
//   - Normalise delta: steps = rawDelta / (device.resolution / stepsPerRotation)
//
// Hold state machine:
//   Idle → [.pressed] → Held (start 200ms timer)
//   Held → [.released before timer] → Idle (emit .tap)
//   Held → [timer fires] → MenuOpen (emit .holdConfirmed)
//   MenuOpen → [.rotated] → emit .menuRotated(delta:) to OverlayController
//   MenuOpen → [.released] → emit .menuCommit(segmentIndex:) → Idle
//   MenuOpen → [3s inactivity] → emit .menuDismiss → Idle

import Foundation

// MARK: - InputInterpreter

/// Translates raw DialEvents into higher-level interpreted events.
final class InputInterpreter {
    // TODO: Accept a DialDevice and consume its eventStream.
    // TODO: Instantiate HoldGestureRecogniser with configured hold threshold.
    // TODO: Implement the hold state machine (Idle / Held / MenuOpen).
    // TODO: Emit normalised events onto ActionEventBus.
    // TODO: Implement 3-second inactivity timer for MenuOpen → Idle transition.
    // TODO: Store stepsPerRotation from ConfigStore (default 20).
}
