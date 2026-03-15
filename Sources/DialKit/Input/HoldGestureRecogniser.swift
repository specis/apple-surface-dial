// HoldGestureRecogniser.swift
// Detects press-and-hold gestures with a configurable time threshold.
//
// Default hold threshold: 200ms (configurable via ConfigStore holdThresholdMs).
// Emits either .tap (released before threshold) or .holdConfirmed (threshold reached).

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
final class HoldGestureRecogniser {
    // TODO: Accept a holdThreshold (TimeInterval, default 0.2s).
    // TODO: On pressDown(), start a timer; fire .holdConfirmed when it elapses.
    // TODO: On pressUp(), cancel the timer and emit .tap if timer hadn't fired.
    // TODO: Expose result via callback or async continuation.
}
