/// The coach's engine entry point: unlike `HintEngine`, which skips ahead to
/// the next placement, the coach surfaces the cheapest available deduction —
/// eliminations included, because those are what actually teach.
public enum CoachEngine {
    /// The cheapest deduction available in this position, or nil when even
    /// the full technique ladder stalls (chain-analysis territory).
    public static func nextDeduction(for grid: Grid, givens: Grid? = nil) -> Deduction? {
        guard grid.isValid else { return nil }
        return Techniques.findDeduction(grid: grid, candidates: grid.candidates(), givens: givens)
    }
}
