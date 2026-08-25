import SudokuKit
import SwiftData
import SwiftUI

/// Every recorded game, newest first. Games that stored the puzzle and move
/// log open the same post-game review offered on the victory screen, so a
/// review skipped at the time is never lost.
struct PastGamesView: View {
    @Query(sort: \CompletedGame.finishedAt, order: .reverse) private var games: [CompletedGame]

    var body: some View {
        List {
            ForEach(games) { game in
                if let input = game.reviewInput {
                    NavigationLink {
                        ReviewView(
                            givens: input.givens,
                            solution: input.solution,
                            difficulty: game.difficulty,
                            log: input.log
                        )
                    } label: {
                        PastGameRow(game: game, reviewable: true)
                    }
                } else {
                    // Recorded before the puzzle was stored — stats only.
                    PastGameRow(game: game, reviewable: false)
                }
            }
        }
        .navigationTitle("Past Games")
        .overlay {
            if games.isEmpty {
                ContentUnavailableView(
                    "No games yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Finish a puzzle and it will appear here, ready to review.")
                )
            }
        }
    }
}

private struct PastGameRow: View {
    let game: CompletedGame
    let reviewable: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: game.completed ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(game.completed ? Color.accentColor : Theme.mistakeText)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(game.difficulty.displayName) · \(game.completed ? "Solved" : "Not solved")")
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if !reviewable {
                    Text("Review unavailable for this game")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var detail: String {
        var parts = [
            game.finishedAt.formatted(date: .abbreviated, time: .shortened),
            game.seconds.timerString,
        ]
        parts.append(game.mistakes == 1 ? "1 mistake" : "\(game.mistakes) mistakes")
        return parts.joined(separator: " · ")
    }
}
