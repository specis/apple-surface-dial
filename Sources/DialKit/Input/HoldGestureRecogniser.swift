// HoldGestureRecogniser.swift
// Detects press-and-hold gestures with a configurable time threshold.
//
// Default hold threshold: 200ms (configurable via ConfigStore holdThresholdMs).
// Emits either .tap (released before threshold) or .holdConfirmed (threshold reached).
//
// All methods must be called on the main thread. The onResult callback fires
// on the main thread (timer dispatches to DispatchQueue.main).

import Foundation

// MARK: - HoldGestureResult

enum HoldGestureResult {
    /// Button was released before the hold threshold — treat as a tap.
    case tap
    /// Hold threshold elapsed before release — a long press is confirmed.
    case holdConfirmed
}

// MARK: - HoldGestureRecogniser

/// Manages the timer that distinguishes a tap from a hold.
/// Not thread-safe — all calls must be from the main thread.
final class HoldGestureRecogniser {

    var threshold: TimeInterval
    /// Called exactly once per press-down / press-up cycle with the resolved result.
    var onResult: ((HoldGestureResult) -> Void)?

    private var pendingWork: DispatchWorkItem?
    /// Guards against emitting both .tap and .holdConfirmed in the same cycle
    /// (possible if cancel() races with a workItem that already started).
    private var resultEmitted = false

    init(threshold: TimeInterval = 0.2) {
        self.threshold = threshold
    }

    /// Call when the button is pressed. Starts the hold timer.
    func pressDown() {
        resultEmitted = false
        let item = DispatchWorkItem { [weak self] in
            guard let self, !self.resultEmitted else { return }
            self.resultEmitted = true
            self.pendingWork = nil
            self.onResult?(.holdConfirmed)
        }
        pendingWork = item
        DispatchQueue.main.asyncAfter(deadline: .now() + threshold, execute: item)
    }

    /// Call when the button is released. Cancels the hold timer if still pending
    /// and emits .tap; does nothing if .holdConfirmed was already emitted.
    func pressUp() {
        pendingWork?.cancel()
        pendingWork = nil
        guard !resultEmitted else { return }
        resultEmitted = true
        onResult?(.tap)
    }
}
