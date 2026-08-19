import Testing
@testable import SudokuKit

/// Detector-level tests. The finders trust the candidate array they're given,
/// so most fixtures are synthetic: an empty grid plus hand-built candidates
/// encoding exactly one pattern. That pins down each technique — and its
/// metadata — without hand-crafting a full consistent position.
@Suite struct TechniqueTests {
    /// All cells full candidates, except the given overrides.
    private func cands(_ overrides: [Int: CandidateSet]) -> [CandidateSet] {
        var result = Array(repeating: CandidateSet.all, count: 81)
        for (cell, set) in overrides { result[cell] = set }
        return result
    }

    private func set(_ digits: [UInt8]) -> CandidateSet {
        CandidateSet(digits: digits)
    }

    // MARK: - Full house

    @Test func fullHouse() {
        // Row 1 misses only its last cell; the ladder must report it as a
        // full house, not a naked single.
        let grid = Grid(string:
            "123456780" + String(repeating: "0", count: 72))!
        let d = Techniques.findDeduction(grid: grid, candidates: grid.candidates())
        #expect(d != nil)
        #expect(d!.technique == .fullHouse)
        guard case .place(let cell, let digit) = d!.kind else {
            Issue.record("expected a placement")
            return
        }
        #expect(cell == 8)
        #expect(digit == 9)
        #expect(d!.patternCells == [8])
        #expect(d!.unit == 0)
        #expect(d!.keyDigits == set([9]))
    }

    // MARK: - Naked subsets

    @Test func nakedPair() {
        // {4,9} twice in row 1, in different boxes — a plain naked pair;
        // eliminations stay within the row.
        let c = cands([0: set([4, 9]), 4: set([4, 9])])
        let d = Techniques.nakedSubset(Grid(), c, size: 2)
        #expect(d != nil)
        #expect(d!.technique == .nakedPair)
        #expect(d!.patternCells == [0, 4])
        #expect(d!.keyDigits == set([4, 9]))
        let elimCells = Set(d!.eliminationCells)
        #expect(elimCells == Set([1, 2, 3, 5, 6, 7, 8]))
    }

    @Test func lockedPairCleansBothUnits() {
        // {4,9} twice in the row–box intersection: a locked pair. Both the
        // rest of row 1 and the rest of box 1 must be cleaned in one step.
        let c = cands([0: set([4, 9]), 1: set([4, 9])])
        let d = Techniques.nakedSubset(Grid(), c, size: 2)
        #expect(d != nil)
        #expect(d!.technique == .lockedPair)
        #expect(d!.patternCells == [0, 1])
        let elimCells = Set(d!.eliminationCells)
        // Rest of the row…
        #expect(elimCells.isSuperset(of: [2, 3, 4, 5, 6, 7, 8]))
        // …and the rest of the box, in the same deduction.
        #expect(elimCells.isSuperset(of: [9, 10, 11, 18, 19, 20]))
    }

    @Test func lockedTriple() {
        let c = cands([9: set([2, 6]), 10: set([2, 9]), 11: set([6, 9])])
        let d = Techniques.nakedSubset(Grid(), c, size: 3)
        #expect(d != nil)
        #expect(d!.technique == .lockedTriple)
        #expect(d!.patternCells == [9, 10, 11])
        #expect(d!.keyDigits == set([2, 6, 9]))
        let elimCells = Set(d!.eliminationCells)
        // Rest of row 2 and rest of box 1.
        #expect(elimCells.isSuperset(of: [12, 13, 14, 15, 16, 17]))
        #expect(elimCells.isSuperset(of: [0, 1, 2, 18, 19, 20]))
    }

    @Test func nakedQuad() {
        // Four cells of row 1 covering only {1,2,3,4} — spanning two boxes,
        // so it can't be reported as locked.
        let quad = set([1, 2, 3, 4])
        let c = cands([0: quad, 1: quad, 2: quad, 3: quad])
        let d = Techniques.nakedSubset(Grid(), c, size: 4)
        #expect(d != nil)
        #expect(d!.technique == .nakedQuad)
        #expect(d!.patternCells == [0, 1, 2, 3])
        #expect(d!.keyDigits == quad)
        #expect(Set(d!.eliminationCells) == Set([4, 5, 6, 7, 8]))
    }

    // MARK: - Hidden subsets

    @Test func hiddenPair() {
        // 4 and 9 fit only in the first two cells of row 1; those cells'
        // other candidates are noise.
        var overrides: [Int: CandidateSet] = [:]
        for i in 2...8 { overrides[i] = set([1, 2, 3, 5, 6, 7, 8]) }
        let d = Techniques.hiddenSubset(Grid(), cands(overrides), size: 2)
        #expect(d != nil)
        #expect(d!.technique == .hiddenPair)
        #expect(d!.patternCells == [0, 1])
        #expect(d!.unit == 0)
        #expect(d!.keyDigits == set([4, 9]))
        guard case .eliminate(let elims) = d!.kind else {
            Issue.record("expected eliminations")
            return
        }
        #expect(Set(elims.map(\.cell)) == Set([0, 1]))
        for (_, digits) in elims {
            #expect(digits == set([1, 2, 3, 5, 6, 7, 8]))
        }
    }

    @Test func hiddenTriple() {
        // 1, 2, 3 confined to the first three cells of row 1.
        var overrides: [Int: CandidateSet] = [:]
        for i in 3...8 { overrides[i] = set([4, 5, 6, 7, 8, 9]) }
        let d = Techniques.hiddenSubset(Grid(), cands(overrides), size: 3)
        #expect(d != nil)
        #expect(d!.technique == .hiddenTriple)
        #expect(d!.patternCells == [0, 1, 2])
        #expect(d!.keyDigits == set([1, 2, 3]))
        guard case .eliminate(let elims) = d!.kind else {
            Issue.record("expected eliminations")
            return
        }
        for (_, digits) in elims {
            #expect(digits == set([4, 5, 6, 7, 8, 9]))
        }
    }

    @Test func hiddenTripleDigitsNeedNotFillEveryCell() {
        // Each of 1, 2, 3 appears in only two of the three cells — still a
        // valid hidden triple on those cells.
        var overrides: [Int: CandidateSet] = [
            0: set([1, 2, 7, 8]),
            1: set([2, 3, 7, 8]),
            2: set([1, 3, 7, 8]),
        ]
        for i in 3...8 { overrides[i] = set([4, 5, 6, 7, 8, 9]) }
        let d = Techniques.hiddenSubset(Grid(), cands(overrides), size: 3)
        #expect(d != nil)
        #expect(d!.technique == .hiddenTriple)
        #expect(d!.patternCells == [0, 1, 2])
        #expect(d!.keyDigits == set([1, 2, 3]))
    }

    @Test func hiddenQuad() {
        // 1–4 confined to the first four cells of row 1.
        var overrides: [Int: CandidateSet] = [:]
        for i in 4...8 { overrides[i] = set([5, 6, 7, 8, 9]) }
        let d = Techniques.hiddenSubset(Grid(), cands(overrides), size: 4)
        #expect(d != nil)
        #expect(d!.technique == .hiddenQuad)
        #expect(d!.patternCells == [0, 1, 2, 3])
        #expect(d!.keyDigits == set([1, 2, 3, 4]))
    }

    // MARK: - X-Wing metadata

    @Test func xWingReportsCorners() {
        // 3 confined to columns 3 and 7 in rows 2 and 8 (the guide's example).
        var overrides: [Int: CandidateSet] = [:]
        let others = set([1, 2, 4, 5, 6, 7, 8, 9])
        for c in 0..<9 where c != 2 && c != 6 {
            overrides[9 + c] = others
            overrides[63 + c] = others
        }
        let d = Techniques.basicFish(Grid(), cands(overrides), size: 2)
        #expect(d != nil)
        #expect(d!.technique == .xWing)
        #expect(d!.patternCells == [11, 15, 65, 69])
        #expect(d!.keyDigits == set([3]))
        // Eliminations happen in the two columns, outside the two rows.
        #expect(!d!.eliminationCells.isEmpty)
        #expect(d!.eliminationCells.allSatisfy { $0 % 9 == 2 || $0 % 9 == 6 })
        #expect(d!.eliminationCells.allSatisfy { $0 / 9 != 1 && $0 / 9 != 7 })
    }

    // MARK: - Ladder integration

    @Test func deductionsAreSoundOnGeneratedPuzzles() {
        // Replay entire logical solves, checking every step against the known
        // solution: placements must match it, eliminations must never remove
        // the solution digit. Catches unsound detectors immediately.
        for difficulty in Difficulty.allCases {
            var rng = SeededRNG(seed: UInt64(difficulty.rawValue) &+ 17)
            let puzzle = Generator.generate(difficulty: difficulty, using: &rng)
            var grid = puzzle.givens
            var cands = grid.candidates()
            var steps = 0
            while let d = Techniques.findDeduction(grid: grid, candidates: cands) {
                switch d.kind {
                case .place(let cell, let digit):
                    #expect(puzzle.solution.cells[cell] == digit, "\(d.technique) placed a wrong digit")
                case .eliminate(let elims):
                    #expect(!elims.isEmpty)
                    for (cell, digits) in elims {
                        #expect(
                            !digits.contains(digit: puzzle.solution.cells[cell]),
                            "\(d.technique) eliminated the solution digit from cell \(cell)"
                        )
                    }
                }
                Solver.apply(d, to: &grid, candidates: &cands)
                steps += 1
                #expect(steps < 1000)
            }
        }
    }

    @Test func deductionsCarryPatternMetadata() {
        // Every deduction on a real solve names the cells that justify it.
        var rng = SeededRNG(seed: 29)
        let puzzle = Generator.generate(difficulty: .hard, using: &rng)
        var grid = puzzle.givens
        var cands = grid.candidates()
        while let d = Techniques.findDeduction(grid: grid, candidates: cands) {
            #expect(!d.patternCells.isEmpty, "\(d.technique) reported no pattern cells")
            #expect(!d.keyDigits.isEmpty, "\(d.technique) reported no key digits")
            #expect(!d.explanation.isEmpty)
            Solver.apply(d, to: &grid, candidates: &cands)
        }
    }

    @Test func hintCarriesPatternMetadata() {
        var rng = SeededRNG(seed: 11)
        let puzzle = Generator.generate(difficulty: .easy, using: &rng)
        let hint = HintEngine.hint(for: puzzle.givens)
        #expect(hint != nil)
        #expect(hint!.patternCells.contains(hint!.cell))
        #expect(hint!.keyDigits.contains(digit: hint!.digit))
    }

    @Test func containingUnits() {
        // Same row and box.
        #expect(Techniques.containingUnits(of: [0, 1]) == [0, 18])
        // Same row only.
        #expect(Techniques.containingUnits(of: [0, 4]) == [0])
        // Same column and box.
        #expect(Techniques.containingUnits(of: [0, 9]) == [9, 18])
        // Same box only.
        #expect(Techniques.containingUnits(of: [0, 10]) == [18])
        // Nothing shared.
        #expect(Techniques.containingUnits(of: [0, 40]).isEmpty)
    }
}
