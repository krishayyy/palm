import AppKit
import CoreGraphics

// Drives the real macOS cursor from hand-tracking updates instead of a fake
// on-screen pointer: moves it to the tracked fingertip, and treats pinch as
// the left mouse button (down on pinch-start, dragged while held, up on
// release) so click-and-drag gestures work like a real trackpad.
@MainActor
final class CursorController {
    private var isDragging = false

    // Only one hand drives the cursor even if two are tracked, otherwise the
    // pointer would jump between hands every frame; Vision's result order
    // isn't guaranteed stable, but in practice the same hand wins consistently
    // frame-to-frame since it's the only one present most of the time.
    func update(hands: [HandPointerState]) {
        guard let hand = hands.first else { return }

        let screen = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let point = CGPoint(
            x: hand.normalizedPosition.x * screen.width,
            y: (1 - hand.normalizedPosition.y) * screen.height
        )

        if hand.isPinching {
            if !isDragging {
                isDragging = true
                InputInjector.postMouseEvent(type: .leftMouseDown, at: point)
            } else {
                InputInjector.postMouseEvent(type: .leftMouseDragged, at: point)
            }
        } else {
            if isDragging {
                isDragging = false
                InputInjector.postMouseEvent(type: .leftMouseUp, at: point)
            } else {
                InputInjector.postMouseEvent(type: .mouseMoved, at: point)
            }
        }
    }
}
