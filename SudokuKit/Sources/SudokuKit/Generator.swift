public struct Puzzle: Sendable, Equatable, Codable {
    public let givens: Grid
    public let solution: Grid
    public let difficulty: Difficulty

    public init(givens: Grid, solution: Grid, difficulty: Difficulty) {
        self.givens = givens
        self.solution = solution
        self.difficulty = difficulty
    }
}

/// Deterministic seedable RNG (SplitMix64) for reproducible generation in tests.
public struct SeededRNG: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

public enum Generator {
    /// Generate a puzzle of the requested difficulty using the system RNG.
    public static func generate(difficulty: Difficulty) -> Puzzle {
        var rng = SystemRandomNumberGenerator()
        return generate(difficulty: difficulty, using: &rng)
    }

    /// Generate a puzzle of the requested difficulty.
    ///
    /// Fills a complete grid, digs symmetric holes while preserving uniqueness,
    /// rates the result, and retries until the puzzle qualifies. Attempts are
    /// capped; on exhaustion the closest-qualifying puzzle is returned so a
    /// request can never hang.
    ///
    /// Expert and master additionally dig asymmetrically past the symmetric
    /// local minimum and are accepted on clue count as well as rating —
    /// symmetric digging alone bottoms out near 25–30 clues, which is why
    /// those levels used to feel like hard.
    public static func generate(difficulty: Difficulty, using rng: inout some RandomNumberGenerator) -> Puzzle {
        // Dig until the clue count reaches this floor (or no cell can be
        // removed without breaking uniqueness).
        let clueFloor: Int
        switch difficulty {
        case .easy: clueFloor = 42
        case .medium: clueFloor = 34
        case .hard: clueFloor = 30
        case .expert: clueFloor = 24
        case .master: clueFloor = 20
        }
        let deepDig = difficulty >= .expert
        // Acceptance for deep-dug levels: few enough clues, and hard enough
        // that the technique solver needs at least this band. Master allows
        // one clue more than it used to: with the full ladder, master means
        // "requires a master-band technique", and demanding ≤23 clues on top
        // of that made qualifying puzzles rare enough to stall generation.
        let maxClues = difficulty == .master ? 24 : 25
        let minRating: Difficulty = difficulty == .master ? .master : .expert

        // score = (rating misses acceptance ? 1 : 0, clues over the cap) —
        // lexicographically smaller is closer to qualifying.
        var best: (givens: Grid, solution: Grid, score: (Int, Int))?
        let maxAttempts = 60
        // After this many misses, accept a rating one band away rather than
        // grinding on toward the attempt cap.
        let nearBandThreshold = 18

        for attempt in 0..<maxAttempts {
            let solution = fillGrid(using: &rng)
            var puzzle = solution
            var clues = 81

            // Dig 180°-rotationally-symmetric pairs in random order.
            var pairs = Array(0...40)
            pairs.shuffle(using: &rng)
            for i in pairs {
                if clues <= clueFloor { break }
                let j = 80 - i
                let targets = i == j ? [i] : [i, j]
                let saved = targets.map { puzzle.cells[$0] }
                guard saved.contains(where: { $0 != 0 }) else { continue }
                for t in targets { puzzle.cells[t] = 0 }
                if Solver.countSolutions(puzzle, limit: 2) == 1 {
                    clues -= saved.count { $0 != 0 }
                } else {
                    for (k, t) in targets.enumerated() { puzzle.cells[t] = saved[k] }
                }
            }

            if deepDig {
                // Single-cell pass, breaking symmetry to shed more clues. One
                // pass suffices: a removal that breaks uniqueness now can only
                // break it after further removals too.
                var clueCells = (0..<81).filter { puzzle.cells[$0] != 0 }
                clueCells.shuffle(using: &rng)
                for i in clueCells {
                    if clues <= clueFloor { break }
                    let saved = puzzle.cells[i]
                    puzzle.cells[i] = 0
                    if Solver.countSolutions(puzzle, limit: 2) == 1 {
                        clues -= 1
                    } else {
                        puzzle.cells[i] = saved
                    }
                }
            }

            let rating = Rater.rate(puzzle)
            if deepDig {
                if clues <= maxClues && rating >= minRating {
                    return Puzzle(givens: puzzle, solution: solution, difficulty: difficulty)
                }
                let score = (rating >= minRating ? 0 : 1, max(0, clues - maxClues))
                if best == nil || score < best!.score {
                    best = (puzzle, solution, score)
                }
            } else {
                if rating == difficulty {
                    return Puzzle(givens: puzzle, solution: solution, difficulty: difficulty)
                }
                let distance = abs(rating.rawValue - difficulty.rawValue)
                if best == nil || distance < best!.score.0 {
                    best = (puzzle, solution, (distance, 0))
                }
                if attempt >= nearBandThreshold, best!.score.0 <= 1 {
                    break
                }
            }
        }

        // Fallback: nearest qualifying puzzle, labelled with the requested level.
        let fallback = best!
        return Puzzle(givens: fallback.givens, solution: fallback.solution, difficulty: difficulty)
    }

    /// Fill an empty grid with a complete valid solution via randomized DFS.
    public static func fillGrid(using rng: inout some RandomNumberGenerator) -> Grid {
        var grid = Grid()
        _ = fill(&grid, index: 0, using: &rng)
        return grid
    }

    private static func fill(_ grid: inout Grid, index: Int, using rng: inout some RandomNumberGenerator) -> Bool {
        if index == 81 { return true }
        var digits: [UInt8] = Array(1...9)
        digits.shuffle(using: &rng)
        for d in digits where grid.isLegal(digit: d, at: index) {
            grid.cells[index] = d
            if fill(&grid, index: index + 1, using: &rng) { return true }
        }
        grid.cells[index] = 0
        return false
    }
}
