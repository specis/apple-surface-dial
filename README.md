# DialKit

A macOS menu bar app that makes the Microsoft Surface Dial fully functional on macOS — volume control, scrolling, app-specific shortcuts, haptic feedback, a radial overlay menu, and per-app custom menus.

No Xcode required. Built with Swift Package Manager.

---

## Requirements

- macOS 13 Ventura or later
- Microsoft Surface Dial (VID `0x045E` / PID `0x091B`)
- Swift 5.9+

---

## Permissions

DialKit requires two system permissions:

| Permission | Why |
|---|---|
| **Input Monitoring** | Read raw HID reports from the Surface Dial over Bluetooth |
| **Accessibility** | Synthesise scroll and keystroke events to other apps |

On first run, DialKit will prompt for Accessibility access. Input Monitoring is requested automatically by IOKit when the HID manager opens. Grant both in **System Settings → Privacy & Security**.

If Accessibility is not granted, a `⚠` badge appears on the menu bar icon. Scroll still works without it; keystroke shortcuts require it.

---

## Build & Run

```bash
# Clone
git clone https://github.com/your-username/apple-surface-dial.git
cd apple-surface-dial

# Build
swift build

# Run
swift run

# Release build (universal binary — Apple Silicon + Intel)
swift build -c release --arch arm64 --arch x86_64
```

---

## Features

### Dial modes

Three operating modes, switchable from the menu bar or the radial overlay:

| Mode | Rotate | Tap |
|---|---|---|
| **Volume** | Adjust system volume. HUD shows current level. | — |
| **Scroll** | Scroll the window under the cursor (natural or inverted). | — |
| **Shortcuts** | Fire configurable key combos per app profile. | Fire press-action shortcut. |

### Per-app profiles

DialKit watches the frontmost application and automatically switches mode and behaviour when you move between apps. Profiles are defined in `~/.config/dialkit/profiles.json`.

Built-in profiles:

| App | Mode | Rotate | Tap |
|---|---|---|---|
| Safari | Scroll | Scroll page | — |
| Apple Music | Shortcuts | Previous / Next track | Play/Pause |
| VSCode | Shortcuts | Previous / Next tab | Quick Open |
| Everything else | Volume | Adjust volume | — |

App-profile modes are **temporary** — switching to an unprofiled app reverts to whichever mode you last manually selected.

### Radial overlay menu

Hold the dial button for 200ms to open the radial menu. Rotate to highlight a segment, release to commit.

- Default layout: **Scroll / Volume / Shortcuts**
- Apps with `overlaySegments` in their profile get a **custom menu** — Apple Music shows ⏮ / ⏯ / ⏭, VSCode shows Prev Tab / Quick Open / Next Tab
- Centre disc shows the active app name
- Menu auto-dismisses after 3 seconds of inactivity
- Committing a custom segment fires its shortcuts directly

### Haptic feedback

Haptic output via HID output reports to the Surface Dial's SimpleHapticsController:

| Event | Haptic |
|---|---|
| Rotation step | Click (detent) |
| Menu open | Soft click |
| Menu close | Soft click |
| Mode switch | Buzz |
| Shortcut fired | Double click |
| Volume boundary (0% / 100%) | Strong buzz |

Haptics can be toggled from the menu bar and are fully configurable per-event in `profiles.json`.

### Reconnect

The dial reconnects automatically when it wakes from sleep or comes back in range. The menu bar icon shows a `⊗` badge while disconnected and clears when the device is found again.

### Preferences

A GUI preferences window (⌘,) covers the most common settings without touching JSON:

- **General** — default mode, hold threshold (100–500ms), steps per rotation (10–40)
- **Haptics** — master toggle, per-event intensity sliders
- **App Profiles** — add/remove per-app profiles and set their mode

All changes write through to `profiles.json` immediately and take effect without restarting.

---

## How It Works

```
Surface Dial (Bluetooth LE HID)
        │ raw HID reports
        ▼
  SurfaceDialDriver        — IOHIDManager, parses button + rotation bytes
        │ DialEvent stream
        ▼
  InputInterpreter         — hold detection, tick accumulation, step normalisation
        │ ActionEvent stream
        ▼
  ActionEventBus           — fan-out AsyncStream to all subscribers
        │
   ┌────┼──────────────┐
   ▼    ▼              ▼
ModeRouter        OverlayController
   │                   │
   ├─ ScrollAction      └─ RadialMenuView (CoreGraphics)
   ├─ VolumeAction
   └─ ShortcutAction

SurfaceDialHapticEngine    — HID output reports (Page 0x0E)
MenuBarController          — NSStatusItem + NSMenu
ValueHUDController         — frosted-glass live-value HUD
```

### Input reports

The Surface Dial sends 9-byte HID reports at Report ID 1:

| Bytes | Field | Notes |
|---|---|---|
| 1 | Button | Bit 0 = pressed |
| 2–3 | Rotation delta | Signed Int16, little-endian. Negative = anticlockwise |
| 4–5 | X position | Physical position (Surface Hub only) |
| 6–7 | Y position | Physical position (Surface Hub only) |
| 8 | Physical size | Constant — dial radius in device units |

Resolution is read dynamically from the device's Resolution Multiplier feature element at connect time (`ticksPerStep` adjusts automatically).

### Hold gesture state machine

```
Idle → [pressed]            → Held (start hold timer)
Held → [released]           → Idle (emit .tap)
Held → [timer fires]        → MenuOpen (emit .holdConfirmed)
MenuOpen → [rotated]        → emit .menuRotated
MenuOpen → [released]       → emit .menuCommit(segmentIndex)
MenuOpen → [3s inactivity]  → emit .menuDismiss
```

### Haptic output

HID output report on the SimpleHapticsController collection (Page `0x0E`):

| Byte | Field | Value |
|---|---|---|
| 0 | RetriggerPeriod | `0x00` = one-shot |
| 1 | AutoTriggerAssociatedControl | `0x01` = manual |
| 2–3 | WaveformVendorPage | Ordinal (LE): `3` = click, `4` = buzz |

---

## Configuration

Config lives at `~/.config/dialkit/profiles.json`. It is created with sensible defaults on first run and reloaded live whenever you save it — no restart needed.

```json
{
  "version": 1,
  "holdThresholdMs": 200,
  "stepsPerRotation": 20,
  "overlay": {
    "enabled": true,
    "position": "cursor"
  },
  "haptics": {
    "enabled": true,
    "events": {
      "detent":    { "waveform": "click", "intensity": 60, "repeat": 0 },
      "modeSwitch": { "waveform": "buzz",  "intensity": 90, "repeat": 0 }
    }
  },
  "defaultProfile": {
    "mode": "volume",
    "volume": { "stepSize": 5 },
    "shortcuts": [
      { "action": "rotate", "keys": ["cmd", "z"],          "label": "Undo" },
      { "action": "press",  "keys": ["cmd", "shift", "z"], "label": "Redo" }
    ]
  },
  "appProfiles": {
    "com.apple.Music": {
      "mode": "shortcut",
      "shortcuts": [
        { "action": "rotate_cw",  "keys": ["cmd", "right"], "label": "Next Track" },
        { "action": "rotate_ccw", "keys": ["cmd", "left"],  "label": "Previous Track" },
        { "action": "press",      "keys": ["space"],        "label": "Play / Pause" }
      ],
      "overlaySegments": [
        { "glyph": "⏮", "label": "Previous",   "shortcuts": [{ "action": "select", "keys": ["cmd", "left"],  "label": "Previous Track" }] },
        { "glyph": "⏯", "label": "Play/Pause", "shortcuts": [{ "action": "select", "keys": ["space"],        "label": "Play / Pause" }] },
        { "glyph": "⏭", "label": "Next",       "shortcuts": [{ "action": "select", "keys": ["cmd", "right"], "label": "Next Track" }] }
      ]
    }
  }
}
```

### Shortcut action types

| Action | Fires when |
|---|---|
| `rotate` | Any rotation step (both directions) |
| `rotate_cw` | Clockwise rotation only |
| `rotate_ccw` | Counterclockwise rotation only |
| `press` | Tap (short press and release) |
| `select` | Overlay segment committed |

---

## Project Structure

```
Sources/DialKit/
├── main.swift                       entry point, pipeline wiring
├── Device/
│   ├── DialDevice.swift             protocol + DialEvent enum
│   ├── SurfaceDialDriver.swift      IOHIDManager driver, haptic output
│   ├── DeviceManager.swift          owns driver + haptic engine, reconnect
│   └── DeviceRegistry.swift         VID/PID → driver factory list
├── Input/
│   ├── InputInterpreter.swift       hold state machine, tick accumulation
│   ├── HoldGestureRecogniser.swift  200ms hold timer
│   └── ActionEventBus.swift         AsyncStream fan-out bus
├── Actions/
│   ├── VolumeAction.swift           CoreAudio + media key fallback
│   ├── ScrollAction.swift           CGEvent scroll wheel (line + pixel fallback)
│   └── ShortcutAction.swift         CGEvent keystroke synthesis
├── Routing/
│   ├── Mode.swift                   scroll / volume / shortcut enum
│   ├── ModeRouter.swift             app-aware mode dispatch, user vs profile mode
│   └── AppWatcher.swift             NSWorkspace active app monitor
├── Config/
│   ├── ConfigStore.swift            load/save/watch ~/.config/dialkit/profiles.json
│   ├── AppProfile.swift             per-bundle-ID profile + overlay segments
│   ├── HapticConfig.swift           per-event waveform/intensity settings
│   └── OverlayConfig.swift          overlay position/timeout settings
├── Overlay/
│   ├── OverlayController.swift      show/hide state machine, segment swapping
│   ├── OverlayPanel.swift           floating NSPanel, screenSaver level
│   ├── RadialMenuView.swift         CoreGraphics radial segments + animations
│   ├── RadialMenuModel.swift        segment data, SegmentAction enum
│   └── ValueHUDController.swift     frosted-glass live-value / shortcut HUD
├── Haptics/
│   ├── HapticEngine.swift           protocol + HapticEvent enum
│   ├── SurfaceDialHapticEngine.swift HID output report driver
│   ├── NullHapticEngine.swift       no-op for non-haptic devices
│   └── HapticEventMap.swift         HapticEvent → waveform ordinal/intensity
└── UI/
    ├── MenuBarController.swift      NSStatusItem + NSMenu
    └── PreferencesWindowController.swift  programmatic AppKit preferences
```

---

## Roadmap

- **Launch at login** — `SMAppService` registration (requires `.app` bundle)
- **`.app` bundle** — proper bundle packaging with `LSUIElement = true`
- **Active profile name in menu bar** — show app name or "Default" as a disabled label
- **Shortcut editor in preferences** — add/edit key bindings without touching JSON
- **Griffin PowerMate BT** — driver abstraction already in place, needs a driver

### Out of scope for v1

- GUI preferences for overlay segments (edit `profiles.json` directly)
- iCloud profile sync
- On-screen dial placement detection
- Windows / Linux support
