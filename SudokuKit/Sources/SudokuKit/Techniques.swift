/// A single logical step: either a placement or a set of candidate eliminations.
///
/// Beyond the action itself, a deduction carries the machine-readable shape of
/// the pattern that justifies it — which cells form it, which unit it lives
/// in, and which digits it is about — so hints, coaching, and lessons can
/// highlight the reasoning instead of just asserting the conclusion.
public struct Deduction: Sendable {
    public enum Kind: Sendable {
        case place(cell: Int, digit: UInt8)
        case eliminate([(cell: Int, digits: CandidateSet)])
    }

    public let kind: Kind
    public let technique: Technique
    /// Cells forming the pattern: the subset's cells, the fish's corners,
    /// the single's cell. Sorted ascending.
    public let patternCells: [Int]
    /// Index into `Grid.units` when the pattern has one home unit; nil for
    /// patterns spanning units (naked single, X-Wing).
    public let unit: Int?
    /// The digits the pattern reasons about.
    public let keyDigits: CandidateSet
    public let explanation: String

    public init(
        kind: Kind,
        technique: Technique,
        patternCells: [Int] = [],
        unit: Int? = nil,
        keyDigits: CandidateSet = CandidateSet(),
        explanation: String
    ) {
        self.kind = kind
        self.technique = technique
        self.patternCells = patternCells
        self.unit = unit
        self.keyDigits = keyDigits
        self.explanation = explanation
    }

    /// Cells that lose candidates (empty for placements).
    public var eliminationCells: [Int] {
        switch kind {
        case .place: []
        case .eliminate(let elims): elims.map(\.cell)
        }
    }
}

public enum Techniques {
    /// Find the cheapest available deduction, trying techniques in ascending order.
    /// Iteration order is fixed, so results are deterministic for a given grid state.
    public static func findDeduction(grid: Grid, candidates: [CandidateSet]) -> Deduction? {
        if let d = fullHouse(grid, candidates) { return d }
        if let d = nakedSingle(grid, candidates) { return d }
        if let d = hiddenSingle(grid, candidates) { return d }
        if let d = lockedCandidates(grid, candidates) { return d }
        if let d = nakedSubset(grid, candidates, size: 2) { return d }
        if let d = hiddenSubset(grid, candidates, size: 2) { return d }
        if let d = nakedSubset(grid, candidates, size: 3) { return d }
        if let d = hiddenSubset(grid, candidates, size: 3) { return d }
        if let d = nakedSubset(grid, candidates, size: 4) { return d }
        if let d = hiddenSubset(grid, candidates, size: 4) { return d }
        if let d = xWing(grid, candidates) { return d }
        return nil
    }

    // MARK: - Singles

    /// The last empty cell of a unit. Logically a naked single, but reported
    /// under its friendlier name — it's the first thing every player learns.
    static func fullHouse(_ grid: Grid, _ cands: [CandidateSet]) -> Deduction? {
        for (u, unit) in Grid.units.enumerated() {
            var emptyCell = -1
            var emptyCount = 0
            for i in unit where grid.cells[i] == 0 {
                emptyCell = i
                emptyCount += 1
                if emptyCount > 1 { break }
            }
            guard emptyCount == 1, let d = cands[emptyCell].first else { continue }
            return Deduction(
                kind: .place(cell: emptyCell, digit: d),
                technique: .fullHouse,
                patternCells: [emptyCell],
                unit: u,
                keyDigits: CandidateSet(digit: d),
                explanation: "R\(emptyCell / 9 + 1)C\(emptyCell % 9 + 1) is the last empty cell of \(Grid.unitName(u)) — it takes the \(d)."
            )
        }
        return nil
    }

    static func nakedSingle(_ grid: Grid, _ cands: [CandidateSet]) -> Deduction? {
        for i in 0..<81 where grid.cells[i] == 0 && cands[i].count == 1 {
            let d = cands[i].first!
            return Deduction(
                kind: .place(cell: i, digit: d),
                technique: .nakedSingle,
                patternCells: [i],
                keyDigits: CandidateSet(digit: d),
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
                        patternCells: [found],
                        unit: u,
                        keyDigits: CandidateSet(digit: d),
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
                            patternCells: positions,
                            unit: 18 + b,
                            keyDigits: CandidateSet(digit: d),
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
                            patternCells: positions,
                            unit: 18 + b,
                            keyDigits: CandidateSet(digit: d),
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
                            patternCells: positions,
                            unit: u,
                            keyDigits: CandidateSet(digit: d),
                            explanation: "In \(Grid.unitName(u)), \(d) is confined to Box \(b + 1), so it can be removed elsewhere in that box."
                        )
                    }
                }
            }
        }
        return nil
    }

    // MARK: - Naked subsets (pairs, triples, and quadruples)

    /// Naked subsets of `size` cells covering exactly `size` digits.
    ///
    /// A pair or triple whose cells sit in a box–line intersection is reported
    /// as a Locked Pair/Triple: it eliminates from *both* containing units at
    /// once, and is worth its own name because it's easier to spot and
    /// strictly stronger. (A quadruple can't be locked — an intersection has
    /// only three cells.)
    static func nakedSubset(_ grid: Grid, _ cands: [CandidateSet], size: Int) -> Deduction? {
        for (u, unit) in Grid.units.enumerated() {
            let empty = unit.filter { grid.cells[$0] == 0 && cands[$0].count >= 2 && cands[$0].count <= size }
            guard empty.count >= size else { continue }
            for combo in combinations(of: empty, choose: size) {
                var union = CandidateSet()
                for i in combo { union.formUnion(cands[i]) }
                guard union.count == size else { continue }

                // Every unit containing all the subset's cells may be cleaned.
                let homes = containingUnits(of: combo)
                let comboSet = Set(combo)
                var elims: [(Int, CandidateSet)] = []
                var elimSeen = Set<Int>()
                for h in homes {
                    for i in Grid.units[h] where grid.cells[i] == 0 && !comboSet.contains(i) && !elimSeen.contains(i) {
                        let removable = cands[i].intersection(union)
                        if !removable.isEmpty {
                            elims.append((i, removable))
                            elimSeen.insert(i)
                        }
                    }
                }
                if !elims.isEmpty {
                    let locked = homes.count > 1
                    let technique: Technique = switch (size, locked) {
                    case (2, true): .lockedPair
                    case (2, false): .nakedPair
                    case (3, true): .lockedTriple
                    case (3, false): .nakedTriple
                    default: .nakedQuad
                    }
                    let digits = digitList(union)
                    let explanation = locked
                        ? "\(technique.displayName) (\(digits)) sits in \(homes.map(Grid.unitName).joined(separator: " and ")) — those digits can be removed from the rest of both units."
                        : "\(technique.displayName) (\(digits)) in \(Grid.unitName(u)) removes those digits from other cells."
                    return Deduction(
                        kind: .eliminate(elims),
                        technique: technique,
                        patternCells: combo,
                        unit: u,
                        keyDigits: union,
                        explanation: explanation
                    )
                }
            }
        }
        return nil
    }

    // MARK: - Hidden subsets (pairs, triples, and quadruples)

    /// Hidden subsets: `size` digits confined to the same `size` cells of a
    /// unit, so everything else in those cells is noise. A digit needn't
    /// appear in all of the cells — {2,5}, {2,7}, {5,7} is a valid hidden
    /// triple on {2, 5, 7}.
    static func hiddenSubset(_ grid: Grid, _ cands: [CandidateSet], size: Int) -> Deduction? {
        let technique: Technique = switch size {
        case 2: .hiddenPair
        case 3: .hiddenTriple
        default: .hiddenQuad
        }
        for (u, unit) in Grid.units.enumerated() {
            // Candidate digits: those confined to 2...size cells of the unit.
            // (A single-position digit is a hidden single, found earlier.)
            var positions: [UInt8: [Int]] = [:]
            for d: UInt8 in 1...9 {
                let p = unit.filter { grid.cells[$0] == 0 && cands[$0].contains(digit: d) }
                if p.count >= 2 && p.count <= size { positions[d] = p }
            }
            guard positions.count >= size else { continue }
            for digitCombo in combinations(of: positions.keys.sorted(), choose: size) {
                var cells = Set<Int>()
                for d in digitCombo { cells.formUnion(positions[d]!) }
                guard cells.count == size else { continue }
                let subset = CandidateSet(digits: digitCombo)
                var elims: [(Int, CandidateSet)] = []
                for cell in cells.sorted() {
                    let extras = cands[cell].subtracting(subset)
                    if !extras.isEmpty { elims.append((cell, extras)) }
                }
                if !elims.isEmpty {
                    let cellWord = ["two", "three", "four"][size - 2]
                    return Deduction(
                        kind: .eliminate(elims),
                        technique: technique,
                        patternCells: cells.sorted(),
                        unit: u,
                        keyDigits: subset,
                        explanation: "Digits \(digitList(subset)) can only go in \(cellWord) cells of \(Grid.unitName(u)), so those cells hold nothing else."
                    )
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
                    let corners = (lines[i].crosses + lines[j].crosses).enumerated().map {
                        index($0.offset < 2 ? lines[i].line : lines[j].line, $0.element)
                    }
                    return Deduction(
                        kind: .eliminate(elims),
                        technique: .xWing,
                        patternCells: corners.sorted(),
                        keyDigits: CandidateSet(digit: d),
                        explanation: "X-Wing on \(d) in \(axis) \(lines[i].line + 1) and \(lines[j].line + 1)."
                    )
                }
            }
        }
        return nil
    }

    // MARK: - Helpers

    /// Indices into `Grid.units` of every unit containing all of `cells`.
    static func containingUnits(of cells: [Int]) -> [Int] {
        var result: [Int] = []
        if Set(cells.map { $0 / 9 }).count == 1 { result.append(cells[0] / 9) }
        if Set(cells.map { $0 % 9 }).count == 1 { result.append(9 + cells[0] % 9) }
        if Set(cells.map(Grid.box(of:))).count == 1 { result.append(18 + Grid.box(of: cells[0])) }
        return result
    }

    /// "4, 9" / "2, 5 and 7" — digits joined for prose.
    static func digitList(_ set: CandidateSet) -> String {
        let digits = set.digits.map(String.init)
        guard digits.count > 1 else { return digits.first ?? "" }
        return digits.dropLast().joined(separator: ", ") + " and " + digits.last!
    }

    static func combinations<T>(of items: [T], choose k: Int) -> [[T]] {
        guard items.count >= k else { return [] }
        if k == 0 { return [[]] }
        var result: [[T]] = []
        func recurse(_ start: Int, _ current: [T]) {
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
