/// A single logical step: either a placement or a set of candidate eliminations.
public struct Deduction: Sendable {
    public enum Kind: Sendable {
        case place(cell: Int, digit: UInt8)
        case eliminate([(cell: Int, digits: CandidateSet)])
    }

    public let kind: Kind
    public let technique: Technique
    public let explanation: String
}

public enum Techniques {
    /// Find the cheapest available deduction, trying techniques in ascending order.
    /// Iteration order is fixed, so results are deterministic for a given grid state.
    public static func findDeduction(grid: Grid, candidates: [CandidateSet]) -> Deduction? {
        if let d = nakedSingle(grid, candidates) { return d }
        if let d = hiddenSingle(grid, candidates) { return d }
        if let d = lockedCandidates(grid, candidates) { return d }
        if let d = nakedSubset(grid, candidates, size: 2) { return d }
        if let d = hiddenPair(grid, candidates) { return d }
        if let d = nakedSubset(grid, candidates, size: 3) { return d }
        if let d = xWing(grid, candidates) { return d }
        return nil
    }

    // MARK: - Singles

    static func nakedSingle(_ grid: Grid, _ cands: [CandidateSet]) -> Deduction? {
        for i in 0..<81 where grid.cells[i] == 0 && cands[i].count == 1 {
            let d = cands[i].first!
            return Deduction(
                kind: .place(cell: i, digit: d),
                technique: .nakedSingle,
                explanation: "R\(i / 9 + 1)C\(i % 9 + 1) has only one possible digit: \(d)."
            )
        }
        return nil
    }

    static func hiddenSingle(_ grid: Grid, _ cands: [CandidateSet]) -> Deduction? {
        for (u, unit) in Grid.units.enumerated() {
            for d: UInt8 in 1...9 {
                var found = -1
                var count = 0
                for i in unit where grid.cells[i] == 0 && cands[i].contains(digit: d) {
                    found = i
                    count += 1
                    if count > 1 { break }
                }
                // Skip when the digit is already placed in this unit.
                if count == 1 && !unit.contains(where: { grid.cells[$0] == d }) {
                    return Deduction(
                        kind: .place(cell: found, digit: d),
                        technique: .hiddenSingle,
                        explanation: "\(Grid.unitName(u)) has only one place left for a \(d)."
                    )
                }
            }
        }
        return nil
    }

    // MARK: - Locked candidates

    static func lockedCandidates(_ grid: Grid, _ cands: [CandidateSet]) -> Deduction? {
        // Pointing: candidates for a digit within a box confined to one row/col
        // eliminate that digit from the rest of the row/col.
        for b in 0..<9 {
            let box = Grid.units[18 + b]
            for d: UInt8 in 1...9 {
                let positions = box.filter { grid.cells[$0] == 0 && cands[$0].contains(digit: d) }
                guard positions.count >= 2 else { continue }
                let rows = Set(positions.map { $0 / 9 })
                let cols = Set(positions.map { $0 % 9 })
                if rows.count == 1 {
                    let r = rows.first!
                    let elims = (0..<9).map { r * 9 + $0 }.filter {
                        !box.contains($0) && grid.cells[$0] == 0 && cands[$0].contains(digit: d)
                    }
                    if !elims.isEmpty {
                        return Deduction(
                            kind: .eliminate(elims.map { ($0, CandidateSet(digit: d)) }),
                            technique: .lockedCandidates,
                            explanation: "In Box \(b + 1), \(d) is confined to Row \(r + 1), so it can be removed elsewhere in that row."
                        )
                    }
                }
                if cols.count == 1 {
                    let c = cols.first!
                    let elims = (0..<9).map { $0 * 9 + c }.filter {
                        !box.contains($0) && grid.cells[$0] == 0 && cands[$0].contains(digit: d)
                    }
                    if !elims.isEmpty {
                        return Deduction(
                            kind: .eliminate(elims.map { ($0, CandidateSet(digit: d)) }),
                            technique: .lockedCandidates,
                            explanation: "In Box \(b + 1), \(d) is confined to Column \(c + 1), so it can be removed elsewhere in that column."
                        )
                    }
                }
            }
        }
        // Claiming: candidates for a digit within a row/col confined to one box
        // eliminate that digit from the rest of the box.
        for u in 0..<18 {
            let line = Grid.units[u]
            for d: UInt8 in 1...9 {
                let positions = line.filter { grid.cells[$0] == 0 && cands[$0].contains(digit: d) }
                guard positions.count >= 2 else { continue }
                let boxes = Set(positions.map { Grid.box(of: $0) })
                if boxes.count == 1 {
                    let b = boxes.first!
                    let elims = Grid.units[18 + b].filter {
                        !line.contains($0) && grid.cells[$0] == 0 && cands[$0].contains(digit: d)
                    }
                    if !elims.isEmpty {
                        return Deduction(
                            kind: .eliminate(elims.map { ($0, CandidateSet(digit: d)) }),
                            technique: .lockedCandidates,
                            explanation: "In \(Grid.unitName(u)), \(d) is confined to Box \(b + 1), so it can be removed elsewhere in that box."
                        )
                    }
                }
            }
        }
        return nil
    }

    // MARK: - Naked subsets (pairs and triples)

    static func nakedSubset(_ grid: Grid, _ cands: [CandidateSet], size: Int) -> Deduction? {
        let technique: Technique = size == 2 ? .nakedPair : .nakedTriple
        for (u, unit) in Grid.units.enumerated() {
            let empty = unit.filter { grid.cells[$0] == 0 && cands[$0].count >= 2 && cands[$0].count <= size }
            guard empty.count >= size else { continue }
            for combo in combinations(of: empty, choose: size) {
                var union = CandidateSet()
                for i in combo { union.formUnion(cands[i]) }
                guard union.count == size else { continue }
                var elims: [(Int, CandidateSet)] = []
                for i in unit where grid.cells[i] == 0 && !combo.contains(i) {
                    let removable = cands[i].intersection(union)
                    if !removable.isEmpty { elims.append((i, removable)) }
                }
                if !elims.isEmpty {
                    let digits = union.digits.map(String.init).joined(separator: ", ")
                    return Deduction(
                        kind: .eliminate(elims),
                        technique: technique,
                        explanation: "\(technique.displayName) (\(digits)) in \(Grid.unitName(u)) removes those digits from other cells."
                    )
                }
            }
        }
        return nil
    }

    // MARK: - Hidden pair

    static func hiddenPair(_ grid: Grid, _ cands: [CandidateSet]) -> Deduction? {
        for (u, unit) in Grid.units.enumerated() {
            var positions: [UInt8: [Int]] = [:]
            for d: UInt8 in 1...9 {
                let p = unit.filter { grid.cells[$0] == 0 && cands[$0].contains(digit: d) }
                if p.count == 2 { positions[d] = p }
            }
            let digits = positions.keys.sorted()
            for i in 0..<digits.count {
                for j in (i + 1)..<digits.count {
                    let (d1, d2) = (digits[i], digits[j])
                    guard positions[d1]! == positions[d2]! else { continue }
                    let pair = CandidateSet(digits: [d1, d2])
                    var elims: [(Int, CandidateSet)] = []
                    for cell in positions[d1]! {
                        let extras = cands[cell].subtracting(pair)
                        if !extras.isEmpty { elims.append((cell, extras)) }
                    }
                    if !elims.isEmpty {
                        return Deduction(
                            kind: .eliminate(elims),
                            technique: .hiddenPair,
                            explanation: "Digits \(d1) and \(d2) can only go in two cells of \(Grid.unitName(u)), so those cells hold nothing else."
                        )
                    }
                }
            }
        }
        return nil
    }

    // MARK: - X-Wing

    static func xWing(_ grid: Grid, _ cands: [CandidateSet]) -> Deduction? {
        for d: UInt8 in 1...9 {
            // Row-based X-Wing.
            if let ded = xWingAxis(grid, cands, digit: d, rowBased: true) { return ded }
            // Column-based X-Wing.
            if let ded = xWingAxis(grid, cands, digit: d, rowBased: false) { return ded }
        }
        return nil
    }

    private static func xWingAxis(_ grid: Grid, _ cands: [CandidateSet], digit d: UInt8, rowBased: Bool) -> Deduction? {
        func index(_ line: Int, _ cross: Int) -> Int {
            rowBased ? line * 9 + cross : cross * 9 + line
        }
        var lines: [(line: Int, crosses: [Int])] = []
        for line in 0..<9 {
            let crosses = (0..<9).filter {
                let i = index(line, $0)
                return grid.cells[i] == 0 && cands[i].contains(digit: d)
            }
            if crosses.count == 2 { lines.append((line, crosses)) }
        }
        for i in 0..<lines.count {
            for j in (i + 1)..<lines.count where lines[i].crosses == lines[j].crosses {
                var elims: [(Int, CandidateSet)] = []
                for other in 0..<9 where other != lines[i].line && other != lines[j].line {
                    for cross in lines[i].crosses {
                        let idx = index(other, cross)
                        if grid.cells[idx] == 0 && cands[idx].contains(digit: d) {
                            elims.append((idx, CandidateSet(digit: d)))
                        }
                    }
                }
                if !elims.isEmpty {
                    let axis = rowBased ? "rows" : "columns"
                    return Deduction(
                        kind: .eliminate(elims),
                        technique: .xWing,
                        explanation: "X-Wing on \(d) in \(axis) \(lines[i].line + 1) and \(lines[j].line + 1)."
                    )
                }
            }
        }
        return nil
    }

    // MARK: - Helpers

    static func combinations(of items: [Int], choose k: Int) -> [[Int]] {
        guard items.count >= k else { return [] }
        if k == 0 { return [[]] }
        var result: [[Int]] = []
        func recurse(_ start: Int, _ current: [Int]) {
            if current.count == k {
                result.append(current)
                return
            }
            for i in start..<items.count {
                recurse(i + 1, current + [items[i]])
            }
        }
        recurse(0, [])
        return result
    }
}
