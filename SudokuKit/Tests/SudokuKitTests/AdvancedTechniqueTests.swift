import Testing
@testable import SudokuKit

/// Wave 2–6 detector tests. Synthetic fixtures pin exact eliminations for
/// the geometrically constructable patterns; captured fixtures (real solve
/// states with known solutions) pin the search-based detectors, asserting
/// soundness against the embedded solution.
@Suite struct AdvancedTechniqueTests {
    private func cands(_ overrides: [Int: CandidateSet]) -> [CandidateSet] {
        var result = Array(repeating: CandidateSet.all, count: 81)
        for (cell, set) in overrides { result[cell] = set }
        return result
    }

    private func set(_ digits: [UInt8]) -> CandidateSet {
        CandidateSet(digits: digits)
    }

    private func elimMap(_ d: Deduction?) -> [Int: CandidateSet]? {
        guard let d, case .eliminate(let elims) = d.kind else { return nil }
        var map: [Int: CandidateSet] = [:]
        for (cell, digits) in elims { map[cell, default: CandidateSet()].formUnion(digits) }
        return map
    }

    // MARK: - Fish

    @Test func swordfish() {
        // 3 confined to columns 1, 5, 9 in rows 1, 5, 9.
        var ov: [Int: CandidateSet] = [:]
        for r in [0, 4, 8] {
            for c in 0..<9 where ![0, 4, 8].contains(c) {
                ov[r * 9 + c] = CandidateSet.all.subtracting(set([3]))
            }
        }
        let d = Techniques.basicFish(Grid(), cands(ov), size: 3)
        #expect(d?.technique == .swordfish)
        let elims = elimMap(d)!
        #expect(elims.count == 18)
        #expect(elims.keys.allSatisfy { [0, 4, 8].contains($0 % 9) && ![0, 4, 8].contains($0 / 9) })
        #expect(elims.values.allSatisfy { $0 == set([3]) })
    }

    @Test func jellyfish() {
        var ov: [Int: CandidateSet] = [:]
        for r in [0, 2, 5, 7] {
            for c in 0..<9 where ![0, 3, 6, 8].contains(c) {
                ov[r * 9 + c] = CandidateSet.all.subtracting(set([6]))
            }
        }
        let d = Techniques.basicFish(Grid(), cands(ov), size: 4)
        #expect(d?.technique == .jellyfish)
        let elims = elimMap(d)!
        #expect(elims.count == 20)
        #expect(elims.keys.allSatisfy { [0, 3, 6, 8].contains($0 % 9) && ![0, 2, 5, 7].contains($0 / 9) })
    }

    @Test func finnedXWing() {
        // 3 in row 2 cols {3,7}; row 8 cols {3,7,8} — the extra candidate
        // (fin) sits in box 9, restricting eliminations to that box.
        var ov: [Int: CandidateSet] = [:]
        for c in 0..<9 {
            if ![2, 6].contains(c) { ov[9 + c] = CandidateSet.all.subtracting(set([3])) }
            if ![2, 6, 7].contains(c) { ov[63 + c] = CandidateSet.all.subtracting(set([3])) }
        }
        let d = Techniques.finnedFish(Grid(), cands(ov), size: 2)
        #expect(d?.technique == .finnedXWing)
        #expect(elimMap(d) == [60: set([3]), 78: set([3])])
    }

    // MARK: - Single-digit patterns

    @Test func skyscraper() {
        // 5 in row 2 cols {3,7} and row 8 cols {3,9}, linked through column 3.
        var ov: [Int: CandidateSet] = [:]
        for c in 0..<9 {
            if ![2, 6].contains(c) { ov[9 + c] = CandidateSet.all.subtracting(set([5])) }
            if ![2, 8].contains(c) { ov[63 + c] = CandidateSet.all.subtracting(set([5])) }
        }
        let d = Techniques.turbotFamily(Grid(), cands(ov))
        #expect(d?.technique == .skyscraper)
        #expect(elimMap(d) == [8: set([5]), 26: set([5]), 60: set([5]), 78: set([5])])
    }

    @Test func twoStringKite() {
        // 4 in row 1 cols {3,9} and column 1 rows {3,9}; the near ends share
        // box 1, so r9c9 can't be a 4.
        var ov: [Int: CandidateSet] = [:]
        for c in 0..<9 where ![2, 8].contains(c) {
            ov[c] = CandidateSet.all.subtracting(set([4]))
        }
        for r in 0..<9 where ![2, 8].contains(r) {
            ov[r * 9] = (ov[r * 9] ?? CandidateSet.all).subtracting(set([4]))
        }
        let d = Techniques.turbotFamily(Grid(), cands(ov))
        #expect(d?.technique == .twoStringKite)
        #expect(elimMap(d) == [80: set([4])])
    }

    @Test func emptyRectangle() {
        // 7 in box 5 confined to the row-5/column-5 cross; strong link in
        // row 2 cols {5,9} closes the rectangle at r5c9.
        var ov: [Int: CandidateSet] = [:]
        for i in [30, 32, 48, 50] { ov[i] = CandidateSet.all.subtracting(set([7])) }
        for c in 0..<9 where ![4, 8].contains(c) {
            ov[9 + c] = (ov[9 + c] ?? CandidateSet.all).subtracting(set([7]))
        }
        let d = Techniques.emptyRectangle(Grid(), cands(ov))
        #expect(d?.technique == .emptyRectangle)
        #expect(elimMap(d) == [44: set([7])])
    }

    // MARK: - Wings and bivalue chains

    @Test func xyWing() {
        let d = Techniques.xyWing(Grid(), cands([40: set([2, 7]), 37: set([2, 5]), 13: set([5, 7])]))
        #expect(d?.technique == .xyWing)
        #expect(elimMap(d) == [10: set([5])])
    }

    @Test func xyzWing() {
        let d = Techniques.xyzWing(Grid(), cands([40: set([2, 5, 7]), 30: set([2, 5]), 44: set([5, 7])]))
        #expect(d?.technique == .xyzWing)
        #expect(elimMap(d) == [39: set([5]), 41: set([5])])
    }

    @Test func wWing() {
        // {6,9} at r2c2 and r6c6, bridged by a strong link on 9 in row 4.
        var ov: [Int: CandidateSet] = [10: set([6, 9]), 50: set([6, 9])]
        for c in 0..<9 where ![1, 5].contains(c) {
            ov[27 + c] = (ov[27 + c] ?? CandidateSet.all).subtracting(set([9]))
        }
        let d = Techniques.wWing(Grid(), cands(ov))
        #expect(d?.technique == .wWing)
        #expect(elimMap(d) == [14: set([6]), 46: set([6])])
    }

    @Test func remotePair() {
        // {3,8} chain r1c1 → r1c9 → r5c9 → r5c5: the ends carry opposite
        // digits, so both die where the ends are jointly seen.
        let d = Techniques.remotePair(Grid(), cands([
            0: set([3, 8]), 8: set([3, 8]), 44: set([3, 8]), 40: set([3, 8]),
        ]))
        #expect(d?.technique == .remotePair)
        #expect(elimMap(d) == [4: set([3, 8]), 36: set([3, 8])])
    }

    // MARK: - Uniqueness

    @Test func uniqueRectangleType1() {
        let d = Techniques.uniqueRectangle(Grid(), cands([
            0: set([4, 7]), 3: set([4, 7]), 9: set([4, 7]), 12: set([4, 7, 9]),
        ]))
        #expect(d?.technique == .uniqueRectangle)
        #expect(elimMap(d) == [12: set([4, 7])])
    }

    @Test func uniqueRectangleType2() {
        let d = Techniques.uniqueRectangle(Grid(), cands([
            0: set([4, 7]), 3: set([4, 7]), 9: set([4, 7, 9]), 12: set([4, 7, 9]),
        ]))
        #expect(d?.technique == .uniqueRectangle)
        let elims = elimMap(d)!
        #expect(elims.keys.allSatisfy { $0 / 9 == 1 && $0 != 9 && $0 != 12 })
        #expect(elims.values.allSatisfy { $0 == set([9]) })
        #expect(elims.count == 7)
    }

    @Test func hiddenRectangle() {
        // Floor r1c1 bare pair; 4 confined to the rectangle in r2's row and
        // c4's column → the opposite corner can't be 7.
        var ov: [Int: CandidateSet] = [
            0: set([4, 7]), 3: set([4, 7, 8]), 9: set([4, 7, 8]), 12: set([4, 7, 8]),
        ]
        for i in [10, 11, 13, 14, 15, 16, 17] { ov[i] = CandidateSet.all.subtracting(set([4])) }
        for i in [21, 30, 39, 48, 57, 66, 75] { ov[i] = CandidateSet.all.subtracting(set([4])) }
        let d = Techniques.hiddenRectangle(Grid(), cands(ov))
        #expect(d?.technique == .hiddenRectangle)
        #expect(elimMap(d) == [12: set([7])])
    }

    @Test func avoidableRectangle() {
        // r1c1=1, r1c4=2, r2c1=2 all placed by the player: r2c4=1 would make
        // the rectangle swappable.
        var grid = Grid()
        grid.cells[0] = 1
        grid.cells[3] = 2
        grid.cells[9] = 2
        let d = Techniques.avoidableRectangle(grid, grid.candidates(), givens: Grid())
        #expect(d?.technique == .avoidableRectangle)
        #expect(elimMap(d) == [12: set([1])])
    }

    // MARK: - Captured real-position fixtures

    /// Real solve states (from the Python reference harness) where each
    /// search-based detector fires. The embedded solution lets every result
    /// be checked for soundness without pinning exact search order.
    @Test(arguments: [
        Technique.bugPlusOne, .simpleColors, .multiColors, .xChain, .xyChain,
        .sueDeCoq, .alsXZ, .aic,
    ])
    func capturedFixture(technique: Technique) {
        guard let fixture = Self.capturedFixtures.first(where: { $0.technique == technique }) else {
            Issue.record("no fixture for \(technique)")
            return
        }
        let grid = Grid(string: fixture.grid)!
        let solution = Grid(string: fixture.solution)!
        let cands = fixture.rawCands.map(CandidateSet.init(rawValue:))
        let d: Deduction?
        switch technique {
        case .bugPlusOne: d = Techniques.bugPlusOne(grid, cands)
        case .simpleColors: d = Techniques.simpleColors(grid, cands)
        case .multiColors: d = Techniques.multiColors(grid, cands)
        case .xChain: d = Techniques.xChain(grid, cands)
        case .xyChain: d = Techniques.xyChain(grid, cands)
        case .sueDeCoq: d = Techniques.sueDeCoq(grid, cands)
        case .alsXZ: d = Techniques.alsXZ(grid, cands)
        case .aic: d = Techniques.aic(grid, cands)
        default: d = nil
        }
        guard let d else {
            Issue.record("\(technique) found nothing on its fixture")
            return
        }
        #expect(d.technique == technique)
        #expect(!d.patternCells.isEmpty)
        switch d.kind {
        case .place(let cell, let digit):
            #expect(solution.cells[cell] == digit, "\(technique) placed a wrong digit")
        case .eliminate(let elims):
            #expect(!elims.isEmpty)
            for (cell, digits) in elims {
                #expect(!digits.contains(digit: solution.cells[cell]),
                        "\(technique) eliminated the solution digit at cell \(cell)")
                #expect(digits.subtracting(cands[cell]).isEmpty,
                        "\(technique) eliminated an absent candidate at cell \(cell)")
            }
        }
    }

    @Test func bugPlusOnePlacesTheForcedDigit() {
        let fixture = Self.capturedFixtures.first { $0.technique == .bugPlusOne }!
        let grid = Grid(string: fixture.grid)!
        let cands = fixture.rawCands.map(CandidateSet.init(rawValue:))
        let d = Techniques.bugPlusOne(grid, cands)
        guard case .place(let cell, let digit)? = d?.kind else {
            Issue.record("expected a placement")
            return
        }
        #expect(cell == 7)
        #expect(digit == 2)
    }

    // MARK: - Ladder integration

    @Test func fullLadderStaysSoundOnGeneratedPuzzles() {
        for difficulty in Difficulty.allCases {
            var rng = SeededRNG(seed: UInt64(difficulty.rawValue) &+ 71)
            let puzzle = Generator.generate(difficulty: difficulty, using: &rng)
            var grid = puzzle.givens
            var cands = grid.candidates()
            var steps = 0
            while let d = Techniques.findDeduction(grid: grid, candidates: cands, givens: puzzle.givens) {
                switch d.kind {
                case .place(let cell, let digit):
                    #expect(puzzle.solution.cells[cell] == digit, "\(d.technique) placed a wrong digit")
                case .eliminate(let elims):
                    #expect(!elims.isEmpty)
                    for (cell, digits) in elims {
                        #expect(!digits.contains(digit: puzzle.solution.cells[cell]),
                                "\(d.technique) eliminated the solution digit from cell \(cell)")
                    }
                }
                Solver.apply(d, to: &grid, candidates: &cands)
                steps += 1
                #expect(steps < 1500)
                if grid.isFull { break }
            }
        }
    }

    @Test func bandsPartitionTheLadder() {
        #expect(Technique.hiddenSingle.band == .easy)
        #expect(Technique.lockedCandidates.band == .medium)
        #expect(Technique.hiddenPair.band == .hard)
        #expect(Technique.xWing.band == .expert)
        #expect(Technique.xyWing.band == .expert)
        #expect(Technique.swordfish.band == .master)
        #expect(Technique.aic.band == .master)
        // Every technique maps into exactly one band, in ladder order.
        var last = Difficulty.easy
        for t in Technique.allCases {
            #expect(t.band >= last)
            last = t.band
        }
    }
}

extension AdvancedTechniqueTests {
    static let capturedFixtures: [(technique: Technique, grid: String, solution: String, rawCands: [UInt16])] = [
    // from seventeen
    (.aic, "000000010400000000020000000000050407008000300001090000300470200050100000000806000",
     "693784512487512936125963874932651487568247391741398625319475268856129743274836159",
     [992, 968, 744, 748, 348, 956, 992, 0, 892, 0, 970, 744, 748, 334, 942, 992, 1004, 876, 994, 0, 744, 744, 346, 954, 992, 1016, 888, 580, 584, 588, 76, 0, 270, 0, 836, 0, 740, 720, 0, 196, 86, 150, 0, 612, 614, 228, 216, 0, 204, 0, 412, 352, 356, 356, 0, 834, 576, 0, 0, 544, 0, 864, 866, 964, 0, 724, 0, 12, 524, 960, 984, 856, 646, 658, 660, 0, 12, 0, 674, 696, 570]),
    // from seventeen
    (.alsXZ, "000000010400000000020000000000050407008000300001090000300400200050100000000806000",
     "693784512487512936125963874932651487568247391741398625319475268856129743274836159",
     [992, 968, 744, 748, 476, 956, 992, 0, 892, 0, 970, 744, 748, 462, 942, 992, 1004, 876, 994, 0, 744, 744, 474, 954, 992, 1016, 888, 580, 584, 588, 76, 0, 270, 0, 836, 0, 740, 720, 0, 196, 214, 150, 0, 612, 614, 228, 216, 0, 204, 0, 412, 352, 356, 356, 0, 962, 704, 0, 128, 672, 0, 992, 866, 964, 0, 724, 0, 140, 652, 960, 984, 856, 646, 658, 660, 0, 140, 0, 674, 696, 570]),
    // from rand8
    (.bugPlusOne, "068197400743265918910483607001876594657349281894521376086702149409618705170904860",
     "568197423743265918912483657231876594657349281894521376386752149429618735175934862",
     [36, 0, 0, 0, 0, 0, 0, 44, 12, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 36, 0, 0, 0, 0, 36, 0, 12, 12, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 40, 0, 0, 0, 40, 0, 0, 0, 0, 0, 12, 0, 0, 0, 0, 0, 12, 0, 0, 0, 36, 0, 40, 0, 0, 0, 12]),
    // from rand1
    (.multiColors, "002010700864257931700080200600008573048706129900501486109075642450162090006040010",
     "392614758864257931715983264621498573548736129937521486189375642453162897276849315",
     [40, 520, 0, 600, 0, 536, 0, 96, 304, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 522, 42, 600, 0, 536, 0, 96, 48, 0, 6, 2, 528, 516, 0, 0, 0, 0, 40, 0, 0, 0, 8, 0, 0, 0, 0, 0, 140, 136, 0, 12, 0, 0, 0, 0, 0, 264, 0, 264, 0, 0, 0, 0, 0, 0, 0, 136, 0, 0, 0, 264, 0, 384, 12, 396, 0, 776, 0, 520, 264, 0, 416]),
    // from seventeen
    (.simpleColors, "000000010400000000020000000000050407008000300001090000300400200050100000000806000",
     "693784512487512936125963874932651487568247391741398625319475268856129743274836159",
     [992, 968, 744, 748, 476, 956, 992, 0, 892, 0, 970, 744, 748, 462, 942, 992, 1004, 876, 994, 0, 744, 744, 474, 954, 992, 1016, 888, 580, 584, 588, 76, 0, 270, 0, 836, 0, 740, 720, 0, 196, 214, 150, 0, 612, 614, 228, 216, 0, 204, 0, 412, 352, 356, 356, 0, 962, 704, 0, 128, 672, 0, 992, 866, 964, 0, 724, 0, 140, 652, 960, 984, 856, 646, 658, 660, 0, 140, 0, 674, 696, 570]),
    // from seventeen
    (.sueDeCoq, "690080510480010000120060800932651487568040391741398000319475268856129700274836100",
     "693784512487512936125963874932651487568247391741398625319475268856129743274836159",
     [0, 0, 136, 132, 0, 156, 0, 0, 28, 0, 0, 168, 676, 0, 140, 576, 140, 588, 0, 0, 168, 672, 0, 152, 0, 152, 536, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 132, 0, 132, 0, 0, 0, 0, 0, 0, 0, 0, 0, 64, 36, 100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 24, 24, 0, 0, 0, 0, 0, 0, 0, 32, 544]),
    // from norvig_hard
    (.xChain, "417369825030100000000700000020430060000080400040010000000603070503201000104805000",
     "417369825632158947958724316825437169791586432346912758289643571573291684164875293",
     [0, 0, 0, 0, 0, 0, 0, 0, 0, 836, 0, 868, 0, 52, 272, 704, 528, 720, 836, 800, 868, 0, 52, 272, 586, 538, 602, 896, 0, 802, 0, 0, 128, 674, 0, 898, 712, 544, 610, 544, 0, 196, 0, 554, 654, 968, 0, 864, 544, 0, 196, 684, 808, 908, 772, 768, 772, 0, 528, 0, 546, 0, 786, 0, 960, 0, 0, 656, 0, 576, 784, 848, 0, 704, 0, 0, 640, 0, 588, 520, 588]),
    // from seventeen
    (.xyChain, "000000010400010000120000000000051487568000391741398000310470208850100000000806100",
     "693784512487512936125963874932651487568247391741398625319475268856129743274836159",
     [576, 904, 744, 740, 348, 700, 992, 0, 636, 0, 904, 744, 740, 0, 684, 992, 236, 620, 0, 0, 744, 736, 344, 696, 992, 248, 632, 516, 520, 524, 68, 0, 0, 0, 0, 0, 0, 0, 0, 132, 20, 148, 0, 0, 0, 0, 0, 0, 0, 0, 0, 96, 100, 100, 0, 0, 576, 0, 0, 544, 0, 96, 0, 0, 0, 724, 0, 12, 524, 704, 216, 600, 516, 640, 660, 0, 12, 0, 0, 184, 568]),
    ]
}
