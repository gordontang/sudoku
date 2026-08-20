import Foundation
import Testing
@testable import SudokuKit

/// Developer tools for the shipped drill bank, disguised as tests so they
/// run inside the package with the real engine. Both are no-ops unless
/// their environment variables are set, so CI never triggers them.
///
/// Mine positions (multi-threaded; ~100 master digs/s per core in release):
///
///     MINE_OUT=/tmp/master.txt MINE_PROFILE=4 MINE_COUNT=5000 MINE_WORKERS=10 \
///       swift test -c release -Xswiftc -enable-testing --filter DrillBankTools/mine
///
/// Then assemble `Sources/SudokuKit/TrainingBank.swift` from one or more
/// mined files (colon-separated), keeping BANK_PER per technique:
///
///     BANK_IN=/tmp/master.txt:/tmp/expert.txt BANK_OUT=Sources/SudokuKit/TrainingBank.swift \
///       swift test -c release -Xswiftc -enable-testing --filter DrillBankTools/buildBank
@Suite struct DrillBankTools {
    private final class Results: @unchecked Sendable {
        var lines: [[String]]
        init(_ n: Int) { lines = Array(repeating: [], count: n) }
    }

    /// MINE_OUT (path), MINE_SEED, MINE_COUNT (puzzles per worker),
    /// MINE_PROFILE (band 0–4, picks the dig depth), MINE_WORKERS,
    /// MINE_PER (positions kept per technique per worker).
    @Test func mine() throws {
        let env = ProcessInfo.processInfo.environment
        guard let out = env["MINE_OUT"] else { return }
        let seed = UInt64(env["MINE_SEED"] ?? "1") ?? 1
        let count = Int(env["MINE_COUNT"] ?? "1000") ?? 1000
        let band = Difficulty(rawValue: Int(env["MINE_PROFILE"] ?? "4") ?? 4) ?? .master
        let perTechnique = Int(env["MINE_PER"] ?? "8") ?? 8
        let workers = Int(env["MINE_WORKERS"] ?? "8") ?? 8
        let results = Results(workers)
        DispatchQueue.concurrentPerform(iterations: workers) { w in
            var rng = SeededRNG(seed: seed &* 7919 &+ UInt64(w))
            let (floor, deep) = TrainingEngine.digProfile(for: band)
            var kept: [Technique: Int] = [:]
            var lines: [String] = []
            for _ in 0..<count {
                let solution = Generator.fillGrid(using: &rng)
                let givens = Generator.dig(from: solution, clueFloor: floor, deepDig: deep, using: &rng)
                let puzzle = Puzzle(givens: givens, solution: solution, difficulty: band)
                var perPuzzle: [Technique: [Drill]] = [:]
                var grid = givens
                var cands = grid.candidates()
                while !grid.isFull {
                    guard let d = Techniques.findDeduction(grid: grid, candidates: cands, givens: givens) else { break }
                    if (kept[d.technique] ?? 0) < perTechnique {
                        perPuzzle[d.technique, default: []].append(Drill(
                            technique: d.technique, givens: puzzle.givens, solution: puzzle.solution,
                            grid: grid, candidates: cands
                        ))
                    }
                    Solver.apply(d, to: &grid, candidates: &cands)
                }
                // One position per puzzle per technique, random along the path.
                for (t, drills) in perPuzzle {
                    if let pick = drills.randomElement(using: &rng) {
                        kept[t, default: 0] += 1
                        lines.append("\(t.rawValue)|\(TrainingEngine.encode(pick))")
                    }
                }
            }
            results.lines[w] = lines
        }
        let all = results.lines.flatMap { $0 }
        try all.joined(separator: "\n").write(toFile: out, atomically: true, encoding: .utf8)
        var tally: [Technique: Int] = [:]
        for line in all {
            if let raw = Int(line.prefix(while: { $0 != "|" })), let t = Technique(rawValue: raw) {
                tally[t, default: 0] += 1
            }
        }
        for t in Technique.allCases { print("  \(t.displayName): \(tally[t] ?? 0)") }
        print("mined \(all.count) drills into \(out)")
    }

    /// BANK_IN (colon-separated mined files), BANK_OUT (Swift source path),
    /// BANK_PER (drills kept per technique).
    @Test func buildBank() throws {
        let env = ProcessInfo.processInfo.environment
        guard let inputs = env["BANK_IN"], let out = env["BANK_OUT"] else { return }
        let per = Int(env["BANK_PER"] ?? "8") ?? 8
        var byTechnique: [Technique: [(drill: Drill, explanation: String)]] = [:]
        var seen: Set<String> = []
        var rejected = 0
        for path in inputs.split(separator: ":") {
            let text = try String(contentsOfFile: String(path), encoding: .utf8)
            for line in text.split(separator: "\n") {
                guard let bar = line.firstIndex(of: "|"),
                      let raw = Int(line[..<bar]), let technique = Technique(rawValue: raw),
                      let drill = TrainingEngine.decode(String(line[line.index(after: bar)...]), technique: technique)
                else { continue }
                // One position per puzzle per technique.
                let key = "\(raw)|" + drill.givens.cells.map(String.init).joined()
                guard !seen.contains(key) else { continue }
                // Re-verify: still the cheapest deduction, and sound.
                guard let d = drill.deduction, d.technique == technique, isSound(d, solution: drill.solution) else {
                    rejected += 1
                    continue
                }
                seen.insert(key)
                byTechnique[technique, default: []].append((drill, d.explanation))
            }
        }
        var swift = """
        // Generated by the offline drill miner (see DrillBankTools in the test
        // target); do not edit by hand. Each entry is a real solve position
        // where the technique is the cheapest available deduction, verified
        // sound against the puzzle's solution. Entries are ordered tersest-
        // explanation first, so `drills(for:).first` is the clearest instance —
        // the lesson's worked example.
        public enum TrainingBank {
            /// Shipped practice positions for a technique, clearest first.
            public static func drills(for technique: Technique) -> [Drill] {
                (encoded[technique] ?? []).compactMap { TrainingEngine.decode($0, technique: technique) }
            }

            static let encoded: [Technique: [String]] = [

        """
        for t in Technique.allCases {
            let list = (byTechnique[t] ?? []).sorted { $0.explanation.count < $1.explanation.count }
            var chosen: [Drill] = []
            if list.count <= per {
                chosen = list.map(\.drill)
            } else {
                // Tersest first, then an even spread through the rest for variety.
                chosen.append(list[0].drill)
                let stride = Double(list.count - 1) / Double(per - 1)
                for k in 1..<per { chosen.append(list[Int(Double(k) * stride)].drill) }
            }
            print("  \(t.displayName): \(chosen.count) of \(list.count)")
            swift += "        .\(t): [\n"
            for d in chosen { swift += "            \"\(TrainingEngine.encode(d))\",\n" }
            swift += "        ],\n"
        }
        swift += "    ]\n}\n"
        try swift.write(toFile: out, atomically: true, encoding: .utf8)
        print("wrote \(out); rejected \(rejected)")
    }

    private func isSound(_ d: Deduction, solution: Grid) -> Bool {
        switch d.kind {
        case .place(let cell, let digit):
            return solution.cells[cell] == digit
        case .eliminate(let elims):
            return elims.allSatisfy { !$0.digits.contains(digit: solution.cells[$0.cell]) }
        }
    }
}
