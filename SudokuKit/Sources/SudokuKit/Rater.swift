public enum Rater {
    /// Rate a puzzle by the hardest technique the logical solver needs.
    /// Deterministic: the solver has no randomness.
    public static func rate(_ givens: Grid) -> Difficulty {
        let result = Solver.solveLogically(givens)
        guard result.solved != nil else {
            // Logic stalls; search is required.
            return .master
        }
        switch result.techniques.max() ?? .nakedSingle {
        case .nakedSingle, .hiddenSingle:
            return .easy
        case .lockedCandidates:
            return .medium
        case .nakedPair, .hiddenPair:
            return .hard
        case .nakedTriple, .xWing:
            return .expert
        }
    }
}
