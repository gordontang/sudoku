/// Single-digit patterns built on strong links (conjugate pairs: units with
/// exactly two candidates for a digit): the turbot-fish family, empty
/// rectangles, X-chains, and coloring.
extension Techniques {

    /// Conjugate pairs for a digit: (cellA, cellB, unit index).
    static func strongLinks(_ grid: Grid, _ cands: [CandidateSet], digit d: UInt8) -> [(a: Int, b: Int, unit: Int)] {
        var links: [(a: Int, b: Int, unit: Int)] = []
        for (u, unit) in Grid.units.enumerated() {
            var pos: [Int] = []
            for i in unit where grid.cells[i] == 0 && cands[i].contains(digit: d) {
                pos.append(i)
                if pos.count > 2 { break }
            }
            if pos.count == 2 { links.append((pos[0], pos[1], u)) }
        }
        return links
    }

    /// Two strong links joined by a weak link: whichever way the weak end
    /// resolves, one free end holds the digit — it dies wherever both free
    /// ends are seen. Skyscraper (two parallel line links), 2-String Kite
    /// (row + column links meeting in a box), Turbot Fish (a box link).
    static func turbotFamily(_ grid: Grid, _ cands: [CandidateSet]) -> Deduction? {
        for d: UInt8 in 1...9 {
            let links = strongLinks(grid, cands, digit: d)
            guard links.count >= 2 else { continue }
            for a in 0..<links.count {
                for b in (a + 1)..<links.count {
                    let (a1, a2, ua) = links[a]
                    let (b1, b2, ub) = links[b]
                    let cells: Set<Int> = [a1, a2, b1, b2]
                    guard cells.count == 4 else { continue }
                    for (e1, f1) in [(a1, a2), (a2, a1)] {
                        for (e2, f2) in [(b1, b2), (b2, b1)] {
                            guard sees[e1][e2] else { continue }
                            var elims: [(Int, CandidateSet)] = []
                            for i in 0..<81 where !cells.contains(i) && grid.cells[i] == 0
                                && cands[i].contains(digit: d) && sees[i][f1] && sees[i][f2] {
                                elims.append((i, CandidateSet(digit: d)))
                            }
                            guard !elims.isEmpty else { continue }
                            let technique: Technique
                            if ua < 18 && ub < 18 {
                                technique = (ua < 9) == (ub < 9) ? .skyscraper : .twoStringKite
                            } else {
                                technique = .turbotFish
                            }
                            let refs = { (c: Int) in CandidateRef(cell: c, digit: d) }
                            return Deduction(
                                kind: .eliminate(elims),
                                technique: technique,
                                patternCells: cells.sorted(),
                                keyDigits: CandidateSet(digit: d),
                                patternCandidates: [refs(f1), refs(f2)],
                                secondaryCandidates: [refs(e1), refs(e2)],
                                links: [
                                    ChainLink(from: refs(f1), to: refs(e1), isStrong: true),
                                    ChainLink(from: refs(e1), to: refs(e2), isStrong: false),
                                    ChainLink(from: refs(e2), to: refs(f2), isStrong: true),
                                ],
                                explanation: "\(technique.displayName) on \(d): the two strong links guarantee \(cellName(f1)) or \(cellName(f2)) is a \(d), so \(d) dies wherever both are seen."
                            )
                        }
                    }
                }
            }
        }
        return nil
    }

    /// A box whose candidates for a digit sit on one row+column cross,
    /// combined with a line strong link pointing at the cross: the cell
    /// closing the rectangle can't hold the digit.
    static func emptyRectangle(_ grid: Grid, _ cands: [CandidateSet]) -> Deduction? {
        for d: UInt8 in 1...9 {
            let lineLinks = strongLinks(grid, cands, digit: d).filter { $0.unit < 18 }
            guard !lineLinks.isEmpty else { continue }
            for b in 0..<9 {
                let boxCells = Grid.units[18 + b]
                let pos = boxCells.filter { grid.cells[$0] == 0 && cands[$0].contains(digit: d) }
                guard pos.count >= 3 else { continue }
                for erRow in Set(pos.map { $0 / 9 }).sorted() {
                    for erCol in Set(pos.map { $0 % 9 }).sorted() {
                        guard pos.allSatisfy({ $0 / 9 == erRow || $0 % 9 == erCol }) else { continue }
                        // Both arms of the cross must be inhabited.
                        guard pos.contains(where: { $0 / 9 == erRow && $0 % 9 != erCol }),
                              pos.contains(where: { $0 % 9 == erCol && $0 / 9 != erRow })
                        else { continue }
                        for (p, q, u) in lineLinks {
                            for (s, t) in [(p, q), (q, p)] {
                                guard Grid.box(of: s) != b, Grid.box(of: t) != b else { continue }
                                let target: Int
                                if u < 9 {
                                    guard s % 9 == erCol else { continue }
                                    target = erRow * 9 + (t % 9)
                                } else {
                                    guard s / 9 == erRow else { continue }
                                    target = (t / 9) * 9 + erCol
                                }
                                guard target != t, Grid.box(of: target) != b,
                                      grid.cells[target] == 0, cands[target].contains(digit: d)
                                else { continue }
                                return Deduction(
                                    kind: .eliminate([(target, CandidateSet(digit: d))]),
                                    technique: .emptyRectangle,
                                    patternCells: (pos + [s, t]).sorted(),
                                    unit: 18 + b,
                                    keyDigits: CandidateSet(digit: d),
                                    patternCandidates: pos.map { CandidateRef(cell: $0, digit: d) },
                                    secondaryCandidates: [s, t].map { CandidateRef(cell: $0, digit: d) },
                                    explanation: "Empty Rectangle on \(d): Box \(b + 1) confines \(d) to one row and column; with the strong link \(cellName(s))–\(cellName(t)), \(cellName(target)) can't be a \(d)."
                                )
                            }
                        }
                    }
                }
            }
        }
        return nil
    }

    /// Alternating strong/weak chain on one digit, at least three strong
    /// links (the turbot family covers two). One end is true.
    static func xChain(_ grid: Grid, _ cands: [CandidateSet], maxLinks: Int = 7) -> Deduction? {
        for d: UInt8 in 1...9 {
            var nodes: [Int] = []
            for i in 0..<81 where grid.cells[i] == 0 && cands[i].contains(digit: d) {
                nodes.append(i)
            }
            guard nodes.count >= 6 else { continue }
            var strongNbrs: [Int: Set<Int>] = [:]
            for (p, q, _) in strongLinks(grid, cands, digit: d) {
                strongNbrs[p, default: []].insert(q)
                strongNbrs[q, default: []].insert(p)
            }
            guard !strongNbrs.isEmpty else { continue }

            var best: ([(Int, CandidateSet)], [Int])?

            func dfs(_ path: inout [Int], _ inPath: inout Set<Int>, _ needStrong: Bool, _ depth: Int) {
                guard best == nil, depth > 0 else { return }
                let last = path.last!
                let nbrs: [Int]
                if needStrong {
                    nbrs = (strongNbrs[last] ?? []).sorted()
                } else {
                    nbrs = nodes.filter { $0 != last && sees[last][$0] }
                }
                for nxt in nbrs {
                    guard !inPath.contains(nxt), best == nil else { continue }
                    path.append(nxt)
                    inPath.insert(nxt)
                    if needStrong && path.count >= 6 && path.count % 2 == 0 {
                        let a = path[0], z = nxt
                        var elims: [(Int, CandidateSet)] = []
                        for i in nodes where !inPath.contains(i) && sees[i][a] && sees[i][z] {
                            elims.append((i, CandidateSet(digit: d)))
                        }
                        if !elims.isEmpty {
                            best = (elims, path)
                        }
                    }
                    if best == nil {
                        dfs(&path, &inPath, !needStrong, depth - 1)
                    }
                    path.removeLast()
                    inPath.remove(nxt)
                    if best != nil { return }
                }
            }

            for start in nodes where strongNbrs[start] != nil {
                var path = [start]
                var inPath: Set<Int> = [start]
                dfs(&path, &inPath, true, maxLinks)
                if let (elims, chain) = best {
                    let refs = chain.map { CandidateRef(cell: $0, digit: d) }
                    var links: [ChainLink] = []
                    for k in 0..<(chain.count - 1) {
                        links.append(ChainLink(from: refs[k], to: refs[k + 1], isStrong: k % 2 == 0))
                    }
                    return Deduction(
                        kind: .eliminate(elims),
                        technique: .xChain,
                        patternCells: chain.sorted(),
                        keyDigits: CandidateSet(digit: d),
                        patternCandidates: stride(from: 0, to: refs.count, by: 2).map { refs[$0] },
                        secondaryCandidates: stride(from: 1, to: refs.count, by: 2).map { refs[$0] },
                        links: links,
                        explanation: "X-Chain on \(d): following the chain of strong links from \(cellName(chain.first!)) to \(cellName(chain.last!)), one end must be a \(d) — it dies wherever both are seen."
                    )
                }
            }
        }
        return nil
    }

    // MARK: - Coloring

    /// Connected components (≥3 cells) of the conjugate-pair graph, 2-colored.
    static func colorComponents(_ grid: Grid, _ cands: [CandidateSet], digit d: UInt8) -> [[Int: Int]] {
        var nbrs: [Int: Set<Int>] = [:]
        for (p, q, _) in strongLinks(grid, cands, digit: d) {
            nbrs[p, default: []].insert(q)
            nbrs[q, default: []].insert(p)
        }
        var seen = Set<Int>()
        var comps: [[Int: Int]] = []
        for start in nbrs.keys.sorted() where !seen.contains(start) {
            var colors: [Int: Int] = [start: 0]
            var queue = [start]
            seen.insert(start)
            while !queue.isEmpty {
                let cur = queue.removeFirst()
                for nxt in (nbrs[cur] ?? []).sorted() where colors[nxt] == nil {
                    colors[nxt] = 1 - colors[cur]!
                    seen.insert(nxt)
                    queue.append(nxt)
                }
            }
            if colors.count >= 3 { comps.append(colors) }
        }
        return comps
    }

    private static func colorRefs(_ colors: [Int: Int], _ d: UInt8) -> (a: [CandidateRef], b: [CandidateRef]) {
        let a = colors.filter { $0.value == 0 }.keys.sorted().map { CandidateRef(cell: $0, digit: d) }
        let b = colors.filter { $0.value == 1 }.keys.sorted().map { CandidateRef(cell: $0, digit: d) }
        return (a, b)
    }

    /// 2-color a digit's strong-link graph. Wrap: two same-color cells in one
    /// unit kill that whole color. Trap: an outside candidate seeing both
    /// colors dies.
    static func simpleColors(_ grid: Grid, _ cands: [CandidateSet]) -> Deduction? {
        for d: UInt8 in 1...9 {
            for colors in colorComponents(grid, cands, digit: d) {
                let side0 = colors.filter { $0.value == 0 }.keys.sorted()
                let side1 = colors.filter { $0.value == 1 }.keys.sorted()
                for cells in [side0, side1] {
                    var clash = false
                    outer: for x in 0..<cells.count {
                        for y in (x + 1)..<cells.count where sees[cells[x]][cells[y]] {
                            clash = true
                            break outer
                        }
                    }
                    if clash {
                        let (a, b) = colorRefs(colors, d)
                        return Deduction(
                            kind: .eliminate(cells.map { ($0, CandidateSet(digit: d)) }),
                            technique: .simpleColors,
                            patternCells: colors.keys.sorted(),
                            keyDigits: CandidateSet(digit: d),
                            patternCandidates: a,
                            secondaryCandidates: b,
                            explanation: "Simple Colors on \(d): two same-colored cells share a unit, so that whole color is false."
                        )
                    }
                }
                var elims: [(Int, CandidateSet)] = []
                for i in 0..<81 where grid.cells[i] == 0 && cands[i].contains(digit: d) && colors[i] == nil {
                    if side0.contains(where: { sees[i][$0] }) && side1.contains(where: { sees[i][$0] }) {
                        elims.append((i, CandidateSet(digit: d)))
                    }
                }
                if !elims.isEmpty {
                    let (a, b) = colorRefs(colors, d)
                    return Deduction(
                        kind: .eliminate(elims),
                        technique: .simpleColors,
                        patternCells: colors.keys.sorted(),
                        keyDigits: CandidateSet(digit: d),
                        patternCandidates: a,
                        secondaryCandidates: b,
                        explanation: "Simple Colors on \(d): one of the two colors is true, so a \(d) seeing both colors is false either way."
                    )
                }
            }
        }
        return nil
    }

    /// Coloring across two components: colors that clash constrain each
    /// other's opposites.
    static func multiColors(_ grid: Grid, _ cands: [CandidateSet]) -> Deduction? {
        for d: UInt8 in 1...9 {
            let comps = colorComponents(grid, cands, digit: d)
            guard comps.count >= 2 else { continue }
            for i1 in 0..<comps.count {
                for i2 in (i1 + 1)..<comps.count {
                    let c1 = comps[i1], c2 = comps[i2]
                    let sides1 = [c1.filter { $0.value == 0 }.keys.sorted(), c1.filter { $0.value == 1 }.keys.sorted()]
                    let sides2 = [c2.filter { $0.value == 0 }.keys.sorted(), c2.filter { $0.value == 1 }.keys.sorted()]
                    for s1 in 0...1 {
                        for s2 in 0...1 {
                            let aCells = sides1[s1], bCells = sides2[s2]
                            let touches = aCells.contains { a in bCells.contains { sees[a][$0] } }
                            guard touches else { continue }
                            // ¬(A ∧ B): the opposite colors can't both be false.
                            let oa = sides1[1 - s1], ob = sides2[1 - s2]
                            var elims: [(Int, CandidateSet)] = []
                            for i in 0..<81 where grid.cells[i] == 0 && cands[i].contains(digit: d)
                                && c1[i] == nil && c2[i] == nil {
                                if oa.contains(where: { sees[i][$0] }) && ob.contains(where: { sees[i][$0] }) {
                                    elims.append((i, CandidateSet(digit: d)))
                                }
                            }
                            if elims.isEmpty {
                                // A color seeing both colors of the other
                                // component is false entirely.
                                for x in aCells {
                                    if sides2[0].contains(where: { sees[x][$0] }) && sides2[1].contains(where: { sees[x][$0] }) {
                                        elims = aCells.map { ($0, CandidateSet(digit: d)) }
                                        break
                                    }
                                }
                            }
                            if !elims.isEmpty {
                                let pattern = (c1.keys.sorted() + c2.keys.sorted()).sorted()
                                return Deduction(
                                    kind: .eliminate(elims),
                                    technique: .multiColors,
                                    patternCells: pattern,
                                    keyDigits: CandidateSet(digit: d),
                                    patternCandidates: c1.keys.sorted().map { CandidateRef(cell: $0, digit: d) },
                                    secondaryCandidates: c2.keys.sorted().map { CandidateRef(cell: $0, digit: d) },
                                    explanation: "Multi-Colors on \(d): the two color clusters constrain each other — the marked \(d)s can't survive every outcome."
                                )
                            }
                        }
                    }
                }
            }
        }
        return nil
    }
}
