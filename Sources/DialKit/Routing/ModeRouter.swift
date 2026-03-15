// ModeRouter.swift
// Maps (active app bundle ID + current Mode) to the correct action handler.
//
// Lookup order:
//   1. App-specific profile for bundle ID + current mode → use its action config
//   2. Default profile for current mode
//   3. Built-in fallback (scroll)

import Foundation

// MARK: - ModeRouter

/// Routes ActionEvents to the appropriate action handler based on current app and mode.
final class ModeRouter {
    // TODO: Hold references to ScrollAction, VolumeAction, ShortcutAction.
    // TODO: Track currentMode (updated by overlay menu commit or manual menu bar selection).
    // TODO: Track activeBundleID (fed by AppWatcher).
    // TODO: Consult ConfigStore for app-specific profiles; fall back to default profile.
    // TODO: On ActionEvent.rotated(steps:) or .tap, dispatch to the resolved action handler.
    // TODO: On ActionEvent.menuCommit(segmentIndex:), update currentMode.
}
