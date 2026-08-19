import SwiftUI

struct VictoryView: View {
    let vm: GameViewModel
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            content
        }
    }

    private var content: some View {
        VStack(spacing: 20) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 56))
                .foregroundStyle(.yellow)
                .padding(.top, 32)

            Text("Puzzle Complete!")
                .font(.title.bold())

            if vm.victoryIsRecord {
                Label("New \(vm.difficulty.displayName) record!", systemImage: "sparkles")
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
            }

            VStack(spacing: 12) {
                statRow("Score", "\(vm.score)")
                statRow("Time", vm.elapsed.timerString)
                if let best = vm.victoryPreviousBest, !vm.victoryIsRecord {
                    statRow("Best", best.timerString)
                }
                statRow("Mistakes", "\(vm.mistakeCount)")
                statRow("Hints", "\(vm.hintsUsed)")
                if vm.mistakeCount == 0 && vm.hintsUsed == 0 {
                    Label("Perfect solve", systemImage: "star.fill")
                        .font(.subheadline)
                        .foregroundStyle(.yellow)
                }
            }
            .padding(20)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 24)

            // Post-game coaching: stalls, mistakes, and what was available.
            NavigationLink {
                ReviewView(
                    givens: vm.givens,
                    solution: vm.solution,
                    difficulty: vm.difficulty,
                    log: vm.moveLog
                )
            } label: {
                Label("Review Game", systemImage: "magnifyingglass.circle")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, 24)
            .accessibilityIdentifier("victory_review")

            Button {
                dismiss()
                onDone()
            } label: {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 24)
            .accessibilityIdentifier("victory_done")

            Spacer()
        }
        .presentationDetents([.medium, .large])
    }

    private func statRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
    }
}
