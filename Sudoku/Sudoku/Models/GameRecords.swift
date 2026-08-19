import Foundation
import SudokuKit
import SwiftData

/// The single in-progress game. Starting a new game replaces it.
/// Grids and pencil marks are stored as compact Data blobs.
@Model
final class SavedGame {
    var givensData: Data
    var solutionData: Data
    var valuesData: Data
    var pencilData: Data
    var difficultyRaw: Int
    var elapsedSeconds: Double
    var mistakeCount: Int
    var hintsUsed: Int
    var score: Int = 0
    var startedAt: Date
    /// Encoded action log (see `MoveLogCoding`), for post-game review.
    var moveLogData: Data = Data()

    init(
        givensData: Data,
        solutionData: Data,
        valuesData: Data,
        pencilData: Data,
        difficultyRaw: Int,
        elapsedSeconds: Double,
        mistakeCount: Int,
        hintsUsed: Int,
        score: Int = 0,
        startedAt: Date,
        moveLogData: Data = Data()
    ) {
        self.givensData = givensData
        self.solutionData = solutionData
        self.valuesData = valuesData
        self.pencilData = pencilData
        self.difficultyRaw = difficultyRaw
        self.elapsedSeconds = elapsedSeconds
        self.mistakeCount = mistakeCount
        self.hintsUsed = hintsUsed
        self.score = score
        self.startedAt = startedAt
        self.moveLogData = moveLogData
    }

    var difficulty: Difficulty {
        Difficulty(rawValue: difficultyRaw) ?? .easy
    }
}

/// One row per finished (or abandoned) puzzle. This table *is* the stats —
/// aggregates are always computed from it, never stored.
@Model
final class CompletedGame {
    var difficultyRaw: Int
    var seconds: Double
    var mistakes: Int
    var hints: Int
    var score: Int = 0
    var completed: Bool
    var finishedAt: Date
    /// Encoded action log (see `MoveLogCoding`), for post-game review.
    var moveLogData: Data = Data()

    init(
        difficultyRaw: Int, seconds: Double, mistakes: Int, hints: Int,
        score: Int = 0, completed: Bool, finishedAt: Date, moveLogData: Data = Data()
    ) {
        self.difficultyRaw = difficultyRaw
        self.seconds = seconds
        self.mistakes = mistakes
        self.hints = hints
        self.score = score
        self.completed = completed
        self.finishedAt = finishedAt
        self.moveLogData = moveLogData
    }

    var difficulty: Difficulty {
        Difficulty(rawValue: difficultyRaw) ?? .easy
    }
}

// MARK: - Data encoding

extension Grid {
    var data: Data { Data(cells) }

    init?(data: Data) {
        guard data.count == 81 else { return nil }
        self.init(cells: [UInt8](data))
    }
}

enum PencilCoding {
    static func encode(_ pencil: [CandidateSet]) -> Data {
        var data = Data(capacity: 162)
        for set in pencil {
            withUnsafeBytes(of: set.rawValue.littleEndian) { data.append(contentsOf: $0) }
        }
        return data
    }

    static func decode(_ data: Data) -> [CandidateSet]? {
        guard data.count == 162 else { return nil }
        var result: [CandidateSet] = []
        result.reserveCapacity(81)
        let bytes = [UInt8](data)
        for i in 0..<81 {
            let raw = UInt16(bytes[i * 2]) | (UInt16(bytes[i * 2 + 1]) << 8)
            result.append(CandidateSet(rawValue: raw))
        }
        return result
    }
}
