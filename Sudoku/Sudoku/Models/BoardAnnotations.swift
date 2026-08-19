import SudokuKit

/// The board's semantic highlight vocabulary. Hints, the coach, and game
/// review describe what to show in these terms and BoardView renders them —
/// one rendering path, many consumers.
///
/// Entries exist at two grains: whole cells, and individual pencil marks.
/// Candidate-level tinting matters because advanced patterns (fish, coloring,
/// chains) live on marks, not cells.
struct BoardAnnotations: Equatable {
    enum Role: Equatable {
        /// Part of the pattern being shown.
        case pattern
        /// The pattern's second polarity: color B of a coloring, the
        /// alternate chain nodes, a fish's fins.
        case alternate
        /// Loses candidates because of the pattern.
        case elimination
        /// The surrounding scope (the pattern's unit) — shaded quietly.
        case context
    }

    struct Candidate: Hashable {
        let cell: Int
        let digit: UInt8
    }

    var cells: [Int: Role] = [:]
    var candidates: [Candidate: Role] = [:]
    /// Chain links to draw between candidates (solid = strong, dashed = weak).
    var links: [ChainLink] = []

    var isEmpty: Bool { cells.isEmpty && candidates.isEmpty && links.isEmpty }

    init() {}

    /// Highlights explaining a hint: the justifying pattern's cells, inside
    /// their home unit for orientation. A hidden single reads instantly when
    /// its whole row is shaded and the target cell pops.
    init(hint: Hint) {
        if let unit = hint.unit {
            for i in SudokuKit.Grid.units[unit] {
                cells[i] = .context
            }
        }
        for i in hint.patternCells {
            cells[i] = .pattern
        }
    }

    /// Highlights for a deduction, at increasing reveal levels:
    /// - `.location`: just the home unit (or nothing when the pattern spans
    ///   units) — where to look, not what to see.
    /// - `.pattern`: the pattern's cells and candidate marks, links included.
    /// - `.full`: the pattern plus what it eliminates.
    enum Reveal {
        case location
        case pattern
        case full
    }

    init(deduction: Deduction, reveal: Reveal) {
        if let unit = deduction.unit {
            for i in SudokuKit.Grid.units[unit] {
                cells[i] = .context
            }
        }
        guard reveal != .location else { return }
        for i in deduction.patternCells {
            cells[i] = .pattern
        }
        for ref in deduction.patternCandidates {
            candidates[Candidate(cell: ref.cell, digit: ref.digit)] = .pattern
        }
        for ref in deduction.secondaryCandidates {
            candidates[Candidate(cell: ref.cell, digit: ref.digit)] = .alternate
        }
        links = deduction.links
        guard reveal == .full else { return }
        if case .eliminate(let elims) = deduction.kind {
            for (cell, digits) in elims {
                if cells[cell] == nil { cells[cell] = .elimination }
                for d in digits.digits {
                    candidates[Candidate(cell: cell, digit: d)] = .elimination
                }
            }
        }
        if case .place(let cell, let digit) = deduction.kind {
            cells[cell] = .pattern
            candidates[Candidate(cell: cell, digit: digit)] = .pattern
        }
    }
}
