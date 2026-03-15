// PreferencesWindowController.swift
// Programmatic AppKit preferences window — three tabs: General, Haptics, App Profiles.
// Write-through design: every control change mutates configStore.config and calls save().
// isReleasedWhenClosed = false keeps the instance alive for repeat opens.

import AppKit

// MARK: - PreferencesWindowController

final class PreferencesWindowController: NSWindowController,
                                         NSTableViewDataSource,
                                         NSTableViewDelegate {

    private let configStore: ConfigStore

    // App Profiles tab mirror
    private var profileRows: [(bundleID: String, profile: AppProfile)] = []
    private weak var profileTable: NSTableView?

    // General tab refs (for external sync if needed)
    private weak var defaultModePopup: NSPopUpButton?
    private weak var holdSlider: NSSlider?
    private weak var holdLabel: NSTextField?
    private weak var stepsSlider: NSSlider?
    private weak var stepsLabel: NSTextField?

    // Haptics tab refs
    private weak var hapticsMasterToggle: NSButton?
    private var hapticSliders: [String: NSSlider] = [:]
    private var hapticValueLabels: [String: NSTextField] = [:]

    // MARK: - Init

    init(configStore: ConfigStore) {
        self.configStore = configStore

        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 440),
            styleMask:   [.titled, .closable, .miniaturizable],
            backing:     .buffered,
            defer:       false
        )
        win.title = "DialKit Preferences"
        win.center()
        win.isReleasedWhenClosed = false   // keeps instance alive after close

        super.init(window: win)
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError("use init(configStore:)") }

    // MARK: - UI Construction

    private func buildUI() {
        let tabView = NSTabView()
        tabView.translatesAutoresizingMaskIntoConstraints = false

        let generalItem = NSTabViewItem(identifier: "general")
        generalItem.label = "General"
        generalItem.view  = makeGeneralTab()

        let hapticsItem = NSTabViewItem(identifier: "haptics")
        hapticsItem.label = "Haptics"
        hapticsItem.view  = makeHapticsTab()

        let profilesItem = NSTabViewItem(identifier: "profiles")
        profilesItem.label = "App Profiles"
        profilesItem.view  = makeProfilesTab()

        tabView.addTabViewItem(generalItem)
        tabView.addTabViewItem(hapticsItem)
        tabView.addTabViewItem(profilesItem)

        let content = window!.contentView!
        content.addSubview(tabView)
        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(equalTo: content.topAnchor),
            tabView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            tabView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            tabView.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
    }

    // MARK: - General Tab

    private func makeGeneralTab() -> NSView {
        let cfg = configStore.config

        // Default mode
        let modePopup = NSPopUpButton()
        Mode.allCases.forEach { modePopup.addItem(withTitle: $0.displayName) }
        modePopup.selectItem(at: Mode.allCases.firstIndex(of: cfg.defaultProfile.mode) ?? 0)
        modePopup.target = self
        modePopup.action = #selector(defaultModeChanged(_:))
        modePopup.widthAnchor.constraint(equalToConstant: 140).isActive = true
        defaultModePopup = modePopup

        // Hold threshold slider (100–500 ms, snap to 50ms increments)
        let hSlider = NSSlider()
        hSlider.minValue            = 100
        hSlider.maxValue            = 500
        hSlider.doubleValue         = Double(cfg.holdThresholdMs)
        hSlider.numberOfTickMarks   = 9       // 100, 150, … 500
        hSlider.allowsTickMarkValuesOnly = true
        hSlider.target              = self
        hSlider.action              = #selector(holdThresholdChanged(_:))
        hSlider.widthAnchor.constraint(equalToConstant: 200).isActive = true
        let hLabel = valueLabel("\(cfg.holdThresholdMs) ms")
        holdSlider = hSlider
        holdLabel  = hLabel

        // Steps per rotation slider (10–40)
        let sSlider = NSSlider()
        sSlider.minValue    = 10
        sSlider.maxValue    = 40
        sSlider.integerValue = cfg.stepsPerRotation
        sSlider.target      = self
        sSlider.action      = #selector(stepsPerRotationChanged(_:))
        sSlider.widthAnchor.constraint(equalToConstant: 200).isActive = true
        let sLabel = valueLabel("\(cfg.stepsPerRotation) steps")
        stepsSlider = sSlider
        stepsLabel  = sLabel

        return padded(vstack([
            controlRow("Default Mode",      modePopup),
            controlRow("Hold Threshold",    hSlider, hLabel),
            controlRow("Steps / Rotation",  sSlider, sLabel),
        ]))
    }

    // MARK: - Haptics Tab

    private let hapticEventKeys: [(key: String, display: String)] = [
        ("detent",          "Detent"),
        ("modeSwitch",      "Mode Switch"),
        ("shortcutFired",   "Shortcut Fired"),
        ("boundaryReached", "Boundary Reached"),
        ("menuOpen",        "Menu Open"),
        ("menuClose",       "Menu Close"),
    ]

    private func makeHapticsTab() -> NSView {
        let cfg = configStore.config

        let toggle = NSButton(checkboxWithTitle: "Enable haptic feedback", target: self,
                              action: #selector(hapticsMasterToggled(_:)))
        toggle.state = cfg.haptics.enabled ? .on : .off
        hapticsMasterToggle = toggle

        let separator = NSBox()
        separator.boxType = .separator

        var rows: [NSView] = [toggle, separator]

        for (idx, (key, display)) in hapticEventKeys.enumerated() {
            let intensity = cfg.haptics.events[key]?.intensity ?? 60

            let slider = NSSlider()
            slider.minValue     = 0
            slider.maxValue     = 100
            slider.integerValue = intensity
            slider.isEnabled    = cfg.haptics.enabled
            slider.tag          = idx    // index into hapticEventKeys
            slider.target       = self
            slider.action       = #selector(hapticIntensityChanged(_:))
            slider.widthAnchor.constraint(equalToConstant: 180).isActive = true

            let vLabel = valueLabel("\(intensity)%")
            hapticSliders[key]      = slider
            hapticValueLabels[key]  = vLabel

            rows.append(controlRow(display, slider, vLabel))
        }

        return padded(vstack(rows, spacing: 10))
    }

    // MARK: - App Profiles Tab

    private func makeProfilesTab() -> NSView {
        syncProfileRows()

        let table = NSTableView()
        table.usesAlternatingRowBackgroundColors = true
        table.rowHeight = 24

        let bundleCol = NSTableColumn(identifier: .init("bundleID"))
        bundleCol.title = "Bundle ID"
        bundleCol.width = 290

        let modeCol = NSTableColumn(identifier: .init("mode"))
        modeCol.title = "Mode"
        modeCol.width = 110

        table.addTableColumn(bundleCol)
        table.addTableColumn(modeCol)
        table.dataSource = self
        table.delegate   = self
        profileTable = table

        let scrollView = NSScrollView()
        scrollView.documentView       = table
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers  = true
        scrollView.borderType          = .bezelBorder
        scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 220).isActive = true

        let addBtn    = smallButton("+", action: #selector(addProfile(_:)))
        let removeBtn = smallButton("−", action: #selector(removeProfile(_:)))
        let btnRow    = NSStackView(views: [addBtn, removeBtn])
        btnRow.orientation = .horizontal
        btnRow.spacing     = 4

        let hint = NSTextField(labelWithString: "Bundle IDs are case-sensitive, e.g. com.adobe.Photoshop")
        hint.font      = .systemFont(ofSize: NSFont.smallSystemFontSize)
        hint.textColor = .secondaryLabelColor

        return padded(vstack([scrollView, btnRow, hint], spacing: 6))
    }

    // MARK: - Layout Helpers

    private func controlRow(_ label: String, _ control: NSView, _ extra: NSView? = nil) -> NSStackView {
        let lbl = NSTextField(labelWithString: label + ":")
        lbl.widthAnchor.constraint(equalToConstant: 140).isActive = true
        var views: [NSView] = [lbl, control]
        if let e = extra { views.append(e) }
        let row = NSStackView(views: views)
        row.orientation = .horizontal
        row.spacing     = 8
        row.alignment   = .centerY
        return row
    }

    private func valueLabel(_ text: String) -> NSTextField {
        let lbl = NSTextField(labelWithString: text)
        lbl.widthAnchor.constraint(equalToConstant: 60).isActive = true
        return lbl
    }

    private func vstack(_ views: [NSView], spacing: CGFloat = 14) -> NSStackView {
        let s = NSStackView(views: views)
        s.orientation = .vertical
        s.alignment   = .leading
        s.spacing     = spacing
        return s
    }

    private func padded(_ view: NSView, inset: CGFloat = 20) -> NSView {
        let container = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: container.topAnchor, constant: inset),
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: inset),
            view.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -inset),
            view.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -inset),
        ])
        return container
    }

    private func smallButton(_ title: String, action: Selector) -> NSButton {
        let btn = NSButton(title: title, target: self, action: action)
        btn.bezelStyle = .smallSquare
        return btn
    }

    // MARK: - Actions — General

    @objc private func defaultModeChanged(_ sender: NSPopUpButton) {
        configStore.config.defaultProfile.mode = Mode.allCases[sender.indexOfSelectedItem]
        configStore.save()
    }

    @objc private func holdThresholdChanged(_ sender: NSSlider) {
        // Snap to nearest 50ms (tick marks handle this, but guard anyway)
        let snapped = (sender.integerValue / 50) * 50
        configStore.config.holdThresholdMs = snapped
        configStore.save()
        holdLabel?.stringValue = "\(snapped) ms"
    }

    @objc private func stepsPerRotationChanged(_ sender: NSSlider) {
        let value = sender.integerValue
        configStore.config.stepsPerRotation = value
        configStore.save()
        stepsLabel?.stringValue = "\(value) steps"
    }

    // MARK: - Actions — Haptics

    @objc private func hapticsMasterToggled(_ sender: NSButton) {
        let enabled = sender.state == .on
        configStore.config.haptics.enabled = enabled
        configStore.save()
        hapticSliders.values.forEach { $0.isEnabled = enabled }
    }

    @objc private func hapticIntensityChanged(_ sender: NSSlider) {
        let key   = hapticEventKeys[sender.tag].key
        let value = sender.integerValue
        configStore.config.haptics.events[key]?.intensity = value
        configStore.save()
        hapticValueLabels[key]?.stringValue = "\(value)%"
    }

    // MARK: - Actions — App Profiles

    @objc private func addProfile(_ sender: Any) {
        let newID      = "com.example.app"
        let newProfile = AppProfile(mode: .scroll, scroll: nil, volume: nil, shortcuts: nil)
        profileRows.append((bundleID: newID, profile: newProfile))
        configStore.config.appProfiles[newID] = newProfile
        configStore.save()
        profileTable?.reloadData()
        let newRow = profileRows.count - 1
        profileTable?.selectRowIndexes(IndexSet(integer: newRow), byExtendingSelection: false)
        profileTable?.editColumn(0, row: newRow, with: nil, select: true)
    }

    @objc private func removeProfile(_ sender: Any) {
        guard let table = profileTable, table.selectedRow >= 0 else { return }
        let idx      = table.selectedRow
        let bundleID = profileRows[idx].bundleID
        profileRows.remove(at: idx)
        configStore.config.appProfiles.removeValue(forKey: bundleID)
        configStore.save()
        table.reloadData()
    }

    @objc private func bundleIDCommitted(_ sender: NSTextField) {
        let row    = sender.tag
        guard row < profileRows.count else { return }
        let oldID  = profileRows[row].bundleID
        let newID  = sender.stringValue.trimmingCharacters(in: .whitespaces)
        guard !newID.isEmpty, newID != oldID else { return }
        let profile = profileRows[row].profile
        profileRows[row] = (bundleID: newID, profile: profile)
        configStore.config.appProfiles.removeValue(forKey: oldID)
        configStore.config.appProfiles[newID] = profile
        configStore.save()
    }

    @objc private func profileModeChanged(_ sender: NSPopUpButton) {
        let row  = sender.tag
        guard row < profileRows.count else { return }
        let mode = Mode.allCases[sender.indexOfSelectedItem]
        profileRows[row].profile.mode = mode
        let bundleID = profileRows[row].bundleID
        configStore.config.appProfiles[bundleID] = profileRows[row].profile
        configStore.save()
    }

    // MARK: - Helpers

    private func syncProfileRows() {
        profileRows = configStore.config.appProfiles
            .sorted { $0.key < $1.key }
            .map { (bundleID: $0.key, profile: $0.value) }
    }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int { profileRows.count }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView,
                   viewFor tableColumn: NSTableColumn?,
                   row: Int) -> NSView? {
        let entry = profileRows[row]
        switch tableColumn?.identifier.rawValue {
        case "bundleID":
            let tf = NSTextField(string: entry.bundleID)
            tf.isEditable      = true
            tf.isBordered      = false
            tf.drawsBackground = false
            tf.tag             = row
            tf.target          = self
            tf.action          = #selector(bundleIDCommitted(_:))
            return tf
        case "mode":
            let popup = NSPopUpButton(frame: .zero, pullsDown: false)
            Mode.allCases.forEach { popup.addItem(withTitle: $0.displayName) }
            popup.selectItem(at: Mode.allCases.firstIndex(of: entry.profile.mode) ?? 0)
            popup.tag    = row
            popup.target = self
            popup.action = #selector(profileModeChanged(_:))
            return popup
        default:
            return nil
        }
    }
}
