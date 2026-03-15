// AppWatcher.swift
// Monitors the active application and feeds bundle IDs to ModeRouter.
//
// Subscribes to NSWorkspace.didActivateApplicationNotification.

import AppKit
import Foundation

// MARK: - AppWatcher

/// Observes application activation events and notifies ModeRouter of bundle ID changes.
final class AppWatcher {
    // TODO: Subscribe to NSWorkspace.shared.notificationCenter
    //       for NSWorkspace.didActivateApplicationNotification.
    // TODO: Extract the bundle identifier from the notification's userInfo.
    // TODO: Forward the bundle ID to ModeRouter via a callback or direct reference.
    // TODO: Provide the current active bundle ID on demand.
}
