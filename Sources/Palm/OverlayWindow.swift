import AppKit
import SwiftUI

// A borderless, click-through, always-on-top window that hosts the hand-tracking
// keyboard + pointer overlay above every other app on screen.
final class OverlayWindow: NSPanel {

    init(handTrackerModel: HandOverlayModel) {
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let overlayHeight = screenFrame.height * 0.55
        let overlayFrame = NSRect(
            x: screenFrame.minX,
            y: screenFrame.minY,
            width: screenFrame.width,
            height: overlayHeight
        )

        super.init(
            contentRect: overlayFrame,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        ignoresMouseEvents = true // never steal clicks from the real frontmost app
        isReleasedWhenClosed = false

        let hostingView = NSHostingView(rootView: OverlayRootView(model: handTrackerModel))
        hostingView.frame = NSRect(origin: .zero, size: overlayFrame.size)
        contentView = hostingView
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private struct OverlayRootView: View {
    @ObservedObject var model: HandOverlayModel

    var body: some View {
        ZStack {
            KeyboardOverlayView(model: model)
            PointerView(model: model)
        }
    }
}
