import SwiftUI

// Renders one pointer per tracked hand at its mapped position within the overlay,
// visually distinguished by an L/R label so two-hand pinch-typing stays legible.
struct PointerView: View {
    @ObservedObject var model: HandOverlayModel

    var body: some View {
        GeometryReader { geometry in
            ForEach(model.hands) { hand in
                pointerGlyph(for: hand)
                    .position(
                        x: hand.state.normalizedPosition.x * geometry.size.width,
                        y: (1 - hand.state.normalizedPosition.y) * geometry.size.height
                    )
                    .animation(.easeOut(duration: 0.05), value: hand.state.normalizedPosition)
            }
        }
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func pointerGlyph(for hand: TrackedHand) -> some View {
        let color = Color(nsColor: Preferences.shared.pointerColor.nsColor)
        let isPinching = hand.state.isPinching
        let size: CGFloat = isPinching ? 34 : 26

        ZStack {
            switch Preferences.shared.pointerShape {
            case .circle:
                Circle()
                    .fill(color.opacity(isPinching ? 0.9 : 0.55))
                    .frame(width: size, height: size)
            case .ring:
                Circle()
                    .stroke(color, lineWidth: isPinching ? 5 : 3)
                    .frame(width: size, height: size)
            case .crosshair:
                CrosshairShape()
                    .stroke(color, lineWidth: isPinching ? 4 : 2.5)
                    .frame(width: size, height: size)
            }

            Text(hand.state.label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .offset(y: -size / 2 - 12)
        }
        .shadow(color: color.opacity(0.6), radius: isPinching ? 8 : 3)
    }
}

private struct CrosshairShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midX = rect.midX
        let midY = rect.midY
        path.move(to: CGPoint(x: rect.minX, y: midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: midY))
        path.move(to: CGPoint(x: midX, y: rect.minY))
        path.addLine(to: CGPoint(x: midX, y: rect.maxY))
        return path
    }
}
