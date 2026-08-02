import SwiftUI

struct NumberPadView: View {
    @Bindable var vm: GameViewModel

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...9, id: \.self) { digit in
                let remaining = vm.remaining(of: UInt8(digit))
                let isLocked = vm.lockedDigit == UInt8(digit)
                Button {
                    vm.tapDigit(UInt8(digit))
                } label: {
                    VStack(spacing: 2) {
                        Text("\(digit)")
                            .font(.title2.weight(.medium))
                        Text("\(remaining)")
                            .font(.caption2)
                            .foregroundStyle(isLocked ? Color.accentColor : Color.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isLocked ? Color.accentColor.opacity(0.22) : Color(.secondarySystemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isLocked ? Color.accentColor : .clear, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
                // Long-press locks the digit (number-first entry): tap cells
                // to place it repeatedly, long-press again to release.
                .simultaneousGesture(
                    LongPressGesture().onEnded { _ in
                        vm.toggleLock(UInt8(digit))
                    }
                )
                .opacity(remaining == 0 ? 0.3 : 1)
                .disabled(remaining == 0 && !vm.pencilMode)
                .accessibilityLabel("Digit \(digit), \(remaining) remaining\(isLocked ? ", locked" : "")")
                .accessibilityIdentifier("digit_\(digit)")
            }
        }
    }
}
