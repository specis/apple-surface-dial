// NullHapticEngine.swift
// No-op HapticEngine for devices that do not support haptic output.
//
// Eliminates nil-checks throughout the codebase: every code path uses
// the same HapticEngine interface regardless of device capability.

import Foundation

// MARK: - NullHapticEngine

/// No-op HapticEngine. isSupported = false. All methods are silent no-ops.
final class NullHapticEngine: HapticEngine {
    let isSupported = false

    func play(_ event: HapticEvent) async {
        // Intentional no-op.
    }

    func configure(with config: HapticConfig) {
        // Intentional no-op.
    }
}
