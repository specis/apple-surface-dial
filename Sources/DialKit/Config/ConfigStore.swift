// ConfigStore.swift
// Loads, saves, and watches ~/.config/dialkit/profiles.json.
// Uses DispatchSource VNODE watcher for live reload without restarting.

import Foundation
import OSLog

// MARK: - DialKitConfig

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

extension DialKitConfig {
    static let defaults = DialKitConfig(
        version: 1,
        holdThresholdMs: 200,
        stepsPerRotation: 20,
        overlay: OverlayConfig(
            enabled: true,
            position: .cursor,
            corner: .bottomRight,
            cornerInset: 40,
            windowLevel: "screenSaver",
            dismissAfterSeconds: 3.0,
            showModeChanges: true,
            showShortcutLabels: true
        ),
        haptics: HapticConfig(
            enabled: true,
            autoTriggerEnabled: false,
            events: [
                "detent":          HapticEventConfig(waveform: "click", intensity: 60,  repeat: 0, retriggerMs: nil),
                "modeSwitch":      HapticEventConfig(waveform: "buzz",  intensity: 90,  repeat: 0, retriggerMs: nil),
                "shortcutFired":   HapticEventConfig(waveform: "click", intensity: 70,  repeat: 1, retriggerMs: 80),
                "boundaryReached": HapticEventConfig(waveform: "buzz",  intensity: 100, repeat: 0, retriggerMs: nil),
                "menuOpen":        HapticEventConfig(waveform: "click", intensity: 40,  repeat: 0, retriggerMs: nil),
                "menuClose":       HapticEventConfig(waveform: "click", intensity: 30,  repeat: 0, retriggerMs: nil),
            ]
        ),
        defaultProfile: AppProfile(
            mode: .volume,
            scroll: ScrollConfig(direction: "natural", multiplier: 1.0),
            volume: VolumeConfig(stepSize: 5),
            shortcuts: [
                ShortcutDefinition(action: "rotate", keys: ["cmd", "z"],       label: "Undo"),
                ShortcutDefinition(action: "press",  keys: ["cmd", "shift", "z"], label: "Redo"),
            ]
        ),
        appProfiles: [
            // Safari — explicit scroll mode so it always switches back from other modes
            "com.apple.Safari": AppProfile(
                mode: .scroll,
                scroll: ScrollConfig(direction: "natural", multiplier: 1.0),
                volume: nil,
                shortcuts: nil
            ),
            // Apple Music — rotate to skip tracks, tap to play/pause
            "com.apple.Music": AppProfile(
                mode: .shortcut,
                scroll: nil,
                volume: nil,
                shortcuts: [
                    ShortcutDefinition(action: "rotate_cw",  keys: ["cmd", "right"], label: "Next Track"),
                    ShortcutDefinition(action: "rotate_ccw", keys: ["cmd", "left"],  label: "Previous Track"),
                    ShortcutDefinition(action: "press",      keys: ["space"],        label: "Play / Pause"),
                ],
                overlaySegments: [
                    AppOverlaySegment(glyph: "⏮", label: "Previous",   shortcuts: [ShortcutDefinition(action: "select", keys: ["cmd", "left"],  label: "Previous Track")]),
                    AppOverlaySegment(glyph: "⏯", label: "Play/Pause", shortcuts: [ShortcutDefinition(action: "select", keys: ["space"],         label: "Play / Pause")]),
                    AppOverlaySegment(glyph: "⏭", label: "Next",       shortcuts: [ShortcutDefinition(action: "select", keys: ["cmd", "right"], label: "Next Track")]),
                ]
            ),
            // VSCode — rotate through open tabs, tap to quick-open
            "com.microsoft.VSCode": AppProfile(
                mode: .shortcut,
                scroll: nil,
                volume: nil,
                shortcuts: [
                    ShortcutDefinition(action: "rotate_cw",  keys: ["cmd", "shift", "]"], label: "Next Tab"),
                    ShortcutDefinition(action: "rotate_ccw", keys: ["cmd", "shift", "["], label: "Previous Tab"),
                    ShortcutDefinition(action: "press",      keys: ["cmd", "p"],          label: "Quick Open"),
                ],
                overlaySegments: [
                    AppOverlaySegment(glyph: "←",  label: "Prev Tab",   shortcuts: [ShortcutDefinition(action: "select", keys: ["cmd", "shift", "["], label: "Previous Tab")]),
                    AppOverlaySegment(glyph: "⌘P", label: "Quick Open", shortcuts: [ShortcutDefinition(action: "select", keys: ["cmd", "p"],          label: "Quick Open")]),
                    AppOverlaySegment(glyph: "→",  label: "Next Tab",   shortcuts: [ShortcutDefinition(action: "select", keys: ["cmd", "shift", "]"], label: "Next Tab")]),
                ]
            ),
        ]
    )
}

// MARK: - ConfigStore

final class ConfigStore {

    let fileURL: URL
    private var source: DispatchSourceFileSystemObject?

    var config: DialKitConfig

    /// Called on the main thread whenever the config is reloaded from disk.
    var onChange: ((DialKitConfig) -> Void)?

    // MARK: - Init

    init() {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/dialkit", isDirectory: true)
        fileURL = dir.appendingPathComponent("profiles.json")

        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        if let data = try? Data(contentsOf: fileURL),
           let loaded = try? JSONDecoder().decode(DialKitConfig.self, from: data) {
            config = loaded
            Log.config.info("Loaded config from \(self.fileURL.path)")
        } else {
            Log.config.info("No config found — writing defaults to \(self.fileURL.path)")
            config = .defaults
            save()
        }

        startWatcher()
    }

    // MARK: - Public

    func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(config) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    // MARK: - File watcher

    private func startWatcher() {
        source?.cancel()
        source = nil

        let fd = open(fileURL.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )

        src.setEventHandler { [weak self, weak src] in
            guard let self else { return }
            self.reload()
            // Atomic writes rename the original; restart watcher on the new inode.
            let flags = src?.data ?? []
            if flags.contains(.rename) || flags.contains(.delete) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.startWatcher() }
            }
        }
        src.setCancelHandler { close(fd) }
        src.resume()
        source = src
    }

    private func reload() {
        guard let data = try? Data(contentsOf: fileURL) else {
            Log.config.warning("Config file not readable — skipping reload")
            return
        }
        do {
            config = try JSONDecoder().decode(DialKitConfig.self, from: data)
            Log.config.info("Config reloaded from disk")
            onChange?(config)
        } catch {
            Log.config.error("Config decode failed: \(error.localizedDescription)")
        }
    }
}
