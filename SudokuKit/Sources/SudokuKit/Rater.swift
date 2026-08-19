public enum Rater {
    /// Rate a puzzle by the hardest technique the logical solver needs.
    /// Deterministic: the solver has no randomness. Master means the puzzle
    /// required a master-band technique — or stalled the whole ladder.
    public static func rate(_ givens: Grid) -> Difficulty {
        let result = Solver.solveLogically(givens)
        guard result.solved != nil else {
            // Even the full ladder stalls; search is required.
            return .master
        }
        return (result.techniques.max() ?? .nakedSingle).band
    }
}
