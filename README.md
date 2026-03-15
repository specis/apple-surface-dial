# DialKit

A macOS menu bar app that makes the Microsoft Surface Dial fully functional on macOS — volume control, scrolling, app-specific shortcuts, haptic feedback, and a radial overlay menu.

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

If Accessibility is not granted, a `⚠` badge appears on the menu bar icon.

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

## How It Works

```
Surface Dial (Bluetooth LE HID)
        │ raw HID reports
        ▼
  SurfaceDialDriver        — IOHIDManager, parses button + rotation bytes
        │ DialEvent stream
        ▼
  InputInterpreter         — hold detection (200ms), tick accumulation, step normalisation
        │ ActionEvent stream
        ▼
  ActionEventBus           — fan-out to all subscribers
        │
   ┌────┴────┐
   ▼         ▼
VolumeAction  (more actions coming)
HapticEngine
MenuBarController
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

The device reports **36 ticks per revolution** (read dynamically from the Resolution Multiplier feature element at connect time). Each tick represents approximately 10° of physical rotation.

### Hold gesture

- Press and hold for **200ms** → opens radial menu (`.holdConfirmed`)
- Press and release before 200ms → tap (`.tap`)
- While menu is open, rotate to select a segment, release to commit
- Menu auto-dismisses after **3 seconds** of inactivity

### Haptics

Haptic output uses HID Report ID 1 (output type) on the SimpleHapticsController collection (HID Page `0x0E`). The 4-byte report layout:

| Byte | Field | Value |
|---|---|---|
| 0 | RetriggerPeriod | `0x00` = one-shot |
| 1 | AutoTriggerAssociatedControl | `0x01` = manual |
| 2–3 | WaveformVendorPage | Ordinal (LE): `3` = click, `4` = buzz |

---

## Features

### Currently working

- **Volume control** — rotate to adjust system volume. Uses CoreAudio virtual main volume with fallback to per-channel scalar and media key simulation (required on Apple Silicon built-in audio)
- **Haptic feedback** — detent click on rotation, distinct patterns for menu open/close and mode switch
- **Hold gesture** — 200ms hold detection with tap/hold disambiguation
- **Menu bar icon** — `dial.medium` SF Symbol with mode label, mode switcher submenu, haptics toggle, and Quit
- **Dynamic resolution** — reads the device's Resolution Multiplier feature element on connect; `ticksPerStep` adjusts automatically
- **Accessibility prompt** — requests permission on launch; shows `⚠` badge if not granted

### Implemented but not yet active

- **Scroll** — `ScrollAction` is implemented (CGEvent scroll wheel via `postToPid`) but not wired to the event loop pending a fix for event delivery to non-focused windows

---

## Project Structure

```
Sources/DialKit/
├── main.swift                    entry point, bootstrap wiring
├── Device/
│   ├── DialDevice.swift          protocol + DialEvent enum
│   ├── SurfaceDialDriver.swift   IOHIDManager driver, haptic output
│   ├── DeviceManager.swift       stub — multi-device scanning
│   └── DeviceRegistry.swift      VID/PID → driver factory list
├── Input/
│   ├── InputInterpreter.swift    hold state machine, tick accumulation
│   ├── HoldGestureRecogniser.swift  200ms hold timer
│   └── ActionEventBus.swift      AsyncStream fan-out bus
├── Actions/
│   ├── VolumeAction.swift        CoreAudio + media key fallback
│   ├── ScrollAction.swift        CGEvent scroll wheel
│   └── ShortcutAction.swift      stub — CGEvent keystroke synthesis
├── Routing/
│   ├── Mode.swift                scroll / volume / shortcut enum
│   ├── ModeRouter.swift          stub — app-aware mode switching
│   └── AppWatcher.swift          stub — NSWorkspace active app monitor
├── Config/
│   ├── ConfigStore.swift         stub — ~/.config/dialkit/profiles.json
│   ├── AppProfile.swift          stub — per-bundle-ID profile
│   ├── HapticConfig.swift        per-event waveform/intensity overrides
│   └── OverlayConfig.swift       stub — overlay position/timeout settings
├── Overlay/
│   ├── OverlayController.swift   stub — show/hide state machine
│   ├── OverlayPanel.swift        stub — floating NSPanel
│   ├── RadialMenuView.swift      stub — CoreGraphics radial segments
│   └── RadialMenuModel.swift     stub — segment data + highlighted index
├── Haptics/
│   ├── HapticEngine.swift        protocol + HapticEvent enum
│   ├── SurfaceDialHapticEngine.swift  HID output report driver
│   ├── NullHapticEngine.swift    no-op for non-haptic devices
│   └── HapticEventMap.swift      HapticEvent → waveform ordinal/intensity
└── UI/
    └── MenuBarController.swift   NSStatusItem + NSMenu
```

---

## Configuration

Configuration will live at `~/.config/dialkit/profiles.json` (not yet implemented). Planned schema:

```json
{
  "version": 1,
  "defaultProfile": {
    "mode": "volume",
    "volume": { "stepSize": 2 }
  },
  "appProfiles": {
    "com.adobe.Photoshop": {
      "mode": "shortcuts",
      "shortcuts": [
        { "action": "rotate", "keys": ["cmd", "z"], "label": "Undo" }
      ]
    }
  }
}
```

---

## Roadmap

### Next up

- **ModeRouter + AppWatcher** — automatically switch between scroll/volume/shortcut modes based on the active app. Reads app-specific profiles from `ConfigStore`.
- **ConfigStore** — load/save/watch `~/.config/dialkit/profiles.json`. File watcher via `DispatchSource` so changes apply without restarting.

### Overlay

- **RadialMenuView** — CoreGraphics radial menu drawn in an `NSVisualEffectView` panel. Three equal segments (120° each) showing the three modes with icon, label, and live value.
- **OverlayPanel** — floating `NSPanel` at `.screenSaver` level, non-activating, transparent background.
- **OverlayController** — animates show/hide (scale + opacity), positions at cursor or fixed corner, handles segment highlight as the dial rotates.

### Shortcuts

- **ShortcutAction** — CGEvent keystroke synthesis. Requires Accessibility. Per-app shortcut profiles configurable in `profiles.json`.

### Polish

- Fix scroll event delivery to non-focused windows (CGEvent `postToPid` with Accessibility currently delivers to cursor position; needs investigation for reliable cross-app delivery)
- Haptics fine-tuning per event type
- Menu bar icon badge for device disconnected state
- DeviceManager for automatic reconnection and multi-device support
- Launch at login via `SMAppService` (macOS 13+)
- Universal binary release build + `.app` bundle packaging

### Future / out of scope for v1

- GUI preferences panel
- iCloud profile sync
- Griffin PowerMate BT support (driver abstraction already in place)
- On-screen dial placement detection
