import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, HandTrackerDelegate {
    private var statusItem: NSStatusItem!
    private let handTracker = HandTracker()
    private let cursorController = CursorController()
    private let voiceDictation = VoiceDictation()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // menu-bar only, no Dock icon or app switcher entry

        handTracker.delegate = self

        buildStatusItem()
        syncFeatureState()

        if !InputInjector.isAccessibilityTrusted() {
            InputInjector.requestAccessibilityPermission()
        }
    }

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "hand.raised.fill", accessibilityDescription: "Palm")
        }
        statusItem.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let handItem = NSMenuItem(title: "Hand Cursor", action: #selector(toggleHandCursor), keyEquivalent: "")
        handItem.target = self
        handItem.state = Preferences.shared.isHandCursorEnabled ? .on : .off
        menu.addItem(handItem)

        let voiceItem = NSMenuItem(title: "Voice Dictation", action: #selector(toggleVoiceDictation), keyEquivalent: "")
        voiceItem.target = self
        voiceItem.state = Preferences.shared.isVoiceDictationEnabled ? .on : .off
        menu.addItem(voiceItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Palm", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    @objc private func toggleHandCursor() {
        Preferences.shared.isHandCursorEnabled.toggle()
        statusItem.menu = buildMenu()
        syncFeatureState()
    }

    @objc private func toggleVoiceDictation() {
        Preferences.shared.isVoiceDictationEnabled.toggle()
        statusItem.menu = buildMenu()
        syncFeatureState()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func syncFeatureState() {
        if Preferences.shared.isHandCursorEnabled {
            handTracker.start()
        } else {
            handTracker.stop()
        }

        if Preferences.shared.isVoiceDictationEnabled {
            voiceDictation.start()
        } else {
            voiceDictation.stop()
        }
    }

    nonisolated func handTracker(_ tracker: HandTracker, didUpdate hands: [HandPointerState]) {
        Task { @MainActor [cursorController] in
            cursorController.update(hands: hands)
        }
    }
}
