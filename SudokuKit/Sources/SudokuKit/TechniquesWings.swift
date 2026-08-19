/// Wings and bivalue-cell chains: XY-Wing, XYZ-Wing, W-Wing, Remote Pair,
/// and XY-Chain — patterns whose raw material is cells with exactly two
/// candidates.
extension Techniques {

    static func xyWing(_ grid: Grid, _ cands: [CandidateSet]) -> Deduction? {
        var bival: [Int] = []
        for i in 0..<81 where grid.cells[i] == 0 && cands[i].count == 2 { bival.append(i) }
        for pivot in bival {
            let ds = cands[pivot].digits
            let (x, y) = (ds[0], ds[1])
            for w1 in bival where w1 != pivot && sees[pivot][w1] {
                for w2 in bival where w2 != pivot && w2 != w1 && sees[pivot][w2] {
                    let s1 = cands[w1], s2 = cands[w2]
                    for (a, b) in [(x, y), (y, x)] {
                        guard s1.contains(digit: a), s2.contains(digit: b) else { continue }
                        let zs = s1.subtracting(CandidateSet(digit: a))
                            .intersection(s2.subtracting(CandidateSet(digit: b)))
                        for z in zs.digits where z != a && z != b {
                            var elims: [(Int, CandidateSet)] = []
                            for i in 0..<81 where i != pivot && i != w1 && i != w2
                                && grid.cells[i] == 0 && cands[i].contains(digit: z)
                                && sees[i][w1] && sees[i][w2] {
                                elims.append((i, CandidateSet(digit: z)))
                            }
                            if !elims.isEmpty {
                                return Deduction(
                                    kind: .eliminate(elims),
                                    technique: .xyWing,
                                    patternCells: [pivot, w1, w2].sorted(),
                                    keyDigits: CandidateSet(digits: [a, b, z]),
                                    patternCandidates: [CandidateRef(cell: w1, digit: z), CandidateRef(cell: w2, digit: z)],
                                    secondaryCandidates: [CandidateRef(cell: pivot, digit: a), CandidateRef(cell: pivot, digit: b)],
                                    explanation: "XY-Wing: pivot \(cellName(pivot)) {\(a),\(b)} sees wings \(cellName(w1)) and \(cellName(w2)) — either way one wing becomes \(z), so \(z) dies where both are seen."
                                )
                            }
                        }
                    }
                }
            }
        }
        return nil
    }

    static func xyzWing(_ grid: Grid, _ cands: [CandidateSet]) -> Deduction? {
        for pivot in 0..<81 where grid.cells[pivot] == 0 && cands[pivot].count == 3 {
            var bival: [Int] = []
            for i in 0..<81 where grid.cells[i] == 0 && cands[i].count == 2
                && sees[pivot][i] && cands[i].subtracting(cands[pivot]).isEmpty {
                bival.append(i)
            }
            guard bival.count >= 2 else { continue }
            for combo in combinations(of: bival, choose: 2) {
                let (w1, w2) = (combo[0], combo[1])
                let inter = cands[w1].intersection(cands[w2])
                guard inter.count == 1, let z = inter.first else { continue }
                guard cands[w1].union(cands[w2]) == cands[pivot] else { continue }
                var elims: [(Int, CandidateSet)] = []
                for i in 0..<81 where i != pivot && i != w1 && i != w2
                    && grid.cells[i] == 0 && cands[i].contains(digit: z)
                    && sees[i][pivot] && sees[i][w1] && sees[i][w2] {
                    elims.append((i, CandidateSet(digit: z)))
                }
                if !elims.isEmpty {
                    return Deduction(
                        kind: .eliminate(elims),
                        technique: .xyzWing,
                        patternCells: [pivot, w1, w2].sorted(),
                        keyDigits: cands[pivot],
                        patternCandidates: [pivot, w1, w2].sorted().map { CandidateRef(cell: $0, digit: z) },
                        explanation: "XYZ-Wing: \(cellName(pivot)) with its wings \(cellName(w1)) and \(cellName(w2)) must produce a \(z) among them — \(z) dies wherever all three are seen."
                    )
                }
            }
        }
        return nil
    }

    static func wWing(_ grid: Grid, _ cands: [CandidateSet]) -> Deduction? {
        var byPair: [CandidateSet: [Int]] = [:]
        for i in 0..<81 where grid.cells[i] == 0 && cands[i].count == 2 {
            byPair[cands[i], default: []].append(i)
        }
        for (pair, cells) in byPair.sorted(by: { ($0.value.first ?? 81) < ($1.value.first ?? 81) }) {
            guard cells.count >= 2 else { continue }
            let ds = pair.digits
            let (x, y) = (ds[0], ds[1])
            for combo in combinations(of: cells, choose: 2) {
                let (a, b) = (combo[0], combo[1])
                guard !sees[a][b] else { continue }
                for d in [x, y] {
                    let other = d == x ? y : x
                    for (p, q, _) in strongLinks(grid, cands, digit: d) {
                        guard p != a, p != b, q != a, q != b else { continue }
                        for (s, t) in [(p, q), (q, p)] {
                            guard sees[a][s], sees[b][t] else { continue }
                            var elims: [(Int, CandidateSet)] = []
                            for i in 0..<81 where i != a && i != b
                                && grid.cells[i] == 0 && cands[i].contains(digit: other)
                                && sees[i][a] && sees[i][b] {
                                elims.append((i, CandidateSet(digit: other)))
                            }
                            if !elims.isEmpty {
                                let refs = { (c: Int, dd: UInt8) in CandidateRef(cell: c, digit: dd) }
                                return Deduction(
                                    kind: .eliminate(elims),
                                    technique: .wWing,
                                    patternCells: [a, b, s, t].sorted(),
                                    keyDigits: pair,
                                    patternCandidates: [refs(a, other), refs(b, other)],
                                    secondaryCandidates: [refs(s, d), refs(t, d)],
                                    links: [
                                        ChainLink(from: refs(a, d), to: refs(s, d), isStrong: false),
                                        ChainLink(from: refs(s, d), to: refs(t, d), isStrong: true),
                                        ChainLink(from: refs(t, d), to: refs(b, d), isStrong: false),
                                    ],
                                    explanation: "W-Wing: \(cellName(a)) and \(cellName(b)) both hold {\(x),\(y)}; the strong link on \(d) at \(cellName(s))–\(cellName(t)) means one of them must be \(other) — it dies where both are seen."
                                )
                            }
                        }
                    }
                }
            }
        }
        return nil
    }

    static func remotePair(_ grid: Grid, _ cands: [CandidateSet]) -> Deduction? {
        var pairs = Set<CandidateSet>()
        for i in 0..<81 where grid.cells[i] == 0 && cands[i].count == 2 { pairs.insert(cands[i]) }
        for pair in pairs.sorted(by: { $0.rawValue < $1.rawValue }) {
            var cells: [Int] = []
            for i in 0..<81 where grid.cells[i] == 0 && cands[i] == pair { cells.append(i) }
            guard cells.count >= 4 else { continue }
            let cellSet = Set(cells)
            var nbrs: [Int: [Int]] = [:]
            for i in cells { nbrs[i] = cells.filter { $0 != i && sees[i][$0] } }

            var best: ([(Int, CandidateSet)], [Int])?

            func dfs(_ path: inout [Int], _ inPath: inout Set<Int>) {
                guard best == nil else { return }
                if path.count >= 4 && path.count % 2 == 0 {
                    let a = path[0], z = path.last!
                    var elims: [(Int, CandidateSet)] = []
                    for i in 0..<81 where !cellSet.contains(i) && grid.cells[i] == 0 && sees[i][a] && sees[i][z] {
                        let removable = cands[i].intersection(pair)
                        if !removable.isEmpty { elims.append((i, removable)) }
                    }
                    if !elims.isEmpty {
                        best = (elims, path)
                        return
                    }
                }
                guard path.count < 8 else { return }
                for nxt in nbrs[path.last!] ?? [] where !inPath.contains(nxt) {
                    path.append(nxt)
                    inPath.insert(nxt)
                    dfs(&path, &inPath)
                    path.removeLast()
                    inPath.remove(nxt)
                    if best != nil { return }
                }
            }

            for start in cells {
                var path = [start]
                var inPath: Set<Int> = [start]
                dfs(&path, &inPath)
                if let (elims, chain) = best {
                    let ds = pair.digits
                    return Deduction(
                        kind: .eliminate(elims),
                        technique: .remotePair,
                        patternCells: chain.sorted(),
                        keyDigits: pair,
                        patternCandidates: stride(from: 0, to: chain.count, by: 2).map { CandidateRef(cell: chain[$0], digit: ds[0]) },
                        secondaryCandidates: stride(from: 1, to: chain.count, by: 2).map { CandidateRef(cell: chain[$0], digit: ds[0]) },
                        explanation: "Remote Pair on {\(ds[0]),\(ds[1])}: the chain alternates the two digits, so its ends hold different ones — both digits die where both ends are seen."
                    )
                }
            }
        }
        return nil
    }

    /// Chain of bivalue cells, each passing its other digit to the next. If
    /// the start's reserved digit equals the final cell's output, one end
    /// holds it.
    static func xyChain(_ grid: Grid, _ cands: [CandidateSet], maxCells: Int = 8) -> Deduction? {
        var bival: [Int] = []
        for i in 0..<81 where grid.cells[i] == 0 && cands[i].count == 2 { bival.append(i) }
        guard bival.count >= 3 else { return nil }

        var best: ([(Int, CandidateSet)], [Int], UInt8)?

        func dfs(_ path: inout [Int], _ inPath: inout Set<Int>, _ outDigit: UInt8, _ z: UInt8) {
            guard best == nil else { return }
            if path.count >= 3 && outDigit == z {
                let a = path[0], end = path.last!
                var elims: [(Int, CandidateSet)] = []
                for i in 0..<81 where !inPath.contains(i) && grid.cells[i] == 0
                    && cands[i].contains(digit: z) && sees[i][a] && sees[i][end] {
                    elims.append((i, CandidateSet(digit: z)))
                }
                if !elims.isEmpty {
                    best = (elims, path, z)
                    return
                }
            }
            guard path.count < maxCells else { return }
            let last = path.last!
            for nxt in bival where !inPath.contains(nxt) && sees[last][nxt] && cands[nxt].contains(digit: outDigit) {
                path.append(nxt)
                inPath.insert(nxt)
                dfs(&path, &inPath, cands[nxt].subtracting(CandidateSet(digit: outDigit)).first!, z)
                path.removeLast()
                inPath.remove(nxt)
                if best != nil { return }
            }
        }

        for start in bival {
            let ds = cands[start].digits
            for (z, first) in [(ds[0], ds[1]), (ds[1], ds[0])] {
                var path = [start]
                var inPath: Set<Int> = [start]
                dfs(&path, &inPath, first, z)
                if let (elims, chain, zz) = best {
                    return Deduction(
                        kind: .eliminate(elims),
                        technique: .xyChain,
                        patternCells: chain.sorted(),
                        keyDigits: CandidateSet(digit: zz),
                        patternCandidates: [CandidateRef(cell: chain.first!, digit: zz), CandidateRef(cell: chain.last!, digit: zz)],
                        explanation: "XY-Chain: following the bivalue cells from \(cellName(chain.first!)) to \(cellName(chain.last!)), one end must be a \(zz) — it dies wherever both are seen."
                    )
                }
            }
        }
        return nil
    }
}
