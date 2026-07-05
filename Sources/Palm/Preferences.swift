import Foundation

// Central UserDefaults-backed store for user-facing feature toggles.
final class Preferences {
    static let shared = Preferences()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let handCursorEnabled = "palm.handCursorEnabled"
        static let voiceDictationEnabled = "palm.voiceDictationEnabled"
    }

    private init() {
        defaults.register(defaults: [
            Keys.handCursorEnabled: false,
            Keys.voiceDictationEnabled: false
        ])
    }

    var isHandCursorEnabled: Bool {
        get { defaults.bool(forKey: Keys.handCursorEnabled) }
        set { defaults.set(newValue, forKey: Keys.handCursorEnabled) }
    }

    var isVoiceDictationEnabled: Bool {
        get { defaults.bool(forKey: Keys.voiceDictationEnabled) }
        set { defaults.set(newValue, forKey: Keys.voiceDictationEnabled) }
    }
}
