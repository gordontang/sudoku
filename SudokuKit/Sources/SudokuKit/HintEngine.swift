public struct Hint: Sendable {
    public let cell: Int
    public let digit: UInt8
    public let technique: Technique
    public let explanation: String
}

public enum HintEngine {
    /// The next logical placement for the current position, with a
    /// human-readable explanation.
    ///
    /// Elimination deductions are applied silently until a placement
    /// deduction appears; the placement's technique is what gets reported.
    /// Returns nil when logic stalls (or the grid contains contradictions) —
    /// callers should then fall back to revealing a digit from the solution.
    public static func hint(for grid: Grid) -> Hint? {
        guard grid.isValid else { return nil }
        var g = grid
        var cands = g.candidates()
        while let deduction = Techniques.findDeduction(grid: g, candidates: cands) {
            switch deduction.kind {
            case .place(let cell, let digit):
                return Hint(
                    cell: cell,
                    digit: digit,
                    technique: deduction.technique,
                    explanation: deduction.explanation
                )
            case .eliminate:
                Solver.apply(deduction, to: &g, candidates: &cands)
            }
        }
        return nil
    }
}
