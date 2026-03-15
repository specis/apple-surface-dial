// MenuBarController.swift
// NSStatusItem and NSMenu for the DialKit menu bar presence.
//
// NSMenu structure:
//   Mode: Volume         (disabled label)
//   ───────────────────────────────────────
//   Mode ▶               Scroll ✓ / Volume ✓ / Shortcuts ✓
//   ───────────────────────────────────────
//   Haptics: Enabled     (toggle; disabled if device has no haptics)
//   ───────────────────────────────────────
//   About DialKit
//   Quit DialKit         ⌘Q

import AppKit

// MARK: - MenuBarController

final class MenuBarController {

    // MARK: - Public state

    /// Current dial mode. Updates the mode label and checkmarks.
    var currentMode: Mode = .volume {
        didSet { updateModeItems() }
    }

    /// Whether haptic feedback is currently enabled.
    var hapticsEnabled: Bool = true {
        didSet { updateHapticsItem() }
    }

    /// False when the connected device doesn't support haptics — greys out the toggle.
    var hapticsAvailable: Bool = true {
        didSet { updateHapticsItem() }
    }

    /// Called when the user picks a mode from the menu.
    var onModeChange: ((Mode) -> Void)?

    /// Called when the user toggles haptics.
    var onHapticsToggle: ((Bool) -> Void)?

    /// Called when the user clicks "Preferences…".
    var onOpenPreferences: (() -> Void)?

    /// URL of the config file opened by "Open Config File".
    var configFileURL: URL?

    // MARK: - Private

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let modeLabel  = NSMenuItem()
    private let hapticsItem = NSMenuItem()
    private var modeItems: [Mode: NSMenuItem] = [:]

    // MARK: - init

    init(accessibilityGranted: Bool = true) {
        buildMenu()
        updateIcon(accessibilityGranted: accessibilityGranted)
    }

    // MARK: - Public

    func setAccessibilityGranted(_ granted: Bool) {
        updateIcon(accessibilityGranted: granted)
    }

    /// Shows a disconnected badge on the menu bar icon.
    func setDisconnected() {
        guard let button = statusItem.button else { return }
        if let img = NSImage(systemSymbolName: "dial.medium", accessibilityDescription: "DialKit") {
            img.isTemplate = true
            button.image = img
        }
        button.title = " ⊗"
    }

    // MARK: - Private — icon

    private func updateIcon(accessibilityGranted: Bool) {
        guard let button = statusItem.button else { return }
        if let img = NSImage(systemSymbolName: "dial.medium", accessibilityDescription: "DialKit") {
            img.isTemplate = true
            button.image = img
            button.title = accessibilityGranted ? "" : " ⚠"
        } else {
            button.title = accessibilityGranted ? "◎" : "◎ ⚠"
        }
    }

    // MARK: - Private — menu construction

    private func buildMenu() {
        let menu = NSMenu()

        // Mode label (non-interactive header)
        modeLabel.isEnabled = false
        menu.addItem(modeLabel)

        menu.addItem(.separator())

        // Mode submenu
        let modeSubmenu = NSMenu(title: "Mode")
        for mode in Mode.allCases {
            let item = NSMenuItem(
                title: mode.displayName,
                action: #selector(modeItemSelected(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = mode
            modeSubmenu.addItem(item)
            modeItems[mode] = item
        }
        let modeParent = NSMenuItem(title: "Mode", action: nil, keyEquivalent: "")
        modeParent.submenu = modeSubmenu
        menu.addItem(modeParent)

        menu.addItem(.separator())

        // Haptics toggle
        hapticsItem.target = self
        hapticsItem.action = #selector(toggleHaptics)
        menu.addItem(hapticsItem)

        menu.addItem(.separator())

        // Preferences
        let prefs = NSMenuItem(title: "Preferences…", action: #selector(openPreferences), keyEquivalent: ",")
        prefs.target = self
        menu.addItem(prefs)

        menu.addItem(.separator())

        // Open Config File
        let openConfig = NSMenuItem(title: "Open Config File", action: #selector(openConfigFile), keyEquivalent: "")
        openConfig.target = self
        menu.addItem(openConfig)

        menu.addItem(.separator())

        // About
        let about = NSMenuItem(title: "About DialKit", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        // Quit
        menu.addItem(NSMenuItem(
            title: "Quit DialKit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        statusItem.menu = menu

        updateModeItems()
        updateHapticsItem()
    }

    // MARK: - Private — dynamic updates

    private func updateModeItems() {
        modeLabel.title = "Mode: \(currentMode.displayName)"
        for (mode, item) in modeItems {
            item.state = mode == currentMode ? .on : .off
        }
    }

    private func updateHapticsItem() {
        hapticsItem.title   = "Haptics: \(hapticsEnabled ? "Enabled" : "Disabled")"
        hapticsItem.isEnabled = hapticsAvailable
    }

    // MARK: - Actions

    @objc private func modeItemSelected(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? Mode else { return }
        currentMode = mode
        onModeChange?(mode)
    }

    @objc private func toggleHaptics() {
        hapticsEnabled.toggle()
        onHapticsToggle?(hapticsEnabled)
    }

    @objc private func openPreferences() {
        onOpenPreferences?()
    }

    @objc private func openConfigFile() {
        guard let url = configFileURL else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func showAbout() {
        NSApplication.shared.orderFrontStandardAboutPanel(nil)
    }
}
