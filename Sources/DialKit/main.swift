// main.swift
// DialKit entry point.
// Wires the full pipeline: DeviceManager → InputInterpreter → ActionEventBus → router / overlay / haptics.

import AppKit
import ApplicationServices
import OSLog

private let log = Logger(subsystem: "com.dialkit", category: "main")

// MARK: - Accessibility permission

let axOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
let isTrusted = AXIsProcessTrustedWithOptions(axOptions as CFDictionary)
if isTrusted {
    log.info("Accessibility: granted")
} else {
    log.warning("Accessibility: NOT granted — shortcuts will not work. Grant access in System Settings → Privacy & Security → Accessibility, then restart.")
}

// MARK: - Device discovery

let deviceManager = DeviceManager()
do {
    try deviceManager.start()
} catch {
    fputs("DialKit: no device could be initialised — \(error.localizedDescription)\n" +
          "Check Input Monitoring in System Settings → Privacy & Security.\n", stderr)
    exit(1)
}

let primaryDevice = deviceManager.primaryDevice

// MARK: - Bootstrap

let configStore       = ConfigStore()
let preferencesWindow = PreferencesWindowController(configStore: configStore)
let bus               = ActionEventBus()
let scroll       = ScrollAction()
let volume       = VolumeAction()
let shortcut     = ShortcutAction()
let haptics      = deviceManager.hapticEngine
let interpreter  = InputInterpreter(device: primaryDevice, bus: bus,
                                    holdThreshold: Double(configStore.config.holdThresholdMs) / 1000.0)
interpreter.degreesPerStep = 360.0 / Double(configStore.config.stepsPerRotation)
let router       = ModeRouter(scroll: scroll, volume: volume, shortcut: shortcut,
                               configStore: configStore)
let appWatcher   = AppWatcher()
let overlay      = OverlayController(config: configStore.config.overlay)
let valueHUD     = ValueHUDController()
let menuBar      = MenuBarController(accessibilityGranted: isTrusted)

// MARK: - Wiring

// Device connect/disconnect → menu bar badge
interpreter.onDeviceConnected = {
    log.info("Dial connected")
    menuBar.setAccessibilityGranted(isTrusted)   // clears any disconnect badge
}
interpreter.onDeviceDisconnected = {
    log.warning("Dial disconnected — waiting for reconnect")
    // Reuse the warning badge to signal disconnected state
    menuBar.setDisconnected()
}

// AppWatcher → ModeRouter + overlay segments + profile HUD
appWatcher.onAppActivated = { app in
    let bundleID = app?.bundleIdentifier
    router.setActiveBundleID(bundleID)

    // Swap overlay segments to match the active app profile.
    let profile  = bundleID.flatMap { configStore.config.appProfiles[$0] }
    let appName  = app?.localizedName ?? "Default"
    overlay.setSegments(profile?.overlaySegments, centreLabel: appName)

    // Show a brief HUD with the app name and active mode.
    if configStore.config.overlay.enabled && configStore.config.overlay.showModeChanges {
        let mode = router.currentMode
        valueHUD.show(glyph: mode.glyph, value: appName, fraction: 1.0)
    }
}
router.setActiveBundleID(appWatcher.activeBundleID)

// Overlay commit → ModeRouter or ShortcutAction
overlay.onSegmentCommitted = { action in
    switch action {
    case .switchMode(let mode):
        router.setMode(mode)
    case .fireShortcuts(let defs):
        for def in defs { shortcut.fire(definition: def) }
    }
}

// ModeRouter mode change → MenuBar
router.onModeChanged = { mode in
    menuBar.currentMode = mode
}

// MenuBar manual mode pick → ModeRouter
menuBar.onModeChange = { mode in
    router.setMode(mode)
}

// Shortcut fired → HUD + haptic
shortcut.onShortcutFired = { label in
    valueHUD.show(glyph: "⌘", value: label, fraction: 1.0)
    Task { await haptics.play(.shortcutFired) }
}

// Volume live value → HUD + overlay model + boundary haptic
volume.onVolumeChanged = { level, hitBoundary in
    let pct = Int(level * 100)
    overlay.model.setLiveValue("\(pct)%", for: .volume)
    valueHUD.show(glyph: "▶", value: "\(pct)%", fraction: level)
    if hitBoundary {
        Log.volume.info("Volume boundary hit at \(pct)%")
        Task { await haptics.play(.boundaryReached) }
    } else {
        Log.volume.debug("Volume: \(pct)%")
    }
}

menuBar.currentMode      = router.currentMode
menuBar.hapticsAvailable = haptics.isSupported
menuBar.hapticsEnabled   = configStore.config.haptics.enabled
menuBar.configFileURL    = configStore.fileURL

haptics.isEnabled = configStore.config.haptics.enabled

menuBar.onOpenPreferences = {
    preferencesWindow.showWindow(nil)
    preferencesWindow.window?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
}

menuBar.onHapticsToggle = { enabled in
    haptics.isEnabled = enabled
    log.info("Haptics → \(enabled ? "on" : "off")")
}

configStore.onChange = { config in
    haptics.isEnabled = config.haptics.enabled
    haptics.configure(with: config.haptics)
    menuBar.hapticsEnabled = config.haptics.enabled
    interpreter.degreesPerStep = 360.0 / Double(config.stepsPerRotation)
}

// MARK: - Subscribe to bus

overlay.subscribe(to: bus)

// Main event loop — routes actions and drives haptics.
let mainStream = bus.observe()
Task {
    for await event in mainStream {
        router.handle(event)

        switch event {
        case .rotated:       await haptics.play(.detent)
        case .tap:           log.debug("Tap")
        case .holdConfirmed: await haptics.play(.menuOpen)
        case .menuRotated:   await haptics.play(.detent)
        case .menuCommit:    await haptics.play(.modeSwitch)
        case .menuDismiss:   await haptics.play(.menuClose)
        }
    }
}

// MARK: - Start interpreter

interpreter.start()

// MARK: - Run loop

NSApplication.shared.run()
