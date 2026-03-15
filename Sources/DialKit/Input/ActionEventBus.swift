// ActionEventBus.swift
// Distributes ActionEvents to multiple independent subscribers.
//
// Multiple components subscribe (OverlayController, HapticEngine, action handlers)
// and each receive every event independently via their own AsyncStream.
//
// Not thread-safe — post() and observe() must be called on the main thread.

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

/// Fan-out event bus. Each call to observe() returns an independent AsyncStream
/// that receives all future events posted to the bus.
final class ActionEventBus {

    private var continuations: [UUID: AsyncStream<ActionEvent>.Continuation] = [:]

    /// Delivers event to all current subscribers.
    func post(_ event: ActionEvent) {
        for continuation in continuations.values {
            continuation.yield(event)
        }
    }

    /// Returns a new AsyncStream that receives every future event.
    /// The stream ends when the bus is deallocated or the stream is cancelled.
    func observe() -> AsyncStream<ActionEvent> {
        let id = UUID()
        // AsyncStream calls the closure synchronously, so capturedCont is set
        // before the assignment on the next line.
        var capturedCont: AsyncStream<ActionEvent>.Continuation!
        let stream = AsyncStream<ActionEvent> { capturedCont = $0 }
        continuations[id] = capturedCont
        capturedCont.onTermination = { [weak self] _ in
            DispatchQueue.main.async { self?.continuations.removeValue(forKey: id) }
        }
        return stream
    }
}
