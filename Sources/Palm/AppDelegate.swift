import AppKit
import SwiftUI
import Combine

struct TrackedHand: Identifiable {
    let id: String // "L" or "R"
    var state: HandPointerState
}

// Shared observable state bridging HandTracker's per-frame callbacks to the
// SwiftUI overlay (pointer positions, keyboard highlight, pinch-click flashes).
@MainActor
final class HandOverlayModel: ObservableObject {
    @Published var hands: [TrackedHand] = []
    @Published var keyUnderAnyHand: String?
    @Published var flashingKey: String?

    var keyboardFrame: CGRect = .zero

    private let keyRows: [[String]] = [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
        ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
        ["z", "x", "c", "v", "b", "n", "m"],
        ["space", "delete", "return"]
    ]

    private var previousPinchState: [String: Bool] = [:]
    private var flashResetWorkItem: DispatchWorkItem?

    func update(hands newHands: [HandPointerState]) {
        hands = newHands.map { TrackedHand(id: $0.label, state: $0) }

        var hitKey: String?
        for hand in newHands {
            let point = CGPoint(
                x: hand.normalizedPosition.x * keyboardFrame.width,
                y: (1 - hand.normalizedPosition.y) * keyboardFrame.height
            )
            if let key = keyLabel(at: point) {
                hitKey = key
                handlePinchTransition(handLabel: hand.label, isPinching: hand.isPinching, key: key)
            }
        }
        keyUnderAnyHand = hitKey
    }

    private func handlePinchTransition(handLabel: String, isPinching: Bool, key: String) {
        let wasPinching = previousPinchState[handLabel] ?? false
        previousPinchState[handLabel] = isPinching
        guard isPinching && !wasPinching else { return }
        dispatchKeyPress(key)
    }

    private func dispatchKeyPress(_ key: String) {
        flashingKey = key
        flashResetWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in self?.flashingKey = nil }
        flashResetWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: workItem)

        switch key {
        case "space": InputInjector.pressSpecialKey(.space)
        case "delete": InputInjector.pressSpecialKey(.delete)
        case "return": InputInjector.pressSpecialKey(.return)
        default:
            if let character = key.first {
                InputInjector.typeCharacter(character)
            }
        }
    }

    // Approximates the same grid layout math used by KeyboardOverlayView to
    // figure out which key a normalized point falls on, without needing SwiftUI
    // layout introspection.
    private func keyLabel(at point: CGPoint) -> String? {
        guard keyboardFrame.width > 0, keyboardFrame.height > 0 else { return nil }
        let rowCount = keyRows.count
        let rowHeight = keyboardFrame.height / CGFloat(rowCount + 1) // + spacer allowance
        let rowIndex = Int(point.y / rowHeight)
        guard rowIndex >= 0, rowIndex < rowCount else { return nil }
        let row = keyRows[rowIndex]

        let widths: [CGFloat] = row.map { key in
            switch key {
            case "space": return 5
            case "delete", "return": return 2
            default: return 1
            }
        }
        let totalWidth = widths.reduce(0, +)
        guard totalWidth > 0 else { return nil }

        var cursor: CGFloat = (keyboardFrame.width - (totalWidth * 34)) / 2
        for (index, key) in row.enumerated() {
            let width = widths[index] * 34
            if point.x >= cursor && point.x <= cursor + width {
                return key
            }
            cursor += width + 8
        }
        return nil
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, HandTrackerDelegate {
    private var statusItem: NSStatusItem!
    private let handTracker = HandTracker()
    private let overlayModel = HandOverlayModel()
    private var overlayWindow: OverlayWindow?
    private let voiceDictation = VoiceDictation()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // menu-bar only, no Dock icon or app switcher entry

        handTracker.delegate = self
        overlayWindow = OverlayWindow(handTrackerModel: overlayModel)

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

        let handItem = NSMenuItem(title: "Hand Keyboard", action: #selector(toggleHandKeyboard), keyEquivalent: "")
        handItem.target = self
        handItem.state = Preferences.shared.isHandKeyboardEnabled ? .on : .off
        menu.addItem(handItem)

        let voiceItem = NSMenuItem(title: "Voice Dictation", action: #selector(toggleVoiceDictation), keyEquivalent: "")
        voiceItem.target = self
        voiceItem.state = Preferences.shared.isVoiceDictationEnabled ? .on : .off
        menu.addItem(voiceItem)

        menu.addItem(.separator())
        menu.addItem(buildColorSubmenuItem())
        menu.addItem(buildShapeSubmenuItem())
        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit Palm", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    private func buildColorSubmenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Pointer Color", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for option in PointerColorOption.allCases {
            let sub = NSMenuItem(title: option.displayName, action: #selector(selectColor(_:)), keyEquivalent: "")
            sub.target = self
            sub.representedObject = option
            sub.state = Preferences.shared.pointerColor == option ? .on : .off
            submenu.addItem(sub)
        }
        item.submenu = submenu
        return item
    }

    private func buildShapeSubmenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Pointer Shape", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for option in PointerShapeOption.allCases {
            let sub = NSMenuItem(title: option.displayName, action: #selector(selectShape(_:)), keyEquivalent: "")
            sub.target = self
            sub.representedObject = option
            sub.state = Preferences.shared.pointerShape == option ? .on : .off
            submenu.addItem(sub)
        }
        item.submenu = submenu
        return item
    }

    @objc private func toggleHandKeyboard() {
        Preferences.shared.isHandKeyboardEnabled.toggle()
        statusItem.menu = buildMenu()
        syncFeatureState()
    }

    @objc private func toggleVoiceDictation() {
        Preferences.shared.isVoiceDictationEnabled.toggle()
        statusItem.menu = buildMenu()
        syncFeatureState()
    }

    @objc private func selectColor(_ sender: NSMenuItem) {
        guard let option = sender.representedObject as? PointerColorOption else { return }
        Preferences.shared.pointerColor = option
        statusItem.menu = buildMenu()
    }

    @objc private func selectShape(_ sender: NSMenuItem) {
        guard let option = sender.representedObject as? PointerShapeOption else { return }
        Preferences.shared.pointerShape = option
        statusItem.menu = buildMenu()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func syncFeatureState() {
        if Preferences.shared.isHandKeyboardEnabled {
            handTracker.start()
            overlayWindow?.orderFrontRegardless()
        } else {
            handTracker.stop()
            overlayWindow?.orderOut(nil)
        }

        if Preferences.shared.isVoiceDictationEnabled {
            voiceDictation.start()
        } else {
            voiceDictation.stop()
        }
    }

    nonisolated func handTracker(_ tracker: HandTracker, didUpdate hands: [HandPointerState]) {
        Task { @MainActor [overlayModel] in
            overlayModel.update(hands: hands)
        }
    }
}
