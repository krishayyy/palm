import Foundation
import CoreGraphics
import ApplicationServices

// Posts synthetic keystrokes system-wide via the HID event tap so the frontmost
// app (not just Palm's own window) receives them, regardless of window focus.
enum InputInjector {

    static func isAccessibilityTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    @discardableResult
    static func requestAccessibilityPermission() -> Bool {
        let options: [String: Bool] = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    /// Types a single character using the correct keycode when known, otherwise
    /// falls back to CGEventKeyboardSetUnicodeString for punctuation/symbols
    /// that have no stable virtual keycode across keyboard layouts.
    static func typeCharacter(_ character: Character) {
        if let keyCode = VirtualKeyCode.code(for: character) {
            postKeyEvent(keyCode: keyCode, shift: VirtualKeyCode.needsShift(character))
        } else {
            postUnicodeEvent(for: String(character))
        }
    }

    static func typeString(_ string: String) {
        for character in string {
            typeCharacter(character)
        }
    }

    static func pressSpecialKey(_ key: SpecialKey) {
        postKeyEvent(keyCode: key.keyCode, shift: false)
    }

    private static func postKeyEvent(keyCode: CGKeyCode, shift: Bool) {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else { return }
        if shift {
            keyDown.flags.insert(.maskShift)
            keyUp.flags.insert(.maskShift)
        }
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    private static func postUnicodeEvent(for string: String) {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else { return }
        let utf16 = Array(string.utf16)
        keyDown.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
        keyUp.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}

enum SpecialKey {
    case `return`, delete, tab, space, escape, leftArrow, rightArrow, upArrow, downArrow

    var keyCode: CGKeyCode {
        switch self {
        case .return: return 0x24
        case .delete: return 0x33
        case .tab: return 0x30
        case .space: return 0x31
        case .escape: return 0x35
        case .leftArrow: return 0x7B
        case .rightArrow: return 0x7C
        case .downArrow: return 0x7D
        case .upArrow: return 0x7E
        }
    }
}

// Maps letters/digits to their physical macOS virtual keycodes (ANSI-US layout).
// Punctuation that shifts meaning across layouts is intentionally left out here
// and instead routed through the Unicode-string path in InputInjector.
enum VirtualKeyCode {
    private static let letterCodes: [Character: CGKeyCode] = [
        "a": 0x00, "b": 0x0B, "c": 0x08, "d": 0x02, "e": 0x0E, "f": 0x03,
        "g": 0x05, "h": 0x04, "i": 0x22, "j": 0x26, "k": 0x28, "l": 0x25,
        "m": 0x2E, "n": 0x2D, "o": 0x1F, "p": 0x23, "q": 0x0C, "r": 0x0F,
        "s": 0x01, "t": 0x11, "u": 0x20, "v": 0x09, "w": 0x0D, "x": 0x07,
        "y": 0x10, "z": 0x06
    ]

    private static let digitCodes: [Character: CGKeyCode] = [
        "0": 0x1D, "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15,
        "5": 0x17, "6": 0x16, "7": 0x1A, "8": 0x1C, "9": 0x19
    ]

    static func code(for character: Character) -> CGKeyCode? {
        let lower = Character(character.lowercased())
        if let code = letterCodes[lower] { return code }
        if let code = digitCodes[character] { return code }
        if character == " " { return SpecialKey.space.keyCode }
        return nil
    }

    static func needsShift(_ character: Character) -> Bool {
        character.isUppercase
    }
}
