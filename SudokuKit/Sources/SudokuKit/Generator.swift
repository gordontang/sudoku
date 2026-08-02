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
    /// rates the result, and retries until the rating matches. Attempts are
    /// capped; on exhaustion the closest-rated puzzle is returned so a request
    /// can never hang.
    public static func generate(difficulty: Difficulty, using rng: inout some RandomNumberGenerator) -> Puzzle {
        // Dig until the clue count reaches this floor (or no cell can be
        // removed without breaking uniqueness).
        let clueFloor: Int
        switch difficulty {
        case .easy: clueFloor = 42
        case .medium: clueFloor = 34
        case .hard: clueFloor = 30
        case .expert: clueFloor = 26
        case .master: clueFloor = 17
        }

        var best: (givens: Grid, solution: Grid, distance: Int)?
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

            let rating = Rater.rate(puzzle)
            if rating == difficulty {
                return Puzzle(givens: puzzle, solution: solution, difficulty: difficulty)
            }
            let distance = abs(rating.rawValue - difficulty.rawValue)
            if best == nil || distance < best!.distance {
                best = (puzzle, solution, distance)
            }
            if attempt >= nearBandThreshold, best!.distance <= 1 {
                break
            }
        }

        // Fallback: nearest achieved band, labelled with the requested level.
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
