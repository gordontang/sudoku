import SudokuKit

/// The board's semantic highlight vocabulary. Hints (and later the coach,
/// lessons, and game review) describe what to show in these terms and
/// BoardView renders them — one rendering path, many consumers.
///
/// Entries exist at two grains: whole cells, and individual pencil marks.
/// Candidate-level tinting matters because advanced patterns (fish, coloring,
/// chains) live on marks, not cells.
struct BoardAnnotations: Equatable {
    enum Role: Equatable {
        /// Part of the pattern being shown.
        case pattern
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

    var isEmpty: Bool { cells.isEmpty && candidates.isEmpty }

    /// Highlights explaining a hint: the justifying pattern's cells, inside
    /// their home unit for orientation. A hidden single reads instantly when
    /// its whole row is shaded and the target cell pops.
    init(hint: Hint) {
        cells = [:]
        candidates = [:]
        if let unit = hint.unit {
            for i in SudokuKit.Grid.units[unit] {
                cells[i] = .context
            }
        }
        for i in hint.patternCells {
            cells[i] = .pattern
        }
    }

    init() {}
}
