public struct LogicalResult: Sendable {
    /// The solved grid, or nil when the technique solver stalled.
    public let solved: Grid?
    /// Techniques that were required.
    public let techniques: Set<Technique>
}

public enum Solver {
    // MARK: - Logical solving

    /// Apply human techniques in ascending cost until solved or stuck.
    /// Deterministic for a given grid — no randomness.
    public static func solveLogically(_ start: Grid) -> LogicalResult {
        var grid = start
        var cands = grid.candidates()
        var used = Set<Technique>()
        while !grid.isFull {
            guard let deduction = Techniques.findDeduction(grid: grid, candidates: cands) else {
                return LogicalResult(solved: nil, techniques: used)
            }
            used.insert(deduction.technique)
            apply(deduction, to: &grid, candidates: &cands)
            // A contradiction (empty cell with no candidates) means the puzzle
            // is unsolvable from this state.
            for i in 0..<81 where grid.cells[i] == 0 && cands[i].isEmpty {
                return LogicalResult(solved: nil, techniques: used)
            }
        }
        return LogicalResult(solved: grid, techniques: used)
    }

    /// Apply a deduction, keeping the candidate array in sync.
    public static func apply(_ deduction: Deduction, to grid: inout Grid, candidates: inout [CandidateSet]) {
        switch deduction.kind {
        case .place(let cell, let digit):
            grid.cells[cell] = digit
            candidates[cell] = CandidateSet()
            for p in Grid.peers[cell] {
                candidates[p].remove(digit: digit)
            }
        case .eliminate(let elims):
            for (cell, digits) in elims {
                candidates[cell].subtract(digits)
            }
        }
    }

    // MARK: - Backtracking search

    /// Count solutions by DFS, stopping as soon as `limit` is reached.
    /// Uniqueness checks call this with `limit: 2`.
    public static func countSolutions(_ grid: Grid, limit: Int) -> Int {
        var g = grid
        var count = 0

        func dfs() -> Bool { // true = limit reached, unwind
            var best = -1
            var bestSet = CandidateSet()
            var bestCount = 10
            for i in 0..<81 where g.cells[i] == 0 {
                let set = g.candidateSet(at: i)
                let c = set.count
                if c == 0 { return false }
                if c < bestCount {
                    bestCount = c
                    best = i
                    bestSet = set
                    if c == 1 { break }
                }
            }
            if best == -1 {
                count += 1
                return count >= limit
            }
            for d in bestSet.digits {
                g.cells[best] = d
                if dfs() {
                    g.cells[best] = 0
                    return true
                }
                g.cells[best] = 0
            }
            return false
        }

        _ = dfs()
        return count
    }

    /// First solution found by DFS, or nil when unsolvable.
    public static func firstSolution(_ grid: Grid) -> Grid? {
        var g = grid

        func dfs() -> Bool {
            var best = -1
            var bestSet = CandidateSet()
            var bestCount = 10
            for i in 0..<81 where g.cells[i] == 0 {
                let set = g.candidateSet(at: i)
                let c = set.count
                if c == 0 { return false }
                if c < bestCount {
                    bestCount = c
                    best = i
                    bestSet = set
                    if c == 1 { break }
                }
            }
            if best == -1 { return true }
            for d in bestSet.digits {
                g.cells[best] = d
                if dfs() { return true }
                g.cells[best] = 0
            }
            return false
        }

        return dfs() ? g : nil
    }
}
