/// A practice position for one technique: a real solve state — the board as
/// it stood plus the honest notes the solver had at that moment — where the
/// cheapest available deduction is the drilled technique. Nothing easier
/// applies, so the player can't sidestep the lesson, and the coach machinery
/// (name → location → pattern → resolution) works on it unchanged.
public struct Drill: Sendable, Hashable, Codable, Identifiable {
    public let technique: Technique
    /// The puzzle's original clues (uniqueness techniques need them).
    public let givens: Grid
    public let solution: Grid
    /// Values on the board at the drill position.
    public let grid: Grid
    /// Candidates at the drill position, prior eliminations applied.
    public let candidates: [CandidateSet]

    public init(technique: Technique, givens: Grid, solution: Grid, grid: Grid, candidates: [CandidateSet]) {
        self.technique = technique
        self.givens = givens
        self.solution = solution
        self.grid = grid
        self.candidates = candidates
    }

    public var id: Int { hashValue }

    /// The deduction the drill is about — the cheapest one in the position.
    public var deduction: Deduction? {
        Techniques.findDeduction(grid: grid, candidates: candidates, givens: givens)
    }
}

/// What the player proposes as the drill's move.
public enum DrillAnswer: Sendable, Hashable {
    case place(cell: Int, digit: UInt8)
    case eliminate(cell: Int, digit: UInt8)
}

/// How a proposed move measures up against the drilled technique.
public enum DrillVerdict: Sendable, Equatable {
    /// The move is one the drilled technique yields in this position.
    case correct
    /// A true move (right digit / genuinely false candidate) that the drilled
    /// technique doesn't produce here — the player used something else, or
    /// guessed. Doesn't complete the drill.
    case trueButOffTopic
    /// Wrong digit, or a candidate that is actually the solution.
    case incorrect
}

/// Every move the drilled technique yields in a position: for placement
/// techniques, all such singles; for elimination techniques, the union of
/// eliminations from applying the technique repeatedly (a second X-Wing on
/// another digit counts).
public struct DrillAnswerSet: Sendable, Equatable {
    public var placements: Set<CandidateRef> = []
    public var eliminations: Set<CandidateRef> = []

    public init(placements: Set<CandidateRef> = [], eliminations: Set<CandidateRef> = []) {
        self.placements = placements
        self.eliminations = eliminations
    }

    public var isEmpty: Bool { placements.isEmpty && eliminations.isEmpty }
}

public enum TrainingEngine {
    // MARK: - Mining

    /// Generate puzzles at the technique's band and harvest positions along
    /// their logical solve paths where the technique is the cheapest
    /// deduction. Up to `maxDrills` positions are returned, at most one per
    /// puzzle (chosen at random along that puzzle's path, so drills aren't
    /// all opening moves). Stops early once `deadline` passes.
    ///
    /// Yield varies wildly by technique: singles appear in every puzzle,
    /// finned jellyfish and Sue de Coq in a small fraction of master ones.
    /// Callers that need a guaranteed drill should fall back to the shipped
    /// bank (`TrainingBank`).
    public static func mine(
        technique: Technique,
        using rng: inout some RandomNumberGenerator,
        maxPuzzles: Int = 12,
        maxDrills: Int = 1,
        deadline: ContinuousClock.Instant? = nil
    ) -> [Drill] {
        var drills: [Drill] = []
        let (floor, deep) = digProfile(for: technique.band)
        for _ in 0..<maxPuzzles {
            if drills.count >= maxDrills { break }
            if let deadline, ContinuousClock.now > deadline { break }
            // Cheap unrated digs: any puzzle whose solve path passes through
            // the technique will do, so there's no need to pay for the
            // generator's band-qualification retries.
            let solution = Generator.fillGrid(using: &rng)
            let givens = Generator.dig(from: solution, clueFloor: floor, deepDig: deep, using: &rng)
            let puzzle = Puzzle(givens: givens, solution: solution, difficulty: technique.band)
            let hits = positions(of: technique, in: puzzle)
            if let pick = hits.randomElement(using: &rng) {
                drills.append(pick)
            }
        }
        return drills
    }

    /// How deep to dig when mining a band: shallow symmetric digs stay in
    /// singles territory; deep asymmetric digs reach the advanced ladder.
    static func digProfile(for band: Difficulty) -> (clueFloor: Int, deepDig: Bool) {
        switch band {
        case .easy: (40, false)
        case .medium: (32, false)
        case .hard: (27, false)
        case .expert: (24, true)
        case .master: (22, true)
        }
    }

    /// Every position along a puzzle's logical solve path where `technique`
    /// is the cheapest deduction.
    public static func positions(of technique: Technique, in puzzle: Puzzle) -> [Drill] {
        var grid = puzzle.givens
        var cands = grid.candidates()
        var hits: [Drill] = []
        while !grid.isFull {
            guard let d = Techniques.findDeduction(grid: grid, candidates: cands, givens: puzzle.givens) else { break }
            if d.technique == technique {
                hits.append(Drill(
                    technique: technique, givens: puzzle.givens, solution: puzzle.solution,
                    grid: grid, candidates: cands
                ))
            }
            Solver.apply(d, to: &grid, candidates: &cands)
        }
        return hits
    }

    // MARK: - Checking answers

    public static func check(_ answer: DrillAnswer, against drill: Drill, accepted: DrillAnswerSet? = nil) -> DrillVerdict {
        let accepted = accepted ?? acceptedAnswers(for: drill)
        switch answer {
        case .place(let cell, let digit):
            let ref = CandidateRef(cell: cell, digit: digit)
            if accepted.placements.contains(ref) { return .correct }
            return drill.solution.cells[cell] == digit && drill.grid.cells[cell] == 0
                ? .trueButOffTopic : .incorrect
        case .eliminate(let cell, let digit):
            let ref = CandidateRef(cell: cell, digit: digit)
            if accepted.eliminations.contains(ref) { return .correct }
            let isCandidate = drill.grid.cells[cell] == 0 && drill.candidates[cell].contains(digit: digit)
            return isCandidate && drill.solution.cells[cell] != digit
                ? .trueButOffTopic : .incorrect
        }
    }

    /// All moves the drilled technique yields in the drill's position.
    public static func acceptedAnswers(for drill: Drill) -> DrillAnswerSet {
        var set = DrillAnswerSet()
        let grid = drill.grid
        var cands = drill.candidates
        switch drill.technique {
        case .fullHouse:
            for unit in Grid.units {
                let empty = unit.filter { grid.cells[$0] == 0 }
                if empty.count == 1, let d = cands[empty[0]].first {
                    set.placements.insert(CandidateRef(cell: empty[0], digit: d))
                }
            }
        case .nakedSingle:
            for i in 0..<81 where grid.cells[i] == 0 && cands[i].count == 1 {
                set.placements.insert(CandidateRef(cell: i, digit: cands[i].first!))
            }
        case .hiddenSingle:
            for unit in Grid.units {
                for d: UInt8 in 1...9 where !unit.contains(where: { grid.cells[$0] == d }) {
                    let spots = unit.filter { grid.cells[$0] == 0 && cands[$0].contains(digit: d) }
                    if spots.count == 1 {
                        set.placements.insert(CandidateRef(cell: spots[0], digit: d))
                    }
                }
            }
        default:
            // Apply the technique's own detector repeatedly, collecting what
            // it removes (or places), until it runs dry or drifts to a
            // sibling technique.
            var g = grid
            for _ in 0..<24 {
                guard let d = Techniques.detect(drill.technique, g, cands, givens: drill.givens),
                      d.technique == drill.technique
                else { break }
                switch d.kind {
                case .place(let cell, let digit):
                    set.placements.insert(CandidateRef(cell: cell, digit: digit))
                case .eliminate(let elims):
                    for (cell, digits) in elims {
                        for digit in digits.digits where cands[cell].contains(digit: digit) {
                            set.eliminations.insert(CandidateRef(cell: cell, digit: digit))
                        }
                    }
                }
                Solver.apply(d, to: &g, candidates: &cands)
            }
        }
        return set
    }

    // MARK: - Serialization

    /// Compact text form: `givens|solution|grid|candidates`, candidates as
    /// 81 three-digit hex bitmasks. Used by the shipped drill bank.
    public static func encode(_ drill: Drill) -> String {
        let givens = drill.givens.cells.map(String.init).joined()
        let solution = drill.solution.cells.map(String.init).joined()
        let grid = drill.grid.cells.map(String.init).joined()
        let cands = drill.candidates.map { hex3($0.rawValue) }.joined()
        return "\(givens)|\(solution)|\(grid)|\(cands)"
    }

    private static func hex3(_ value: UInt16) -> String {
        let digits = Array("0123456789abcdef")
        return String([digits[Int(value >> 8) & 0xF], digits[Int(value >> 4) & 0xF], digits[Int(value) & 0xF]])
    }

    public static func decode(_ text: String, technique: Technique) -> Drill? {
        let parts = text.split(separator: "|")
        guard parts.count == 4,
              let givens = Grid(string: String(parts[0])),
              let solution = Grid(string: String(parts[1])),
              let grid = Grid(string: String(parts[2])),
              parts[3].count == 243
        else { return nil }
        var cands: [CandidateSet] = []
        cands.reserveCapacity(81)
        let hex = Array(parts[3])
        for i in 0..<81 {
            guard let raw = UInt16(String(hex[i * 3..<i * 3 + 3]), radix: 16) else { return nil }
            cands.append(CandidateSet(rawValue: raw))
        }
        return Drill(technique: technique, givens: givens, solution: solution, grid: grid, candidates: cands)
    }
}

extension Techniques {
    /// Run one technique's own detector. Family detectors (subsets, fish,
    /// turbot patterns, unique rectangles) may report a sibling technique;
    /// callers compare `technique` when they care.
    static func detect(_ technique: Technique, _ grid: Grid, _ cands: [CandidateSet], givens: Grid?) -> Deduction? {
        switch technique {
        case .fullHouse: fullHouse(grid, cands)
        case .nakedSingle: nakedSingle(grid, cands)
        case .hiddenSingle: hiddenSingle(grid, cands)
        case .lockedCandidates: lockedCandidates(grid, cands)
        case .lockedPair, .nakedPair: nakedSubset(grid, cands, size: 2)
        case .hiddenPair: hiddenSubset(grid, cands, size: 2)
        case .lockedTriple, .nakedTriple: nakedSubset(grid, cands, size: 3)
        case .hiddenTriple: hiddenSubset(grid, cands, size: 3)
        case .nakedQuad: nakedSubset(grid, cands, size: 4)
        case .hiddenQuad: hiddenSubset(grid, cands, size: 4)
        case .xWing: basicFish(grid, cands, size: 2)
        case .skyscraper, .twoStringKite, .turbotFish: turbotFamily(grid, cands)
        case .emptyRectangle: emptyRectangle(grid, cands)
        case .xyWing: xyWing(grid, cands)
        case .swordfish: basicFish(grid, cands, size: 3)
        case .jellyfish: basicFish(grid, cands, size: 4)
        case .finnedXWing: finnedFish(grid, cands, size: 2)
        case .finnedSwordfish: finnedFish(grid, cands, size: 3)
        case .finnedJellyfish: finnedFish(grid, cands, size: 4)
        case .xyzWing: xyzWing(grid, cands)
        case .wWing: wWing(grid, cands)
        case .remotePair: remotePair(grid, cands)
        case .bugPlusOne: bugPlusOne(grid, cands)
        case .uniqueRectangle: uniqueRectangle(grid, cands)
        case .hiddenRectangle: hiddenRectangle(grid, cands)
        case .avoidableRectangle: avoidableRectangle(grid, cands, givens: givens)
        case .simpleColors: simpleColors(grid, cands)
        case .multiColors: multiColors(grid, cands)
        case .xChain: xChain(grid, cands)
        case .xyChain: xyChain(grid, cands)
        case .sueDeCoq: sueDeCoq(grid, cands)
        case .alsXZ: alsXZ(grid, cands)
        case .aic: aic(grid, cands)
        }
    }
}
