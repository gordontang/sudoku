import SudokuKit
import SwiftData
import SwiftUI

struct StatsView: View {
    @Query(sort: \CompletedGame.finishedAt) private var games: [CompletedGame]
    @Environment(\.modelContext) private var modelContext
    @State private var showResetConfirmation = false

    var body: some View {
        List {
            overallSection
            ForEach(Difficulty.allCases) { difficulty in
                let subset = games.filter { $0.difficultyRaw == difficulty.rawValue }
                if !subset.isEmpty {
                    Section(difficulty.displayName) {
                        DifficultyStatsView(games: subset)
                    }
                }
            }
            if !games.isEmpty {
                Section {
                    Button("Reset Statistics", role: .destructive) {
                        showResetConfirmation = true
                    }
                }
            }
        }
        .navigationTitle("Statistics")
        .overlay {
            if games.isEmpty {
                ContentUnavailableView(
                    "No games yet",
                    systemImage: "chart.bar",
                    description: Text("Finish a puzzle and your stats will appear here.")
                )
            }
        }
        .confirmationDialog(
            "Reset all statistics?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) {
                for game in games { modelContext.delete(game) }
                try? modelContext.save()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes every recorded game.")
        }
    }

    @ViewBuilder
    private var overallSection: some View {
        let solved = games.filter(\.completed)
        if !games.isEmpty {
            Section("Overall") {
                StatRow(title: "Puzzles solved", value: "\(solved.count)")
                StatRow(title: "Puzzles started", value: "\(games.count)")
                StatRow(
                    title: "Completion rate",
                    value: games.isEmpty ? "—" : "\(Int((Double(solved.count) / Double(games.count) * 100).rounded()))%"
                )
                StatRow(
                    title: "Total time played",
                    value: games.reduce(0) { $0 + $1.seconds }.timerString
                )
            }
        }
    }
}

private struct DifficultyStatsView: View {
    let games: [CompletedGame] // sorted by finishedAt ascending

    var body: some View {
        let solved = games.filter(\.completed)
        StatRow(title: "Solved", value: "\(solved.count) of \(games.count)")
        if !solved.isEmpty {
            StatRow(title: "Best time", value: solved.map(\.seconds).min()!.timerString)
            StatRow(
                title: "Average time",
                value: (solved.reduce(0) { $0 + $1.seconds } / Double(solved.count)).timerString
            )
            StatRow(
                title: "Average mistakes",
                value: String(format: "%.1f", Double(solved.reduce(0) { $0 + $1.mistakes }) / Double(solved.count))
            )
            let perfect = solved.count { $0.mistakes == 0 && $0.hints == 0 }
            StatRow(title: "Perfect solves", value: "\(perfect)")
            StatRow(title: "Best score", value: "\(solved.map(\.score).max() ?? 0)")
            StatRow(title: "Current streak", value: "\(currentStreak)")
            StatRow(title: "Longest streak", value: "\(longestStreak)")
            if solved.count >= 2 {
                trendView(times: solved.suffix(10).map(\.seconds))
            }
        }
    }

    /// Consecutive wins counted back from the most recent game.
    private var currentStreak: Int {
        var streak = 0
        for game in games.reversed() {
            if game.completed { streak += 1 } else { break }
        }
        return streak
    }

    private var longestStreak: Int {
        var best = 0, run = 0
        for game in games {
            run = game.completed ? run + 1 : 0
            best = max(best, run)
        }
        return best
    }

    private func trendView(times: [Double]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Recent solve times")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(alignment: .bottom, spacing: 4) {
                let maxTime = times.max() ?? 1
                ForEach(Array(times.enumerated()), id: \.offset) { _, time in
                    VStack(spacing: 2) {
                        Capsule()
                            .fill(Color.accentColor.opacity(0.7))
                            .frame(height: max(8, 40 * time / maxTime))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 44)
            .accessibilityLabel(
                "Recent solve times: " + times.map(\.timerString).joined(separator: ", ")
            )
        }
        .padding(.vertical, 4)
    }
}

private struct StatRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}
