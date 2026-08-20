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
                        reasoning: "The four highlighted cells sit on two rows, two columns, and two boxes, and all four could take \(x) or \(y). If they ended up holding only those two digits, you could swap the \(x)s and \(y)s and get a second valid solution, and a proper puzzle has just one. So the rectangle can never close up that way. Here, \(note)."
                    )
                }

                if floors.count == 3, roofs.count == 1 {
                    let roof = roofs[0]
                    let extra = cands[roof].intersection(pair)
                    if !extra.isEmpty {
                        return result([(roof, pair)], "three corners are already down to just \(x) and \(y), so the fourth, \(cellName(roof)), must be something else")
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
                        return result(elims, "the two roof cells carry one extra digit, \(z), and one of them has to actually be that \(z), so any cell that sees both roof cells can't be")
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
                                    return result(elims, "one roof cell has to take one of the roof's extra digits, so the two roof cells together act like a single cell holding those extras, and that cell forms a naked subset with \(k) other cell\(k == 1 ? "" : "s") of \(Grid.unitName(u))")
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
                                return result(elims, "a \(keep) has to land in one of the two roof cells, so neither roof cell can be \(drop) (that would leave the other roof as \(keep) and complete the deadly pattern)")
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
                                return result(elims, "the \(d) has nowhere to go in the rectangle's rows and columns except the rectangle itself, which forces it onto the two floor cells and leaves the roof cells without it")
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
                                reasoning: "The four highlighted cells form a rectangle across two boxes, and \(cellName(floor)) is already down to just \(x) and \(y). In the row and column of the opposite corner, \(cellName(opp)), the only places left for a \(keep) are inside the rectangle. Suppose \(cellName(opp)) were a \(drop): then \(cellName(floor)) would be a \(keep), and the two remaining corners would both have to be \(keep)s too, giving a rectangle of only \(x)s and \(y)s that could be swapped into a second solution. A proper puzzle has one solution, so that can't happen."
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
                    reasoning: "\(cellName(p1)), \(cellName(p2)) and \(cellName(p3)) are all digits you placed, not givens, and they form three corners of a rectangle across two boxes: a \(a) opposite two \(grid.cells[p2])s. If \(cellName(target)) were also a \(a), those four cells could be swapped around into a second valid solution, and a proper puzzle has only one."
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
                    reasoning: "Every empty cell on the board has exactly two candidates except \(cellName(tri)), which has three. Take away its \(z) and every remaining digit would appear exactly twice in every row, column, and box, a position that always has two solutions. A proper puzzle has one, so the \(z) has to be the real one."
                )
            }
        }
        return nil
    }
}
