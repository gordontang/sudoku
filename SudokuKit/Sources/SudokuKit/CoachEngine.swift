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

    /// Every technique that applies in this position — one deduction per
    /// technique, cheapest first — so a player can choose which one to be
    /// coached on instead of always getting the cheapest. Positions with a
    /// naked single available usually also hold an X-Wing or a chain
    /// somewhere; this is how the coach shows them.
    public static func availableDeductions(for grid: Grid, givens: Grid? = nil) -> [Deduction] {
        guard grid.isValid else { return [] }
        let cands = grid.candidates()
        var result: [Deduction] = []
        for technique in Technique.allCases {
            guard let d = Techniques.finder(for: technique, givens: givens)(grid, cands) else { continue }
            // Sibling techniques share a finder (naked/locked pair, the
            // turbot family), so the same deduction can come back twice.
            if !result.contains(where: { $0.technique == d.technique }) {
                result.append(d)
            }
        }
        return result
    }
}
