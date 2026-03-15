// ModeRouter.swift
// Resolves the active app profile and dispatches ActionEvents to the right handler.
//
// Lookup order:
//   1. appProfiles[activeBundleID] if present
//   2. config.defaultProfile

import Foundation
import OSLog

// MARK: - ModeRouter

final class ModeRouter {

    // MARK: - Dependencies

    private let scroll:      ScrollAction
    private let volume:      VolumeAction
    private let shortcut:    ShortcutAction
    private let configStore: ConfigStore

    // MARK: - State

    private(set) var currentMode: Mode
    /// The mode the user explicitly chose — persists across app switches for unprofilesd apps.
    private var userSelectedMode: Mode
    private var activeBundleID: String?

    /// Called on the main thread when the active mode changes.
    var onModeChanged: ((Mode) -> Void)?

    // MARK: - Init

    init(scroll: ScrollAction, volume: VolumeAction, shortcut: ShortcutAction,
         configStore: ConfigStore) {
        self.scroll      = scroll
        self.volume      = volume
        self.shortcut    = shortcut
        self.configStore = configStore
        self.currentMode      = configStore.config.defaultProfile.mode
        self.userSelectedMode = configStore.config.defaultProfile.mode
    }

    // MARK: - Public

    /// Called directly from the main event loop for each ActionEvent.
    func handle(_ event: ActionEvent) {
        switch event {
        case .rotated(let steps):
            dispatchRotation(steps: steps)
        case .tap:
            dispatchTap()
        default:
            break
        }
    }

    /// Explicitly set the current mode (e.g. from overlay commit or menu bar).
    func setMode(_ mode: Mode) {
        Log.router.info("Mode → \(mode.displayName)")
        currentMode      = mode
        userSelectedMode = mode   // user intent — survives app switches
        onModeChanged?(mode)
    }

    /// Update the active bundle ID (called by AppWatcher).
    /// Auto-switches mode if the app profile specifies a different default mode.
    func setActiveBundleID(_ bundleID: String?) {
        activeBundleID = bundleID

        // Only auto-switch mode when the app has an explicit profile that specifies one.
        // The default profile's mode is only used at startup — it should not override a
        // user-selected mode every time the active app changes.
        if let id = bundleID, let appProfile = configStore.config.appProfiles[id] {
            // Temporarily apply the app's profile mode without touching userSelectedMode.
            Log.router.info("Active app: \(id) — profile mode: \(appProfile.mode.displayName)")
            if currentMode != appProfile.mode {
                currentMode = appProfile.mode
                onModeChanged?(appProfile.mode)
            }
        } else {
            // No profile — revert to whatever the user last explicitly chose.
            Log.router.info("Active app: \(bundleID ?? "none") — no profile, reverting to user mode: \(self.userSelectedMode.displayName)")
            if currentMode != userSelectedMode {
                currentMode = userSelectedMode
                onModeChanged?(userSelectedMode)
            }
        }
    }

    // MARK: - Event dispatch

    private func dispatchRotation(steps: Int) {
        let profile = resolvedProfile()
        switch currentMode {
        case .scroll:
            applyScrollConfig(profile.scroll ?? configStore.config.defaultProfile.scroll)
            Log.router.debug("Dispatch scroll \(steps) step(s)")
            scroll.scroll(steps: steps)

        case .volume:
            applyVolumeConfig(profile.volume ?? configStore.config.defaultProfile.volume)
            Log.router.debug("Dispatch volume \(steps > 0 ? "+" : "")\(steps) step(s)")
            volume.adjust(steps: steps)

        case .shortcut:
            let direction = steps > 0 ? "rotate_cw" : "rotate_ccw"
            let defs = (profile.shortcuts ?? []).filter {
                $0.action == "rotate" || $0.action == direction
            }
            Log.router.debug("Dispatch shortcut \(direction) — \(defs.count) binding(s)")
            for _ in 0 ..< abs(steps) {
                for def in defs { shortcut.fire(definition: def) }
            }
        }
    }

    private func dispatchTap() {
        guard currentMode == .shortcut else { return }
        let profile = resolvedProfile()
        let defs = (profile.shortcuts ?? []).filter { $0.action == "press" }
        Log.router.debug("Dispatch shortcut press — \(defs.count) binding(s)")
        for def in defs { shortcut.fire(definition: def) }
    }

    // MARK: - Config application

    private func applyScrollConfig(_ cfg: ScrollConfig?) {
        guard let cfg else { return }
        scroll.isNaturalScrolling = cfg.direction == "natural"
        scroll.linesPerStep = Int32(max(1, (3.0 * cfg.multiplier).rounded()))
    }

    private func applyVolumeConfig(_ cfg: VolumeConfig?) {
        guard let cfg else { return }
        volume.stepSize = Float(cfg.stepSize) / 100.0
    }

    // MARK: - Profile resolution

    private func resolvedProfile() -> AppProfile {
        if let id = activeBundleID,
           let profile = configStore.config.appProfiles[id] {
            return profile
        }
        return configStore.config.defaultProfile
    }
}
