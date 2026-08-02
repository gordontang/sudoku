import Testing
@testable import SudokuKit

// A well-known 17-clue puzzle with a unique solution.
private let seventeenClue =
    "000000010400000000020000000000050407008000300001090000300400200050100000000806000"

@Suite struct GridTests {
    @Test func geometry() {
        #expect(Grid.units.count == 27)
        #expect(Grid.units.allSatisfy { $0.count == 9 })
        #expect(Grid.peers.count == 81)
        #expect(Grid.peers.allSatisfy { $0.count == 20 })
        #expect(Grid.box(of: 0) == 0)
        #expect(Grid.box(of: 80) == 8)
        #expect(Grid.box(of: 40) == 4)
    }

    @Test func parsing() {
        let grid = Grid(string: seventeenClue)
        #expect(grid != nil)
        #expect(grid!.clueCount == 17)
        #expect(grid!.isValid)
    }

    @Test func candidateMath() {
        var set = CandidateSet.all
        #expect(set.count == 9)
        set.remove(digit: 5)
        #expect(set.count == 8)
        #expect(!set.contains(digit: 5))
        #expect(set.first == 1)
        #expect(CandidateSet(digit: 7).digits == [7])
    }
}

@Suite struct GeneratorTests {
    @Test func fullGridIsValid() {
        var rng = SeededRNG(seed: 1)
        let grid = Generator.fillGrid(using: &rng)
        #expect(grid.isFull)
        #expect(grid.isValid)
        #expect(grid.isSolved)
    }

    @Test(arguments: Difficulty.allCases)
    func puzzlesHaveUniqueSolutions(difficulty: Difficulty) {
        var rng = SeededRNG(seed: UInt64(difficulty.rawValue) &+ 42)
        for _ in 0..<10 {
            let puzzle = Generator.generate(difficulty: difficulty, using: &rng)
            #expect(puzzle.solution.isSolved)
            #expect(Solver.countSolutions(puzzle.givens, limit: 2) == 1)
            // The stored solution must actually solve the givens.
            let solved = Solver.firstSolution(puzzle.givens)
            #expect(solved == puzzle.solution)
            // Givens must be a subset of the solution.
            for i in 0..<81 where puzzle.givens.cells[i] != 0 {
                #expect(puzzle.givens.cells[i] == puzzle.solution.cells[i])
            }
        }
    }

    @Test func easySolvesWithSinglesOnly() {
        var rng = SeededRNG(seed: 7)
        for _ in 0..<10 {
            let puzzle = Generator.generate(difficulty: .easy, using: &rng)
            let result = Solver.solveLogically(puzzle.givens)
            #expect(result.solved != nil)
            #expect(result.techniques.allSatisfy { $0 <= .hiddenSingle })
        }
    }

    @Test func generationSpeed() {
        let clock = ContinuousClock()
        for difficulty in Difficulty.allCases {
            var rng = SeededRNG(seed: 99)
            let elapsed = clock.measure {
                _ = Generator.generate(difficulty: difficulty, using: &rng)
            }
            #expect(elapsed < .seconds(5), "\(difficulty) generation took \(elapsed)")
        }
    }
}

@Suite struct SolverTests {
    @Test func ratingIsDeterministic() {
        var rng = SeededRNG(seed: 3)
        let puzzle = Generator.generate(difficulty: .hard, using: &rng)
        let first = Rater.rate(puzzle.givens)
        for _ in 0..<100 {
            #expect(Rater.rate(puzzle.givens) == first)
        }
    }

    @Test func knownSeventeenCluePuzzle() {
        let grid = Grid(string: seventeenClue)!
        #expect(Solver.countSolutions(grid, limit: 2) == 1)
        let solution = Solver.firstSolution(grid)
        #expect(solution != nil)
        #expect(solution!.isSolved)
    }

    @Test func countSolutionsHonorsLimit() {
        // An empty grid has a vast number of solutions; the limit must stop
        // the search immediately rather than enumerate them.
        let empty = Grid()
        #expect(Solver.countSolutions(empty, limit: 2) == 2)
    }

    @Test func solveLogicallyDetectsStall() {
        // An empty grid offers no deduction at all — the solver must report
        // a stall rather than guess.
        let result = Solver.solveLogically(Grid())
        #expect(result.solved == nil)
    }

    @Test func logicalSolutionMatchesSearch() {
        // When the technique solver does solve a grid, it must agree with DFS.
        let grid = Grid(string: seventeenClue)!
        let logical = Solver.solveLogically(grid)
        if let solved = logical.solved {
            #expect(solved == Solver.firstSolution(grid))
        }
    }
}

@Suite struct HintTests {
    @Test func hintOnFreshEasyPuzzle() {
        var rng = SeededRNG(seed: 11)
        let puzzle = Generator.generate(difficulty: .easy, using: &rng)
        let hint = HintEngine.hint(for: puzzle.givens)
        #expect(hint != nil)
        // The hinted digit must match the solution.
        #expect(puzzle.solution.cells[hint!.cell] == hint!.digit)
        #expect(!hint!.explanation.isEmpty)
    }

    @Test func hintsSolveEntirePuzzle() {
        var rng = SeededRNG(seed: 13)
        let puzzle = Generator.generate(difficulty: .medium, using: &rng)
        var grid = puzzle.givens
        var steps = 0
        while !grid.isFull, let hint = HintEngine.hint(for: grid) {
            #expect(puzzle.solution.cells[hint.cell] == hint.digit)
            grid.cells[hint.cell] = hint.digit
            steps += 1
            #expect(steps <= 81)
        }
        #expect(grid == puzzle.solution)
    }

    @Test func noHintForInvalidGrid() {
        var grid = Grid()
        grid[0, 0] = 5
        grid[0, 1] = 5
        #expect(HintEngine.hint(for: grid) == nil)
    }
}
