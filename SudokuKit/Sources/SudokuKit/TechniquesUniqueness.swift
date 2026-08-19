/// Uniqueness techniques: valid only because every generated puzzle has
/// exactly one solution — a position that could complete two ways (a "deadly
/// pattern") therefore can't occur, and whatever would allow one is false.
extension Techniques {

    /// Rectangles spanning exactly two boxes, as (r1c1, r1c2, r2c1, r2c2).
    static let rectangles: [(Int, Int, Int, Int)] = {
        var result: [(Int, Int, Int, Int)] = []
        for r1 in 0..<9 {
            for r2 in (r1 + 1)..<9 {
                for c1 in 0..<9 {
                    for c2 in (c1 + 1)..<9 {
                        if (r1 / 3 == r2 / 3) != (c1 / 3 == c2 / 3) {
                            result.append((r1 * 9 + c1, r1 * 9 + c2, r2 * 9 + c1, r2 * 9 + c2))
                        }
                    }
                }
            }
        }
        return result
    }()

    /// Unique Rectangle types 1–6 (types 2 and 5 unified). All four corners
    /// hold the pair; if the puzzle is unique, the fourth corner can't reduce
    /// to it.
    static func uniqueRectangle(_ grid: Grid, _ cands: [CandidateSet]) -> Deduction? {
        for (p, q, r, s) in rectangles {
            let corners = [p, q, r, s]
            guard corners.allSatisfy({ grid.cells[$0] == 0 }) else { continue }
            var common = cands[p]
            for i in [q, r, s] { common.formIntersection(cands[i]) }
            guard common.count >= 2 else { continue }
            for pairDigits in combinations(of: common.digits, choose: 2) {
                let pair = CandidateSet(digits: pairDigits)
                let (x, y) = (pairDigits[0], pairDigits[1])
                let floors = corners.filter { cands[$0] == pair }
                let roofs = corners.filter { cands[$0] != pair }

                func result(_ elims: [(Int, CandidateSet)], _ note: String) -> Deduction {
                    Deduction(
                        kind: .eliminate(elims),
                        technique: .uniqueRectangle,
                        patternCells: corners.sorted(),
                        keyDigits: pair,
                        explanation: "Unique Rectangle on {\(x),\(y)}: \(note) — otherwise the rectangle could complete two ways and the puzzle would have two solutions."
                    )
                }

                if floors.count == 3, roofs.count == 1 {
                    let roof = roofs[0]
                    let extra = cands[roof].intersection(pair)
                    if !extra.isEmpty {
                        return result([(roof, pair)], "three corners are down to the bare pair, so \(cellName(roof)) can't be either digit")
                    }
                }
                guard floors.count == 2, roofs.count == 2 else { continue }
                let (r1, r2) = (roofs[0], roofs[1])
                let extras = cands[r1].union(cands[r2]).subtracting(pair)
                // Types 2/5: a single shared extra digit.
                if extras.count == 1,
                   cands[r1].subtracting(pair) == extras,
                   cands[r2].subtracting(pair) == extras,
                   let z = extras.first {
                    var elims: [(Int, CandidateSet)] = []
                    for i in 0..<81 where !corners.contains(i) && grid.cells[i] == 0
                        && cands[i].contains(digit: z) && sees[i][r1] && sees[i][r2] {
                        elims.append((i, CandidateSet(digit: z)))
                    }
                    if !elims.isEmpty {
                        return result(elims, "one roof cell must take the extra \(z)")
                    }
                }
                let shared = containingUnits(of: [r1, r2])
                // Type 3: roof extras as a pseudo-cell in a naked subset.
                if extras.count >= 2 && extras.count <= 3 {
                    for u in shared {
                        let others = Grid.units[u].filter {
                            !corners.contains($0) && grid.cells[$0] == 0
                                && cands[$0].count >= 2 && cands[$0].count <= extras.count
                        }
                        for k in 1..<extras.count {
                            for sub in combinations(of: others, choose: k) {
                                var union = extras
                                for i in sub { union.formUnion(cands[i]) }
                                guard union.count == k + 1 else { continue }
                                var elims: [(Int, CandidateSet)] = []
                                for i in Grid.units[u] where !corners.contains(i) && !sub.contains(i) && grid.cells[i] == 0 {
                                    let rem = cands[i].intersection(union)
                                    if !rem.isEmpty { elims.append((i, rem)) }
                                }
                                if !elims.isEmpty {
                                    return result(elims, "the roof's extra digits pair up with \(k) other cell\(k == 1 ? "" : "s") of \(Grid.unitName(u)) into a subset")
                                }
                            }
                        }
                    }
                }
                // Type 4: a pair digit locked to the roof cells in a shared unit.
                for u in shared {
                    for (keep, drop) in [(x, y), (y, x)] {
                        let pos = Grid.units[u].filter { grid.cells[$0] == 0 && cands[$0].contains(digit: keep) }
                        if Set(pos) == Set([r1, r2]) {
                            let elims = [r1, r2].filter { cands[$0].contains(digit: drop) }
                                .map { ($0, CandidateSet(digit: drop)) }
                            if !elims.isEmpty {
                                return result(elims, "\(keep) must land in one roof cell, so neither can be \(drop)")
                            }
                        }
                    }
                }
                // Type 6: diagonal floors + the pair digit X-Wing-locked on
                // the corners.
                if !sees[floors[0]][floors[1]] {
                    let rowSet: Set<Int> = [p / 9, r / 9]
                    let colSet: Set<Int> = [p % 9, q % 9]
                    for d in [x, y] {
                        var locked = true
                        for rr in rowSet.sorted() {
                            for i in Grid.units[rr] where grid.cells[i] == 0 && cands[i].contains(digit: d) {
                                if !colSet.contains(i % 9) { locked = false }
                            }
                        }
                        for cc in colSet.sorted() where locked {
                            for i in Grid.units[9 + cc] where grid.cells[i] == 0 && cands[i].contains(digit: d) {
                                if !rowSet.contains(i / 9) { locked = false }
                            }
                        }
                        if locked {
                            let elims = roofs.filter { cands[$0].contains(digit: d) }
                                .map { ($0, CandidateSet(digit: d)) }
                            if !elims.isEmpty {
                                return result(elims, "\(d) is confined to the rectangle's own rows and columns, forcing it onto the floor diagonal")
                            }
                        }
                    }
                }
            }
        }
        return nil
    }

    /// Hidden Rectangle: one bare-pair floor; if a pair digit is confined to
    /// the rectangle in the opposite corner's row and column, that corner
    /// can't take the other digit.
    static func hiddenRectangle(_ grid: Grid, _ cands: [CandidateSet]) -> Deduction? {
        for (p, q, r, s) in rectangles {
            let corners = [p, q, r, s]
            guard corners.allSatisfy({ grid.cells[$0] == 0 }) else { continue }
            var common = cands[p]
            for i in [q, r, s] { common.formIntersection(cands[i]) }
            guard common.count >= 2 else { continue }
            let cornerSet = Set(corners)
            for pairDigits in combinations(of: common.digits, choose: 2) {
                let pair = CandidateSet(digits: pairDigits)
                let (x, y) = (pairDigits[0], pairDigits[1])
                for (floor, opp) in [(p, s), (q, r), (r, q), (s, p)] {
                    guard cands[floor] == pair else { continue }
                    for (keep, drop) in [(x, y), (y, x)] {
                        let rowPos = Grid.units[opp / 9].filter { grid.cells[$0] == 0 && cands[$0].contains(digit: keep) }
                        let colPos = Grid.units[9 + opp % 9].filter { grid.cells[$0] == 0 && cands[$0].contains(digit: keep) }
                        if Set(rowPos).isSubset(of: cornerSet), Set(colPos).isSubset(of: cornerSet),
                           cands[opp].contains(digit: drop) {
                            return Deduction(
                                kind: .eliminate([(opp, CandidateSet(digit: drop))]),
                                technique: .hiddenRectangle,
                                patternCells: corners.sorted(),
                                keyDigits: pair,
                                explanation: "Hidden Rectangle on {\(x),\(y)}: if \(cellName(opp)) were \(drop), the \(keep)s would complete the deadly rectangle — impossible in a unique puzzle."
                            )
                        }
                    }
                }
            }
        }
        return nil
    }

    /// Avoidable Rectangle: three corners solved by the player (not givens)
    /// in an a/b/b pattern. The fourth can't be `a`, or swapping the
    /// rectangle would have been a second solution.
    static func avoidableRectangle(_ grid: Grid, _ cands: [CandidateSet], givens: Grid?) -> Deduction? {
        guard let givens else { return nil }
        for (p, q, r, s) in rectangles {
            for (p1, p2, p3, target) in [(p, q, r, s), (q, p, s, r), (r, s, p, q), (s, r, q, p)] {
                guard grid.cells[target] == 0,
                      grid.cells[p1] != 0, grid.cells[p2] != 0, grid.cells[p3] != 0,
                      givens.cells[p1] == 0, givens.cells[p2] == 0, givens.cells[p3] == 0,
                      grid.cells[p2] == grid.cells[p3],
                      grid.cells[p1] != grid.cells[p2],
                      cands[target].contains(digit: grid.cells[p1])
                else { continue }
                let a = grid.cells[p1]
                return Deduction(
                    kind: .eliminate([(target, CandidateSet(digit: a))]),
                    technique: .avoidableRectangle,
                    patternCells: [p1, p2, p3, target].sorted(),
                    keyDigits: CandidateSet(digits: [a, grid.cells[p2]]),
                    explanation: "Avoidable Rectangle: with \(cellName(p1)), \(cellName(p2)) and \(cellName(p3)) all solved (none given), a \(a) at \(cellName(target)) would make the rectangle swappable — the puzzle would have had two solutions."
                )
            }
        }
        return nil
    }

    /// BUG+1: every unsolved cell bivalue except one. A perfect BUG (every
    /// digit exactly twice per unit) has no unique solution, so the candidate
    /// whose removal would create one must be placed.
    static func bugPlusOne(_ grid: Grid, _ cands: [CandidateSet]) -> Deduction? {
        var tri = -1
        for i in 0..<81 where grid.cells[i] == 0 {
            switch cands[i].count {
            case 2: continue
            case 3:
                if tri != -1 { return nil }
                tri = i
            default:
                return nil
            }
        }
        guard tri != -1 else { return nil }
        for z in cands[tri].digits {
            var ok = true
            outer: for unit in Grid.units {
                for d: UInt8 in 1...9 {
                    var cnt = 0
                    for i in unit where grid.cells[i] == 0 && cands[i].contains(digit: d) {
                        cnt += 1
                    }
                    if unit.contains(tri) && d == z { cnt -= 1 }
                    if cnt != 0 && cnt != 2 {
                        ok = false
                        break outer
                    }
                }
            }
            if ok {
                return Deduction(
                    kind: .place(cell: tri, digit: z),
                    technique: .bugPlusOne,
                    patternCells: [tri],
                    keyDigits: CandidateSet(digit: z),
                    explanation: "BUG+1: without the \(z), every remaining cell would pair up into a pattern with two solutions — so \(cellName(tri)) must be \(z)."
                )
            }
        }
        return nil
    }
}
