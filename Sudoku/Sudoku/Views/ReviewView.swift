import SudokuKit
import SwiftUI

/// Post-game coaching: where time went, what was available during stalls,
/// and what each mistake should have been. Every moment is replayable — the
/// board is shown as it stood, with the engine's finding highlighted.
struct ReviewView: View {
    let givens: SudokuKit.Grid
    let solution: SudokuKit.Grid
    let difficulty: Difficulty
    let log: [LoggedAction]

    @State private var review: GameReview?

    var body: some View {
        Group {
            if let review {
                List {
                    summarySection(review)
                    techniquesSection(review)
                    if review.moments.isEmpty {
                        Section {
                            Label("No long stalls, no wrong entries — a clean, steady solve.", systemImage: "checkmark.seal")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Section("Key moments") {
                            ForEach(review.moments) { moment in
                                NavigationLink {
                                    ReviewMomentDetail(moment: moment)
                                } label: {
                                    momentRow(moment)
                                }
                            }
                        }
                    }
                }
            } else {
                ProgressView("Analyzing your game…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Game Review")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard review == nil else { return }
            let givens = givens, solution = solution, difficulty = difficulty, log = log
            review = await Task.detached(priority: .userInitiated) {
                GameReview.analyze(givens: givens, solution: solution, difficulty: difficulty, log: log)
            }.value
        }
    }

    private func summarySection(_ review: GameReview) -> some View {
        Section("How it went") {
            row("Time", review.totalTime.timerString)
            if review.stallTime > 0 {
                row("Time in stalls", review.stallTime.timerString)
            }
            row("Wrong entries", "\(review.mistakes)")
            row("Hints", "\(review.hints)")
            if review.adviceRequests > 0 {
                row("Coach requests", "\(review.adviceRequests)")
            }
        }
    }

    /// Each required technique, tappable to see the position on this
    /// puzzle's solve path where it actually fired.
    @ViewBuilder
    private func techniquesSection(_ review: GameReview) -> some View {
        if !review.techniqueExamples.isEmpty {
            Section("This puzzle needed") {
                ForEach(review.techniqueExamples) { example in
                    NavigationLink {
                        TechniqueExampleDetail(example: example, givens: givens)
                    } label: {
                        Text(example.technique.displayName)
                            .font(.subheadline.weight(.medium))
                    }
                }
            }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.semibold).monospacedDigit()
        }
    }

    private func momentRow(_ moment: ReviewMoment) -> some View {
        HStack(spacing: 10) {
            Image(systemName: moment.kind == .stall ? "hourglass" : "xmark.circle")
                .foregroundStyle(moment.kind == .stall ? Color.accentColor : Theme.mistakeText)
            VStack(alignment: .leading, spacing: 2) {
                Text(moment.title)
                    .font(.subheadline.weight(.semibold))
                Text("at \(moment.time.timerString)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct ReviewMomentDetail: View {
    let moment: ReviewMoment

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ReviewBoardView(board: moment.board, annotations: moment.annotations)
                    .frame(maxWidth: 360)
                    .frame(maxWidth: .infinity)
                Text(moment.detail)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
        }
        .navigationTitle(moment.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Where a technique actually appeared on this puzzle: the solve-path
/// position it first fired from, with the pattern highlighted and the
/// engine's reasoning below. Digits beyond the givens are the solve
/// path's own progress, drawn as entries.
private struct TechniqueExampleDetail: View {
    let example: GameReview.TechniqueExample
    let givens: SudokuKit.Grid

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SnapshotBoardView(
                    values: example.board,
                    givens: givens,
                    marks: example.marks,
                    annotations: example.annotations
                )
                .frame(maxWidth: 360)
                .frame(maxWidth: .infinity)
                Text("The first point in this puzzle's solve where \(example.technique.displayName) was the simplest available move:")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(example.detail)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
        }
        .navigationTitle(example.technique.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// A static board snapshot: the position as the player saw it, with the
/// true candidates penciled in and the review's annotations applied.
struct ReviewBoardView: View {
    let board: SudokuKit.Grid
    let annotations: BoardAnnotations

    var body: some View {
        SnapshotBoardView(values: board, marks: board.candidates(), annotations: annotations)
    }
}
