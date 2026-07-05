import Foundation
import AppKit

enum PointerColorOption: String, CaseIterable, Identifiable {
    case cyan, magenta, yellow, green, orange

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }

    var nsColor: NSColor {
        switch self {
        case .cyan: return NSColor.systemCyan
        case .magenta: return NSColor.systemPink
        case .yellow: return NSColor.systemYellow
        case .green: return NSColor.systemGreen
        case .orange: return NSColor.systemOrange
        }
    }
}

enum PointerShapeOption: String, CaseIterable, Identifiable {
    case circle, ring, crosshair

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }
}

// Central UserDefaults-backed store for user-facing toggles and pointer look.
final class Preferences {
    static let shared = Preferences()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let handKeyboardEnabled = "palm.handKeyboardEnabled"
        static let voiceDictationEnabled = "palm.voiceDictationEnabled"
        static let pointerColor = "palm.pointerColor"
        static let pointerShape = "palm.pointerShape"
    }

    private init() {
        defaults.register(defaults: [
            Keys.handKeyboardEnabled: false,
            Keys.voiceDictationEnabled: false,
            Keys.pointerColor: PointerColorOption.cyan.rawValue,
            Keys.pointerShape: PointerShapeOption.ring.rawValue
        ])
    }

    var isHandKeyboardEnabled: Bool {
        get { defaults.bool(forKey: Keys.handKeyboardEnabled) }
        set { defaults.set(newValue, forKey: Keys.handKeyboardEnabled) }
    }

    var isVoiceDictationEnabled: Bool {
        get { defaults.bool(forKey: Keys.voiceDictationEnabled) }
        set { defaults.set(newValue, forKey: Keys.voiceDictationEnabled) }
    }

    var pointerColor: PointerColorOption {
        get { PointerColorOption(rawValue: defaults.string(forKey: Keys.pointerColor) ?? "") ?? .cyan }
        set { defaults.set(newValue.rawValue, forKey: Keys.pointerColor) }
    }

    var pointerShape: PointerShapeOption {
        get { PointerShapeOption(rawValue: defaults.string(forKey: Keys.pointerShape) ?? "") ?? .ring }
        set { defaults.set(newValue.rawValue, forKey: Keys.pointerShape) }
    }
}
