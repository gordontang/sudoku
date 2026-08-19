import Foundation
import SudokuKit

/// A moment worth revisiting after the game: a long stall, or a wrong
/// placement. Each carries the board as it stood, plus annotations showing
/// what was available at that point.
struct ReviewMoment: Identifiable {
    enum Kind {
        case stall
        case mistake
    }

    let id: Int
    let kind: Kind
    /// Elapsed play time when the moment (stall end / mistake) happened.
    let time: Double
    /// Stall length; 0 for mistakes.
    let duration: Double
    let title: String
    let detail: String
    /// The board as the player saw it.
    let board: Grid
    /// What the coach would have pointed at.
    let annotations: BoardAnnotations
}

/// Post-game analysis: replay the move log, find the stalls and mistakes,
/// and for each one ask the engine what was actually available.
struct GameReview {
    let moments: [ReviewMoment]
    let totalTime: Double
    /// Seconds spent in detected stalls.
    let stallTime: Double
    let mistakes: Int
    let hints: Int
    let adviceRequests: Int
    /// Techniques the puzzle's logical solve path requires, in ladder order.
    let requiredTechniques: [Technique]

    /// Thinking gaps longer than this count as stalls.
    static func stallThreshold(for difficulty: Difficulty) -> Double {
        switch difficulty {
        case .easy: 45
        case .medium: 60
        case .hard: 75
        case .expert: 105
        case .master: 150
        }
    }

    static func analyze(
        givens: Grid, solution: Grid, difficulty: Difficulty, log: [LoggedAction]
    ) -> GameReview {
        let threshold = stallThreshold(for: difficulty)
        var board = givens
        var lastTime = 0.0
        var moments: [ReviewMoment] = []
        var stallTotal = 0.0
        var hints = 0
        var advice = 0
        var nextID = 0

        func momentID() -> Int {
            nextID += 1
            return nextID
        }

        for action in log {
            let gap = action.time - lastTime
            if gap > threshold {
                stallTotal += gap
                // What was available while the player was stuck?
                let (title, detail, annotations) = describeStall(
                    gap: gap, endedBy: action, board: board, givens: givens, solution: solution
                )
                moments.append(ReviewMoment(
                    id: momentID(), kind: .stall, time: action.time, duration: gap,
                    title: title, detail: detail, board: board, annotations: annotations
                ))
            }
            lastTime = action.time

            switch action.kind {
            case .hint: hints += 1
            case .advice where action.digit == 1: advice += 1
            default: break
            }

            if action.kind == .place, action.cell != LoggedAction.noCell {
                let cell = Int(action.cell)
                if action.digit != solution.cells[cell] {
                    moments.append(mistakeMoment(
                        id: momentID(), action: action, board: board, givens: givens, solution: solution
                    ))
                }
            }

            if action.affectsValues, action.cell != LoggedAction.noCell {
                let cell = Int(action.cell)
                board.cells[cell] = action.kind == .erase ? 0 : action.digit
            }
        }

        // Keep the worst stalls plus every mistake, in play order.
        let stalls = moments.filter { $0.kind == .stall }
            .sorted { $0.duration > $1.duration }
            .prefix(6)
        let stallIDs = Set(stalls.map(\.id))
        let kept = moments.filter { $0.kind == .mistake || stallIDs.contains($0.id) }
            .sorted { $0.time < $1.time }

        let solvePath = Solver.solveLogically(givens)
        return GameReview(
            moments: kept,
            totalTime: log.last?.time ?? 0,
            stallTime: stallTotal,
            mistakes: kept.count { $0.kind == .mistake },
            hints: hints,
            adviceRequests: advice,
            requiredTechniques: solvePath.techniques.sorted()
        )
    }

    private static func describeStall(
        gap: Double, endedBy: LoggedAction, board: Grid, givens: Grid, solution: Grid
    ) -> (String, String, BoardAnnotations) {
        let minutes = gap.timerString
        // A stall with a wrong entry on the board is a different lesson:
        // nothing was findable because the position was already broken.
        let wrongCells = (0..<81).filter {
            givens.cells[$0] == 0 && board.cells[$0] != 0 && board.cells[$0] != solution.cells[$0]
        }
        if !wrongCells.isEmpty {
            var annotations = BoardAnnotations()
            for c in wrongCells { annotations.cells[c] = .elimination }
            return (
                "Stalled \(minutes)",
                "A wrong entry was already on the board — no technique can work from a broken position. When a puzzle suddenly stops cooperating, re-check recent placements (or run Check) before digging deeper.",
                annotations
            )
        }
        let available = CoachEngine.nextDeduction(for: board, givens: givens)
        var ending: String
        switch endedBy.kind {
        case .hint:
            ending = "You broke the stall with a hint."
        case .advice:
            ending = "You asked the coach — good instinct."
        case .place where endedBy.cell != LoggedAction.noCell:
            let cell = Int(endedBy.cell)
            ending = endedBy.digit == solution.cells[cell]
                ? "You eventually found \(endedBy.digit) at R\(cell / 9 + 1)C\(cell % 9 + 1)."
                : "You then placed a wrong digit — see the next moment."
        case .erase, .undoValue:
            ending = "You then backtracked."
        default:
            ending = "You then worked on your notes."
        }
        if let d = available {
            let what: String
            switch d.kind {
            case .place: what = "a \(d.technique.displayName) placement was available"
            case .eliminate: what = "a \(d.technique.displayName) elimination was available"
            }
            return (
                "Stalled \(minutes)",
                "While you were stuck, \(what): \(d.explanation) \(ending)",
                BoardAnnotations(deduction: d, reveal: .full)
            )
        }
        return (
            "Stalled \(minutes)",
            "No standard pattern applied here — this position genuinely needs chain analysis (Alts). \(ending)",
            BoardAnnotations()
        )
    }

    private static func mistakeMoment(
        id: Int, action: LoggedAction, board: Grid, givens: Grid, solution: Grid
    ) -> ReviewMoment {
        let cell = Int(action.cell)
        let name = "R\(cell / 9 + 1)C\(cell % 9 + 1)"
        let available = CoachEngine.nextDeduction(for: board, givens: givens)
        var annotations: BoardAnnotations
        var detail: String
        if let d = available {
            annotations = BoardAnnotations(deduction: d, reveal: .full)
            if case .place(let dCell, _) = d.kind, dCell == cell {
                detail = "The \(name) cell was actually deducible: \(d.explanation) Worth re-checking before committing — this reads like a misread rather than a guess."
            } else {
                detail = "There was solid ground elsewhere: \(d.explanation) Placing \(action.digit) at \(name) wasn't forced by anything — treat unforced placements as guesses and test them on an Alt instead."
            }
        } else {
            annotations = BoardAnnotations()
            detail = "No standard pattern applied at that point, so this was a genuine gamble. When logic runs dry, test the candidate on an Alt rather than the real board."
        }
        annotations.cells[cell] = .elimination
        return ReviewMoment(
            id: id, kind: .mistake, time: action.time, duration: 0,
            title: "Wrong \(action.digit) at \(name)",
            detail: detail, board: board, annotations: annotations
        )
    }
}
