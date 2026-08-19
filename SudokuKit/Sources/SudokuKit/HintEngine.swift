public struct Hint: Sendable {
    public let cell: Int
    public let digit: UInt8
    public let technique: Technique
    public let explanation: String
    /// Cells forming the justifying pattern (see `Deduction.patternCells`).
    public let patternCells: [Int]
    /// Home unit of the pattern, as an index into `Grid.units`.
    public let unit: Int?
    /// The digits the pattern reasons about.
    public let keyDigits: CandidateSet
}

public enum HintEngine {
    /// The next logical placement for the current position, with a
    /// human-readable explanation.
    ///
    /// Elimination deductions are applied silently until a placement
    /// deduction appears; the placement's technique is what gets reported.
    /// Returns nil when logic stalls (or the grid contains contradictions) —
    /// callers should then fall back to revealing a digit from the solution.
    public static func hint(for grid: Grid, givens: Grid? = nil) -> Hint? {
        guard grid.isValid else { return nil }
        var g = grid
        var cands = g.candidates()
        while let deduction = Techniques.findDeduction(grid: g, candidates: cands, givens: givens) {
            switch deduction.kind {
            case .place(let cell, let digit):
                return Hint(
                    cell: cell,
                    digit: digit,
                    technique: deduction.technique,
                    explanation: deduction.explanation,
                    patternCells: deduction.patternCells,
                    unit: deduction.unit,
                    keyDigits: deduction.keyDigits
                )
            case .eliminate:
                Solver.apply(deduction, to: &g, candidates: &cands)
            }
        }
        return nil
    }
}
