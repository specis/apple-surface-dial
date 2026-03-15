// ActionEventBus.swift
// NotificationCenter / AsyncStream bridge for interpreted dial actions.
//
// OverlayController and HapticEngine subscribe to this bus independently.
// Action handlers (ScrollAction, VolumeAction, ShortcutAction) post events here.

import Foundation

// MARK: - ActionEvent

/// Higher-level events produced by InputInterpreter and consumed by action handlers,
/// OverlayController, and HapticEngine.
enum ActionEvent {
    /// A normalised rotation step (positive = clockwise, negative = anticlockwise).
    case rotated(steps: Int)
    /// Short press — no hold detected.
    case tap
    /// Hold threshold confirmed — triggers overlay menu open.
    case holdConfirmed
    /// Rotation while the overlay menu is open — for segment selection.
    case menuRotated(delta: Int)
    /// Button released while menu is open — commits the highlighted segment.
    case menuCommit(segmentIndex: Int)
    /// Menu dismissed (via inactivity timeout or explicit cancel).
    case menuDismiss
}

// MARK: - ActionEventBus

/// Thin wrapper around NotificationCenter for posting and observing ActionEvents.
final class ActionEventBus {
    // TODO: Define a Notification.Name for each ActionEvent category or use a single name
    //       with the event encoded in userInfo.
    // TODO: Provide a post(_ event: ActionEvent) method.
    // TODO: Provide an observe() -> AsyncStream<ActionEvent> method for subscribers.
    // TODO: Consider thread-safety (all posts on main actor or a dedicated queue).
}
