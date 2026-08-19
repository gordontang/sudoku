/// Almost Locked Sets — k cells of a unit spanning k+1 digits — and Sue de
/// Coq, their box–line cousin.
extension Techniques {

    /// Sue de Coq (basic form): 2–3 intersection cells spanning |cells|+2
    /// digits, split by a bivalue cell in the line and one in the box with
    /// disjoint candidates. Every digit's home is then pinned down.
    static func sueDeCoq(_ grid: Grid, _ cands: [CandidateSet]) -> Deduction? {
        for b in 0..<9 {
            let boxSet = Set(Grid.units[18 + b])
            for u in 0..<18 {
                let lineSet = Set(Grid.units[u])
                let inter = boxSet.intersection(lineSet).filter { grid.cells[$0] == 0 }.sorted()
                guard inter.count >= 2 else { continue }
                let lineOnly = lineSet.subtracting(boxSet).sorted()
                let boxOnly = boxSet.subtracting(lineSet).sorted()
                for k in [2, 3] where inter.count >= k {
                    for cells in combinations(of: inter, choose: k) {
                        var v = CandidateSet()
                        for i in cells { v.formUnion(cands[i]) }
                        guard v.count == k + 2 else { continue }
                        let lineBival = lineOnly.filter {
                            grid.cells[$0] == 0 && cands[$0].count == 2 && cands[$0].subtracting(v).isEmpty
                        }
                        let boxBival = boxOnly.filter {
                            grid.cells[$0] == 0 && cands[$0].count == 2 && cands[$0].subtracting(v).isEmpty
                        }
                        for la in lineBival {
                            for bc in boxBival {
                                guard cands[la].intersection(cands[bc]).isEmpty else { continue }
                                let aset = cands[la], cset = cands[bc]
                                let rest = v.subtracting(aset).subtracting(cset)
                                var elims: [(Int, CandidateSet)] = []
                                for i in lineOnly where i != la && grid.cells[i] == 0 {
                                    let rem = cands[i].intersection(aset.union(rest))
                                    if !rem.isEmpty { elims.append((i, rem)) }
                                }
                                for i in boxOnly where i != bc && grid.cells[i] == 0 {
                                    let rem = cands[i].intersection(cset.union(rest))
                                    if !rem.isEmpty { elims.append((i, rem)) }
                                }
                                for i in inter where !cells.contains(i) && grid.cells[i] == 0 {
                                    let rem = cands[i].intersection(v)
                                    if !rem.isEmpty { elims.append((i, rem)) }
                                }
                                if !elims.isEmpty {
                                    return Deduction(
                                        kind: .eliminate(elims),
                                        technique: .sueDeCoq,
                                        patternCells: (cells + [la, bc]).sorted(),
                                        unit: u,
                                        keyDigits: v,
                                        explanation: "Sue de Coq: the \(Grid.unitName(u))/Box \(b + 1) intersection cells plus \(cellName(la)) and \(cellName(bc)) consume the digits \(digitList(v)) between them, pinning where each can go."
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
        return nil
    }

    struct ALS {
        let cells: Set<Int>
        let digits: CandidateSet
    }

    /// Almost locked sets up to `maxSize` cells per unit.
    static func findALS(_ grid: Grid, _ cands: [CandidateSet], maxSize: Int = 4) -> [ALS] {
        var result: [ALS] = []
        var seen = Set<Set<Int>>()
        for unit in Grid.units {
            let empty = unit.filter { grid.cells[$0] == 0 }
            for k in 1...maxSize where empty.count >= k {
                for cells in combinations(of: empty, choose: k) {
                    var digits = CandidateSet()
                    for i in cells { digits.formUnion(cands[i]) }
                    if digits.count == k + 1 {
                        let cellSet = Set(cells)
                        if seen.insert(cellSet).inserted {
                            result.append(ALS(cells: cellSet, digits: digits))
                        }
                    }
                }
            }
        }
        return result
    }

    /// ALS-XZ: two ALSs sharing a restricted common digit x (all x-cells of
    /// one see all x-cells of the other) can't both fail — a second common
    /// digit z dies wherever it sees every z-cell of both.
    static func alsXZ(_ grid: Grid, _ cands: [CandidateSet]) -> Deduction? {
        let als = findALS(grid, cands)
        for i1 in 0..<als.count {
            let a = als[i1]
            for i2 in (i1 + 1)..<als.count {
                let b = als[i2]
                guard a.cells.isDisjoint(with: b.cells) else { continue }
                let commons = a.digits.intersection(b.digits)
                guard commons.count >= 2 else { continue }
                for x in commons.digits {
                    let xs1 = a.cells.filter { cands[$0].contains(digit: x) }
                    let xs2 = b.cells.filter { cands[$0].contains(digit: x) }
                    guard xs1.allSatisfy({ p in xs2.allSatisfy { sees[p][$0] } }) else { continue }
                    for z in commons.digits where z != x {
                        let zs = a.cells.sorted().filter { cands[$0].contains(digit: z) }
                            + b.cells.sorted().filter { cands[$0].contains(digit: z) }
                        var elims: [(Int, CandidateSet)] = []
                        for i in 0..<81 where grid.cells[i] == 0 && !a.cells.contains(i) && !b.cells.contains(i)
                            && cands[i].contains(digit: z) {
                            if zs.allSatisfy({ sees[i][$0] }) {
                                elims.append((i, CandidateSet(digit: z)))
                            }
                        }
                        if !elims.isEmpty {
                            return Deduction(
                                kind: .eliminate(elims),
                                technique: .alsXZ,
                                patternCells: (a.cells.sorted() + b.cells.sorted()),
                                keyDigits: CandidateSet(digits: [x, z]),
                                patternCandidates: zs.sorted().map { CandidateRef(cell: $0, digit: z) },
                                secondaryCandidates: (xs1.sorted() + xs2.sorted()).map { CandidateRef(cell: $0, digit: x) },
                                explanation: "ALS-XZ: the two almost-locked sets are tied together by \(x) — at most one can lose it, so one of them locks and \(z) dies wherever it sees every \(z) of both."
                            )
                        }
                    }
                }
            }
        }
        return nil
    }
}
