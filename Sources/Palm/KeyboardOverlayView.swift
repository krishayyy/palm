import SwiftUI

// A QWERTY layout the user "types" on by hovering a hand pointer over a key and
// pinching. Highlights the key under each hand and flashes on pinch-click.
struct KeyboardOverlayView: View {
    @ObservedObject var model: HandOverlayModel

    private let rows: [[String]] = [
        ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"],
        ["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"],
        ["a", "s", "d", "f", "g", "h", "j", "k", "l"],
        ["z", "x", "c", "v", "b", "n", "m"],
        ["space", "delete", "return"]
    ]

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 10) {
                Spacer()
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 8) {
                        ForEach(row, id: \.self) { key in
                            KeyCapView(
                                label: key,
                                isHighlighted: model.keyUnderAnyHand == key,
                                isFlashing: model.flashingKey == key
                            )
                        }
                    }
                }
                Spacer().frame(height: geometry.size.height * 0.08)
            }
            .padding(.horizontal, 40)
            .background(
                GeometryReader { keyboardGeo in
                    Color.clear
                        .onAppear {
                            model.keyboardFrame = keyboardGeo.frame(in: .local)
                        }
                        .onChange(of: keyboardGeo.size) { _, _ in
                            model.keyboardFrame = keyboardGeo.frame(in: .local)
                        }
                }
            )
        }
    }
}

private struct KeyCapView: View {
    let label: String
    let isHighlighted: Bool
    let isFlashing: Bool

    private var displayLabel: String {
        switch label {
        case "space": return "␣"
        case "delete": return "⌫"
        case "return": return "⏎"
        default: return label.uppercased()
        }
    }

    private var widthMultiplier: CGFloat {
        switch label {
        case "space": return 5
        case "delete", "return": return 2
        default: return 1
        }
    }

    var body: some View {
        Text(displayLabel)
            .font(.system(size: 15, weight: .medium, design: .rounded))
            .foregroundColor(.white)
            .frame(width: 34 * widthMultiplier, height: 34)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isFlashing ? Color.green.opacity(0.85) : (isHighlighted ? Color.white.opacity(0.35) : Color.black.opacity(0.35)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.25), lineWidth: 1)
            )
            .scaleEffect(isFlashing ? 1.15 : (isHighlighted ? 1.05 : 1.0))
            .animation(.easeOut(duration: 0.1), value: isFlashing)
            .animation(.easeOut(duration: 0.1), value: isHighlighted)
    }
}
