// ConfigStore.swift
// Loads, saves, and watches profiles.json at ~/.config/dialkit/profiles.json.
//
// Uses DispatchSource file watcher so changes take effect without an app restart.

import Foundation

// MARK: - DialKitConfig

/// Top-level decoded representation of profiles.json.
struct DialKitConfig: Codable {
    var version: Int
    var holdThresholdMs: Int
    var stepsPerRotation: Int
    var overlay: OverlayConfig
    var haptics: HapticConfig
    var defaultProfile: AppProfile
    /// Keyed by bundle identifier (e.g. "com.adobe.Photoshop").
    var appProfiles: [String: AppProfile]
}

// MARK: - ConfigStore

/// Singleton-style store that exposes the current config and notifies observers on change.
final class ConfigStore {
    // TODO: Determine config file URL (~/.config/dialkit/profiles.json).
    // TODO: Load and decode DialKitConfig from JSON on init; write defaults if absent.
    // TODO: Set up a DispatchSource VNODE watcher on the config file for live reload.
    // TODO: Expose the current DialKitConfig value.
    // TODO: Provide a save() method that encodes and writes the current config.
    // TODO: Notify interested parties (ModeRouter, OverlayController, HapticEngine)
    //       when the config changes (via NotificationCenter or callback).
}
