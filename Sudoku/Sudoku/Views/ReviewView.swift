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
            if !review.requiredTechniques.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("This puzzle needed")
                        .foregroundStyle(.secondary)
                    Text(review.requiredTechniques.map(\.displayName).joined(separator: " · "))
                        .font(.footnote.weight(.medium))
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

/// A static board snapshot: the position as the player saw it, with the
/// true candidates penciled in and the review's annotations applied.
struct ReviewBoardView: View {
    let board: SudokuKit.Grid
    let annotations: BoardAnnotations

    private var marks: [CandidateSet] { board.candidates() }

    var body: some View {
        let marks = self.marks
        VStack(spacing: 0) {
            ForEach(0..<9, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<9, id: \.self) { col in
                        cell(row * 9 + col, marks: marks)
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .background(Theme.boardBackground)
        .overlay(ReviewGridLines(major: false).stroke(Theme.gridLineMinor, lineWidth: 0.5))
        .overlay(ReviewGridLines(major: true).stroke(Theme.gridLineMajor, lineWidth: 1.5))
        .overlay {
            if !annotations.links.isEmpty {
                ChainLinksOverlay(links: annotations.links)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .accessibilityHidden(true)
    }

    private func cell(_ index: Int, marks: [CandidateSet]) -> some View {
        ZStack {
            Rectangle().fill(background(index))
            if board.cells[index] != 0 {
                Text("\(board.cells[index])")
                    .font(.system(size: 15))
                    .minimumScaleFactor(0.4)
                    .foregroundStyle(Theme.givenText)
            } else if !marks[index].isEmpty {
                markGrid(index, marks: marks[index])
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func background(_ index: Int) -> Color {
        switch annotations.cells[index] {
        case .pattern, .alternate: Theme.cellSameDigit
        case .elimination: Theme.cellMistake
        case .context: Theme.cellPeer
        case nil: .clear
        }
    }

    private func markGrid(_ index: Int, marks: CandidateSet) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { c in
                        let digit = UInt8(r * 3 + c + 1)
                        let present = marks.contains(digit: digit)
                        let role = annotations.candidates[BoardAnnotations.Candidate(cell: index, digit: digit)]
                        Text(present ? "\(digit)" : " ")
                            .font(.system(size: 7, weight: present && role != nil ? .bold : .regular))
                            .minimumScaleFactor(0.5)
                            .foregroundStyle(markColor(present: present, role: role))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .padding(1)
    }

    private func markColor(present: Bool, role: BoardAnnotations.Role?) -> Color {
        guard present else { return .clear }
        switch role {
        case .pattern: return Color.accentColor
        case .alternate: return Theme.annotationAlt
        case .elimination: return Theme.mistakeText
        case .context, nil: return Theme.pencilText
        }
    }
}

/// Same drawing as the game board's grid lines, local to the review board.
private struct ReviewGridLines: Shape {
    let major: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let steps = major ? [0, 3, 6, 9] : [1, 2, 4, 5, 7, 8]
        for i in steps {
            let x = rect.minX + rect.width * CGFloat(i) / 9
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
            let y = rect.minY + rect.height * CGFloat(i) / 9
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        return path
    }
}
