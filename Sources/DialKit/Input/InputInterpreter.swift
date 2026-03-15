// InputInterpreter.swift
// Sits between the raw DialEvent stream and the ActionEventBus.
//
// Hold state machine:
//   Idle     → [.pressed]              → Held (start 200ms timer)
//   Held     → [.released]             → Idle (emit .tap)
//   Held     → [timer fires]           → MenuOpen (emit .holdConfirmed)
//   MenuOpen → [.rotated]              → emit .menuRotated(delta:)
//   MenuOpen → [.released]             → emit .menuCommit(segmentIndex:) → Idle
//   MenuOpen → [3s inactivity]         → emit .menuDismiss → Idle
//
// Tick accumulator: fractional steps are kept across events so that slow
// rotation still registers — steps emit only when a full threshold is crossed.

import Foundation

// MARK: - InputInterpreter

/// Translates raw DialEvents into higher-level ActionEvents.
/// Not thread-safe — all state mutations happen on the main thread via MainActor.run.
final class InputInterpreter {

    // MARK: - Configuration

    /// Degrees of physical rotation that produce one logical step.
    /// Lower = more sensitive. Default 5° → 72 steps per full revolution.
    var degreesPerStep: Double = 5.0

    /// Computed from device.resolution — automatically correct regardless of whether
    /// the device reports 360 or 3600 ticks/revolution.
    private var ticksPerStep: Int {
        max(1, Int((Double(device.resolution) / 360.0) * degreesPerStep))
    }

    // MARK: - Private state

    private let device: any DialDevice
    private let bus: ActionEventBus
    private let holdRecogniser: HoldGestureRecogniser

    private enum State { case idle, held, menuOpen }
    private var state: State = .idle

    /// Accumulated raw ticks waiting to complete a full step.
    private var tickAccumulator: Int = 0
    /// Accumulated dial rotation (degrees) since the menu opened — used for
    /// mapping rotation to segment index on commit.
    private var menuAngleDeg: Double = 0

    private var inactivityTimer: DispatchWorkItem?

    // MARK: - init

    init(device: any DialDevice, bus: ActionEventBus, holdThreshold: TimeInterval = 0.2) {
        self.device = device
        self.bus = bus
        holdRecogniser = HoldGestureRecogniser(threshold: holdThreshold)
        holdRecogniser.onResult = { [weak self] result in
            // Timer fires on DispatchQueue.main — state is safe to mutate here.
            self?.handleHoldResult(result)
        }
    }

    // MARK: - Public

    /// Begins consuming the device's event stream. Safe to call once after init.
    func start() {
        Task { [weak self] in
            guard let self else { return }
            for await event in self.device.eventStream {
                await MainActor.run { [weak self] in self?.handle(event) }
            }
        }
    }

    // MARK: - Raw event dispatch

    private func handle(_ event: DialEvent) {
        switch event {
        case .connected, .disconnected:
            break  // DeviceManager will handle these later.
        case .pressed:
            handlePressed()
        case .released:
            handleReleased()
        case .rotated(let delta):
            handleRotated(delta: delta)
        }
    }

    // MARK: - State machine

    private func handlePressed() {
        guard state == .idle else { return }
        state = .held
        holdRecogniser.pressDown()
    }

    private func handleReleased() {
        switch state {
        case .idle:
            break
        case .held:
            // pressUp() will trigger onResult(.tap) synchronously (timer not yet fired)
            // or do nothing if hold was already confirmed.
            holdRecogniser.pressUp()
            state = .idle
        case .menuOpen:
            let index = segmentIndex(for: menuAngleDeg, segmentCount: 3)
            bus.post(.menuCommit(segmentIndex: index))
            state = .idle
            cancelInactivityTimer()
        }
    }

    private func handleRotated(delta: Int) {
        switch state {
        case .idle, .held:
            // Accumulate ticks; emit once a full step threshold is crossed.
            tickAccumulator += delta
            let steps = tickAccumulator / ticksPerStep
            if steps != 0 {
                tickAccumulator -= steps * ticksPerStep
                bus.post(.rotated(steps: steps))
            }
        case .menuOpen:
            menuAngleDeg += Double(delta) / Double(device.resolution) * 360.0
            bus.post(.menuRotated(delta: delta))
            resetInactivityTimer()
        }
    }

    private func handleHoldResult(_ result: HoldGestureResult) {
        switch result {
        case .tap:
            state = .idle
            bus.post(.tap)
        case .holdConfirmed:
            state = .menuOpen
            menuAngleDeg = 0
            tickAccumulator = 0
            bus.post(.holdConfirmed)
            resetInactivityTimer()
        }
    }

    // MARK: - Helpers

    /// Maps a cumulative rotation angle to a segment index.
    /// Positive angle = clockwise; segments are equal-width arcs.
    private func segmentIndex(for angleDeg: Double, segmentCount: Int) -> Int {
        let arcSize = 360.0 / Double(segmentCount)
        let normalised = angleDeg.truncatingRemainder(dividingBy: 360.0)
        let positive = normalised < 0 ? normalised + 360.0 : normalised
        return Int(positive / arcSize) % segmentCount
    }

    private func resetInactivityTimer() {
        cancelInactivityTimer()
        let item = DispatchWorkItem { [weak self] in
            guard let self, self.state == .menuOpen else { return }
            self.state = .idle
            self.bus.post(.menuDismiss)
        }
        inactivityTimer = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: item)
    }

    private func cancelInactivityTimer() {
        inactivityTimer?.cancel()
        inactivityTimer = nil
    }
}
