// ShortcutAction.swift
// Synthesises CGEvent keystrokes from ShortcutDefinitions.
// Requires Accessibility permission — caller must check before use.

import ApplicationServices
import CoreGraphics
import Foundation
import OSLog

// MARK: - ShortcutAction

final class ShortcutAction {

    /// Called after each successful keystroke with the shortcut's display label.
    var onShortcutFired: ((String) -> Void)?

    /// Fire the keystroke described by a ShortcutDefinition.
    /// Returns silently if Accessibility is not granted.
    func fire(definition: ShortcutDefinition) {
        guard AXIsProcessTrusted() else {
            Log.shortcut.warning("Accessibility not granted — cannot fire '\(definition.label)'")
            return
        }

        let (keyCode, flags) = resolve(keys: definition.keys)
        Log.shortcut.info("Fire '\(definition.label)' — keyCode \(keyCode), flags \(flags.rawValue, format: .hex)")

        if let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) {
            down.flags = flags
            down.post(tap: .cghidEventTap)
        }
        if let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) {
            up.flags = flags
            up.post(tap: .cghidEventTap)
        }

        onShortcutFired?(definition.label)
    }

    // MARK: - Key resolution

    private func resolve(keys: [String]) -> (CGKeyCode, CGEventFlags) {
        var flags: CGEventFlags = []
        var keyCode: CGKeyCode = 0

        for key in keys {
            switch key.lowercased() {
            case "cmd", "command":         flags.insert(.maskCommand)
            case "shift":                  flags.insert(.maskShift)
            case "opt", "alt", "option":   flags.insert(.maskAlternate)
            case "ctrl", "control":        flags.insert(.maskControl)
            default:
                if let code = virtualKeyCode(for: key) { keyCode = code }
            }
        }
        return (keyCode, flags)
    }

    // Virtual key codes sourced from HIToolbox/Events.h
    // swiftlint:disable:next function_body_length
    private func virtualKeyCode(for key: String) -> CGKeyCode? {
        let map: [String: CGKeyCode] = [
            // Letters
            "a": 0,  "s": 1,  "d": 2,  "f": 3,  "h": 4,  "g": 5,
            "z": 6,  "x": 7,  "c": 8,  "v": 9,  "b": 11, "q": 12,
            "w": 13, "e": 14, "r": 15, "y": 16, "t": 17, "o": 31,
            "u": 32, "i": 34, "p": 35, "l": 37, "j": 38, "k": 40,
            "n": 45, "m": 46,
            // Numbers
            "1": 18, "2": 19, "3": 20, "4": 21, "5": 23, "6": 22,
            "7": 26, "8": 28, "9": 25, "0": 29,
            // Symbols
            "-": 27, "=": 24, "[": 33, "]": 30, "\\": 42,
            ";": 41, "'": 39, ",": 43, ".": 47, "/": 44,
            // Special
            "space": 49, "return": 36, "enter": 36, "tab": 48,
            "delete": 51, "backspace": 51, "escape": 53, "esc": 53,
            "forwarddelete": 117,
            // Arrows
            "left": 123, "right": 124, "down": 125, "up": 126,
            // Function keys
            "f1": 122, "f2": 120, "f3": 99,  "f4": 118,
            "f5": 96,  "f6": 97,  "f7": 98,  "f8": 100,
            "f9": 101, "f10": 109, "f11": 103, "f12": 111,
        ]
        return map[key.lowercased()]
    }
}
