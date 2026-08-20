/// General Alternating Inference Chains over candidate nodes.
///
/// Strong link (¬v ⇒ w): the other digit of a bivalue cell, or the other
/// position of a digit with exactly two homes in a unit. Weak link (v ⇒ ¬w):
/// any other digit in the same cell, or the same digit anywhere in a shared
/// unit. A chain strong-weak-…-strong proves "start or end is true", so any
/// candidate weakly linked to both dies.
extension Techniques {

    static func aic(_ grid: Grid, _ cands: [CandidateSet], maxLinks: Int = 7, budget: Int = 250_000) -> Deduction? {
        // Node id: cell * 9 + (digit - 1).
        func id(_ cell: Int, _ d: UInt8) -> Int { cell * 9 + Int(d) - 1 }
        func cellOf(_ n: Int) -> Int { n / 9 }
        func digitOf(_ n: Int) -> UInt8 { UInt8(n % 9 + 1) }

        var exists = Array(repeating: false, count: 729)
        var nodes: [Int] = []
        for i in 0..<81 where grid.cells[i] == 0 {
            for d in cands[i].digits {
                exists[id(i, d)] = true
                nodes.append(id(i, d))
            }
        }
        var strongNbrs = Array(repeating: [Int](), count: 729)
        var weakNbrs = Array(repeating: [Int](), count: 729)
        for i in 0..<81 where grid.cells[i] == 0 {
            let ds = cands[i].digits
            for a in ds {
                for b in ds where a != b {
                    weakNbrs[id(i, a)].append(id(i, b))
                }
                if ds.count == 2 {
                    let other = ds[0] == a ? ds[1] : ds[0]
                    strongNbrs[id(i, a)].append(id(i, other))
                }
            }
        }
        for unit in Grid.units {
            for d: UInt8 in 1...9 {
                let pos = unit.filter { grid.cells[$0] == 0 && cands[$0].contains(digit: d) }
                for p in pos {
                    for q in pos where p != q {
                        weakNbrs[id(p, d)].append(id(q, d))
                    }
                }
                if pos.count == 2 {
                    strongNbrs[id(pos[0], d)].append(id(pos[1], d))
                    strongNbrs[id(pos[1], d)].append(id(pos[0], d))
                }
            }
        }
        for n in nodes {
            strongNbrs[n] = Array(Set(strongNbrs[n])).sorted()
            weakNbrs[n] = Array(Set(weakNbrs[n])).sorted()
        }

        func weaklyLinked(_ v: Int, _ w: Int) -> Bool {
            let (c1, d1) = (cellOf(v), digitOf(v))
            let (c2, d2) = (cellOf(w), digitOf(w))
            if c1 == c2 && d1 != d2 { return true }
            return d1 == d2 && sees[c1][c2]
        }

        var expansions = 0
        var best: ([(Int, CandidateSet)], [Int])?

        func endpointElims(_ v0: Int, _ vk: Int) -> [(Int, CandidateSet)] {
            var byCell: [Int: CandidateSet] = [:]
            for x in nodes where x != v0 && x != vk {
                if weaklyLinked(x, v0) && weaklyLinked(x, vk) {
                    byCell[cellOf(x), default: CandidateSet()].insert(digit: digitOf(x))
                }
            }
            return byCell.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
        }

        func dfs(_ path: inout [Int], _ inPath: inout Set<Int>, _ needStrong: Bool, _ linksLeft: Int) {
            guard best == nil, linksLeft > 0 else { return }
            let v = path.last!
            let nbrs = needStrong ? strongNbrs[v] : weakNbrs[v]
            for w in nbrs {
                if inPath.contains(w) || best != nil { continue }
                expansions += 1
                if expansions > budget { return }
                path.append(w)
                inPath.insert(w)
                if needStrong && path.count >= 4 && path.count % 2 == 0 {
                    let elims = endpointElims(path[0], w)
                    if !elims.isEmpty {
                        best = (elims, path)
                    }
                }
                if best == nil {
                    dfs(&path, &inPath, !needStrong, linksLeft - 1)
                }
                path.removeLast()
                inPath.remove(w)
            }
        }

        for depth in [3, 5, 7] where depth <= maxLinks {
            for v0 in nodes where !strongNbrs[v0].isEmpty {
                var path = [v0]
                var inPath: Set<Int> = [v0]
                dfs(&path, &inPath, true, depth)
                if let (elims, chain) = best {
                    let refs = chain.map { CandidateRef(cell: cellOf($0), digit: digitOf($0)) }
                    var links: [ChainLink] = []
                    for k in 0..<(refs.count - 1) {
                        links.append(ChainLink(from: refs[k], to: refs[k + 1], isStrong: k % 2 == 0))
                    }
                    var keyDigits = CandidateSet()
                    for r in refs { keyDigits.insert(digit: r.digit) }
                    let a = refs.first!, z = refs.last!
                    return Deduction(
                        kind: .eliminate(elims),
                        technique: .aic,
                        patternCells: Set(chain.map(cellOf)).sorted(),
                        keyDigits: keyDigits,
                        patternCandidates: stride(from: 0, to: refs.count, by: 2).map { refs[$0] },
                        secondaryCandidates: stride(from: 1, to: refs.count, by: 2).map { refs[$0] },
                        links: links,
                        reasoning: "Follow the chain from \(cellName(a.cell)) to \(cellName(z.cell)). Solid links mean \"if not this, then that\": the only other candidate in a cell, or the only other spot for a digit in a unit. Dashed links mean \"if this, then not that\": two candidates that can't both be true. Suppose \(cellName(a.cell)) is not a \(a.digit): each link forces the next step, and the chain ends with \(cellName(z.cell)) being a \(z.digit). So at least one end is true, and any candidate that would be knocked out by either end is impossible."
                    )
                }
                if expansions > budget { return nil }
            }
        }
        return nil
    }
}
