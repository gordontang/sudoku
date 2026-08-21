import SwiftUI

/// What the player sees between the system launch image and the home screen,
/// while the app opens its store. Sits on the same system background as the
/// static launch screen, so the hand-off is a content fade, not a flash.
struct LaunchLoadingView: View {
    /// Set when the store couldn't be opened; the screen turns into a
    /// retry prompt instead of spinning forever.
    var failure: Error?
    var retry: () -> Void = {}

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 28) {
                LaunchMark(animating: failure == nil)
                    .frame(width: 104, height: 104)
                Text("Sudoku")
                    .font(.title.weight(.semibold))
                if let failure {
                    failureBody(failure)
                } else {
                    ProgressView()
                        .controlSize(.regular)
                        .tint(.secondary)
                }
            }
            .padding(32)
            // Push the block a little above true center — where the home
            // title lands — so the eye doesn't jump on hand-off.
            .offset(y: -24)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("loading_screen")
    }

    private func failureBody(_ error: Error) -> some View {
        VStack(spacing: 14) {
            Text("Couldn't open your saved games.")
                .font(.headline)
            Text(error.localizedDescription)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try Again", action: retry)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("loading_retry")
        }
        .frame(maxWidth: 320)
    }
}

/// The app icon, redrawn in SwiftUI: a blue tile with a 3×3 grid and five
/// digits. While loading, the digits are written in one at a time on a loop
/// — the app "filling in" the grid — which reads as activity without a
/// second spinner competing for attention.
private struct LaunchMark: View {
    var animating: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Digits in the order they appear; positions mirror the icon.
    private static let digits: [(row: Int, col: Int, text: String)] = [
        (0, 0, "5"), (0, 2, "7"), (1, 1, "3"), (2, 0, "1"), (2, 2, "9"),
    ]
    private static let stepDuration: TimeInterval = 0.32
    /// Five writes, then two beats of rest before the grid clears.
    private static let cycleSteps = digits.count + 2

    var body: some View {
        if animating && !reduceMotion {
            TimelineView(.periodic(from: .now, by: Self.stepDuration)) { context in
                tile(visibleDigits: visibleCount(at: context.date))
            }
        } else {
            tile(visibleDigits: Self.digits.count)
        }
    }

    private func visibleCount(at date: Date) -> Int {
        let step = Int(date.timeIntervalSinceReferenceDate / Self.stepDuration) % Self.cycleSteps
        return min(step + 1, Self.digits.count)
    }

    private func tile(visibleDigits: Int) -> some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let inset = side * 0.16
            let cell = (side - inset * 2) / 3
            ZStack {
                RoundedRectangle(cornerRadius: side * 0.22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.20, green: 0.33, blue: 0.72),
                                Color(red: 0.32, green: 0.56, blue: 0.92),
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .shadow(color: .black.opacity(0.18), radius: side * 0.08, y: side * 0.04)

                // Grid lines, drawn rather than laid out so they stay crisp.
                Path { p in
                    for i in 1..<3 {
                        let off = inset + cell * CGFloat(i)
                        p.move(to: CGPoint(x: off, y: inset))
                        p.addLine(to: CGPoint(x: off, y: side - inset))
                        p.move(to: CGPoint(x: inset, y: off))
                        p.addLine(to: CGPoint(x: side - inset, y: off))
                    }
                }
                .stroke(Color.white.opacity(0.9), lineWidth: max(1, side * 0.018))
                RoundedRectangle(cornerRadius: side * 0.06, style: .continuous)
                    .inset(by: inset)
                    .stroke(Color.white.opacity(0.95), lineWidth: max(1.5, side * 0.028))

                ForEach(Array(Self.digits.enumerated()), id: \.offset) { index, digit in
                    Text(digit.text)
                        .font(.system(size: cell * 0.62, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .opacity(index < visibleDigits ? 1 : 0)
                        .animation(.easeOut(duration: 0.25), value: visibleDigits)
                        .position(
                            x: inset + cell * (CGFloat(digit.col) + 0.5),
                            y: inset + cell * (CGFloat(digit.row) + 0.5)
                        )
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityHidden(true)
    }
}

#Preview("Loading") {
    LaunchLoadingView()
}

#Preview("Failed") {
    LaunchLoadingView(failure: CocoaError(.fileReadCorruptFile))
}
