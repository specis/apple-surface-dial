// AppWatcher.swift
// Monitors the frontmost application and notifies ModeRouter of bundle ID changes.

import AppKit
import Foundation
import OSLog

// MARK: - AppWatcher

final class AppWatcher {

    /// The bundle identifier of the currently active application, if known.
    private(set) var activeBundleID: String?

    /// Called on the main thread whenever the active app changes.
    var onAppActivated: ((NSRunningApplication?) -> Void)?

    // MARK: - Init

    init() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(appActivated(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        // Seed with the app that is already in front.
        activeBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    // MARK: - Notification handler

    @objc private func appActivated(_ note: Notification) {
        let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        activeBundleID = app?.bundleIdentifier
        Log.appwatcher.info("App activated: \(app?.bundleIdentifier ?? "unknown") (\(app?.localizedName ?? "?")")
        onAppActivated?(app)
    }
}
