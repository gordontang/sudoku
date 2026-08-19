import Foundation
import SudokuKit

/// Where practice positions come from: the shipped bank (instant, curated,
/// covers every technique including the ones random puzzles almost never
/// produce) and an on-device miner that digs fresh puzzles and harvests
/// positions from their solve paths (variety, for the techniques common
/// enough to find within a couple of seconds).
enum DrillSupply {
    /// Mining budget per request. Release-build digs run at hundreds per
    /// second, so common techniques land well inside this; rare ones simply
    /// keep drawing from the bank.
    static let miningBudget: Duration = .seconds(2.5)

    /// A worked example for a lesson: the first bank drill of its primary
    /// technique — the bank is ordered tersest-explanation first, so that's
    /// the smallest, clearest instance of the pattern.
    static func example(for lesson: Lesson) -> Drill? {
        guard let primary = lesson.techniques.first else { return nil }
        return TrainingBank.drills(for: primary).first
    }

    /// Up to `count` bank drills spread across `techniques`, skipping
    /// recently-served positions while alternatives exist.
    static func bankDrills(for techniques: [Technique], avoiding recent: Set<String>, count: Int) -> [Drill] {
        var perTechnique: [[Drill]] = techniques.map { t in
            let all = TrainingBank.drills(for: t).shuffled()
            let fresh = all.filter { !recent.contains(DrillSession.key(for: $0)) }
            return fresh.isEmpty ? all : fresh
        }
        var picked: [Drill] = []
        // Round-robin so a multi-technique lesson samples each of them.
        var exhausted = false
        while picked.count < count && !exhausted {
            exhausted = true
            for i in perTechnique.indices where !perTechnique[i].isEmpty && picked.count < count {
                picked.append(perTechnique[i].removeFirst())
                exhausted = false
            }
        }
        return picked
    }

    /// Mine fresh positions off the main actor, one technique at a time in
    /// round-robin, until `count` are found or the budget runs out.
    static func mine(techniques: [Technique], count: Int) async -> [Drill] {
        guard !techniques.isEmpty else { return [] }
        return await Task.detached(priority: .utility) {
            var rng = SystemRandomNumberGenerator()
            let deadline = ContinuousClock.now + miningBudget
            var found: [Drill] = []
            var round = 0
            while found.count < count && ContinuousClock.now < deadline && !Task.isCancelled {
                let technique = techniques[round % techniques.count]
                round += 1
                found += TrainingEngine.mine(
                    technique: technique, using: &rng,
                    maxPuzzles: 40, maxDrills: 1, deadline: deadline
                )
            }
            return found
        }.value
    }
}
