import Testing
@testable import SudokuKit

/// The training engine: drill mining, the shipped bank, and answer checking.
@Suite struct TrainingTests {
    private func isSound(_ d: Deduction, solution: Grid) -> Bool {
        switch d.kind {
        case .place(let cell, let digit):
            return solution.cells[cell] == digit
        case .eliminate(let elims):
            return elims.allSatisfy { !$0.digits.contains(digit: solution.cells[$0.cell]) }
        }
    }

    // MARK: - Shipped bank

    @Test func bankCoversTheWholeLadder() {
        for t in Technique.allCases {
            #expect(TrainingBank.drills(for: t).count >= 4, "\(t.displayName) needs drills")
        }
    }

    /// Every shipped drill is what it claims: the technique is the cheapest
    /// deduction in the position, the deduction is sound, and the accepted
    /// answer set contains it.
    @Test(arguments: Technique.allCases)
    func bankDrillsAreValid(technique: Technique) {
        for drill in TrainingBank.drills(for: technique) {
            #expect(drill.technique == technique)
            #expect(drill.givens.clueCount <= drill.grid.clueCount)
            #expect(Solver.countSolutions(drill.givens, limit: 2) == 1)
            guard let d = drill.deduction else {
                Issue.record("\(technique.displayName) drill has no deduction")
                continue
            }
            #expect(d.technique == technique, "\(technique.displayName) drill's cheapest deduction is \(d.technique.displayName)")
            #expect(isSound(d, solution: drill.solution))
            // Notes are honest: every candidate is legal, every solution digit present.
            for i in 0..<81 where drill.grid.cells[i] == 0 {
                #expect(drill.candidates[i].isSubset(of: drill.grid.candidateSet(at: i)))
                #expect(drill.candidates[i].contains(digit: drill.solution.cells[i]))
            }
            let accepted = TrainingEngine.acceptedAnswers(for: drill)
            switch d.kind {
            case .place(let cell, let digit):
                #expect(accepted.placements.contains(CandidateRef(cell: cell, digit: digit)))
                #expect(TrainingEngine.check(.place(cell: cell, digit: digit), against: drill) == .correct)
            case .eliminate(let elims):
                for (cell, digits) in elims {
                    for digit in digits.digits {
                        #expect(accepted.eliminations.contains(CandidateRef(cell: cell, digit: digit)))
                        #expect(TrainingEngine.check(.eliminate(cell: cell, digit: digit), against: drill) == .correct)
                    }
                }
            }
            // Accepted answers never contradict the solution.
            for ref in accepted.placements {
                #expect(drill.solution.cells[ref.cell] == ref.digit)
            }
            for ref in accepted.eliminations {
                #expect(drill.solution.cells[ref.cell] != ref.digit)
                #expect(drill.candidates[ref.cell].contains(digit: ref.digit))
            }
        }
    }

    @Test func bankExamplesAreTheTersest() {
        // The first entry doubles as the lesson's worked example.
        for t in [Technique.nakedPair, .xWing, .xyWing, .swordfish] {
            let drills = TrainingBank.drills(for: t)
            let lengths = drills.compactMap { $0.deduction?.explanation.count }
            #expect(lengths.first == lengths.min())
        }
    }

    // MARK: - Verdicts

    @Test func placementVerdicts() throws {
        let drill = try #require(TrainingBank.drills(for: .hiddenSingle).first)
        let d = try #require(drill.deduction)
        guard case .place(let cell, let digit) = d.kind else {
            Issue.record("expected a placement")
            return
        }
        #expect(TrainingEngine.check(.place(cell: cell, digit: digit), against: drill) == .correct)
        let wrong: UInt8 = digit == 9 ? 1 : digit + 1
        #expect(TrainingEngine.check(.place(cell: cell, digit: wrong), against: drill) == .incorrect)
        // A filled cell is never a valid answer.
        let filled = try #require((0..<81).first { drill.grid.cells[$0] != 0 })
        #expect(TrainingEngine.check(.place(cell: filled, digit: drill.grid.cells[filled]), against: drill) == .incorrect)
    }

    @Test func eliminationVerdicts() throws {
        let drill = try #require(TrainingBank.drills(for: .nakedPair).first)
        let d = try #require(drill.deduction)
        guard case .eliminate(let elims) = d.kind, let first = elims.first, let digit = first.digits.first else {
            Issue.record("expected eliminations")
            return
        }
        #expect(TrainingEngine.check(.eliminate(cell: first.cell, digit: digit), against: drill) == .correct)
        // Striking the solution digit is flatly wrong.
        let truth = drill.solution.cells[first.cell]
        #expect(TrainingEngine.check(.eliminate(cell: first.cell, digit: truth), against: drill) == .incorrect)
    }

    @Test func offTopicTruthIsRecognised() throws {
        // A hidden-single position has no naked singles, but every other
        // correct digit is "true but off topic" — a placement the drilled
        // technique doesn't make.
        let drill = try #require(TrainingBank.drills(for: .hiddenSingle).first)
        let accepted = TrainingEngine.acceptedAnswers(for: drill)
        let other = try #require((0..<81).first { i in
            drill.grid.cells[i] == 0 && !accepted.placements.contains(CandidateRef(cell: i, digit: drill.solution.cells[i]))
        })
        #expect(TrainingEngine.check(.place(cell: other, digit: drill.solution.cells[other]), against: drill) == .trueButOffTopic)
    }

    @Test func acceptedAnswersCollectEveryInstance() throws {
        // A naked-single position typically holds several naked singles;
        // all of them must be accepted, and only genuine ones.
        let drill = try #require(TrainingBank.drills(for: .nakedSingle).first)
        let accepted = TrainingEngine.acceptedAnswers(for: drill)
        let expected = Set((0..<81).compactMap { i -> CandidateRef? in
            guard drill.grid.cells[i] == 0, drill.candidates[i].count == 1 else { return nil }
            return CandidateRef(cell: i, digit: drill.candidates[i].first!)
        })
        #expect(accepted.placements == expected)
        #expect(accepted.eliminations.isEmpty)
    }

    // MARK: - Serialization

    @Test func encodeDecodeRoundTrip() throws {
        let drill = try #require(TrainingBank.drills(for: .xyWing).first)
        let text = TrainingEngine.encode(drill)
        #expect(text.count == 81 * 3 + 243 + 3)
        let back = try #require(TrainingEngine.decode(text, technique: .xyWing))
        #expect(back == drill)
        #expect(TrainingEngine.decode("garbage", technique: .xyWing) == nil)
    }

    // MARK: - Mining

    @Test func minerFindsCommonTechniquesQuickly() {
        var rng = SeededRNG(seed: 2026)
        let drills = TrainingEngine.mine(technique: .nakedPair, using: &rng, maxPuzzles: 60, maxDrills: 2)
        #expect(!drills.isEmpty)
        for drill in drills {
            let d = drill.deduction
            #expect(d?.technique == .nakedPair)
            if let d { #expect(isSound(d, solution: drill.solution)) }
        }
    }

    @Test func minerRespectsTheDeadline() {
        var rng = SeededRNG(seed: 7)
        let deadline = ContinuousClock.now - .seconds(1) // already passed
        let drills = TrainingEngine.mine(technique: .hiddenSingle, using: &rng, maxPuzzles: 50, deadline: deadline)
        #expect(drills.isEmpty)
    }

    @Test func positionsFollowTheSolvePath() {
        // Norvig's hard 17-clue needs more than singles; its path must pass
        // through some elimination technique, each captured position being
        // one where that technique is the cheapest move.
        let givens = Grid(string: "4.....8.5.3..........7......2.....6.....8.4......1.......6.3.7.5..2.....1.4......")!
        let solution = Solver.firstSolution(givens)!
        let puzzle = Puzzle(givens: givens, solution: solution, difficulty: .master)
        let result = Solver.solveLogically(givens)
        let elimination = result.techniques.filter { $0 > .hiddenSingle }.min()!
        let hits = TrainingEngine.positions(of: elimination, in: puzzle)
        #expect(!hits.isEmpty)
        for h in hits {
            #expect(h.deduction?.technique == elimination)
        }
    }

    @Test func detectorDispatchCoversEveryTechnique() {
        for t in Technique.allCases {
            guard let drill = TrainingBank.drills(for: t).first else { continue }
            let d = Techniques.detect(t, drill.grid, drill.candidates, givens: drill.givens)
            #expect(d?.technique == t, "detect(\(t.displayName)) returned \(String(describing: d?.technique))")
        }
    }
}
