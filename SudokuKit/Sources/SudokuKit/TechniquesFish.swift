/// Fish: N base lines whose candidates for a digit are confined to N cover
/// lines eliminate the digit from the covers elsewhere. Size 2/3/4 =
/// X-Wing/Swordfish/Jellyfish; the finned variants allow extra base
/// candidates confined to one box, restricting eliminations to that box.
extension Techniques {

    private static func fishName(_ size: Int, finned: Bool) -> Technique {
        switch (size, finned) {
        case (2, false): .xWing
        case (3, false): .swordfish
        case (4, false): .jellyfish
        case (2, true): .finnedXWing
        case (3, true): .finnedSwordfish
        default: .finnedJellyfish
        }
    }

    static func basicFish(_ grid: Grid, _ cands: [CandidateSet], size: Int) -> Deduction? {
        for d: UInt8 in 1...9 {
            for rowBased in [true, false] {
                func index(_ line: Int, _ cross: Int) -> Int {
                    rowBased ? line * 9 + cross : cross * 9 + line
                }
                var lines: [(line: Int, crosses: [Int])] = []
                for line in 0..<9 {
                    let crosses = (0..<9).filter {
                        let i = index(line, $0)
                        return grid.cells[i] == 0 && cands[i].contains(digit: d)
                    }
                    if crosses.count >= 2 && crosses.count <= size {
                        lines.append((line, crosses))
                    }
                }
                guard lines.count >= size else { continue }
                for combo in combinations(of: lines, choose: size) {
                    var covers = Set<Int>()
                    for (_, crosses) in combo { covers.formUnion(crosses) }
                    guard covers.count == size else { continue }
                    let base = Set(combo.map { $0.line })
                    var elims: [(Int, CandidateSet)] = []
                    for other in 0..<9 where !base.contains(other) {
                        for c in covers.sorted() {
                            let i = index(other, c)
                            if grid.cells[i] == 0 && cands[i].contains(digit: d) {
                                elims.append((i, CandidateSet(digit: d)))
                            }
                        }
                    }
                    if !elims.isEmpty {
                        let corners = combo.flatMap { line, crosses in
                            crosses.map { index(line, $0) }
                        }.sorted()
                        let technique = fishName(size, finned: false)
                        let axis = rowBased ? "rows" : "columns"
                        let crossAxis = rowBased ? "columns" : "rows"
                        let baseNames = base.sorted().map { "\($0 + 1)" }.joined(separator: ", ")
                        let coverNames = covers.sorted().map { "\($0 + 1)" }.joined(separator: ", ")
                        return Deduction(
                            kind: .eliminate(elims),
                            technique: technique,
                            patternCells: corners,
                            keyDigits: CandidateSet(digit: d),
                            patternCandidates: corners.map { CandidateRef(cell: $0, digit: d) },
                            reasoning: "In \(axis) \(baseNames), the only places a \(d) can still go are all in \(crossAxis) \(coverNames). Each of those \(size) \(axis) needs its own \(d), and between them they will use up the \(d) in every one of those \(size) \(crossAxis). No other cell in those \(crossAxis) can be a \(d)."
                        )
                    }
                }
            }
        }
        return nil
    }

    static func finnedFish(_ grid: Grid, _ cands: [CandidateSet], size: Int) -> Deduction? {
        for d: UInt8 in 1...9 {
            for rowBased in [true, false] {
                func index(_ line: Int, _ cross: Int) -> Int {
                    rowBased ? line * 9 + cross : cross * 9 + line
                }
                var lines: [(line: Int, crosses: [Int])] = []
                for line in 0..<9 {
                    let crosses = (0..<9).filter {
                        let i = index(line, $0)
                        return grid.cells[i] == 0 && cands[i].contains(digit: d)
                    }
                    if crosses.count >= 2 && crosses.count <= size + 2 {
                        lines.append((line, crosses))
                    }
                }
                guard lines.count >= size else { continue }
                for combo in combinations(of: lines, choose: size) {
                    var unionSet = Set<Int>()
                    for (_, crosses) in combo { unionSet.formUnion(crosses) }
                    guard unionSet.count > size && unionSet.count <= size + 2 else { continue }
                    let base = Set(combo.map { $0.line })
                    let union = unionSet.sorted()
                    for covers in combinations(of: union, choose: size) {
                        let coverSet = Set(covers)
                        let fins = combo.flatMap { line, crosses in
                            crosses.filter { !coverSet.contains($0) }.map { index(line, $0) }
                        }
                        guard !fins.isEmpty else { continue }
                        let finBoxes = Set(fins.map(Grid.box(of:)))
                        guard finBoxes.count == 1, let finBox = finBoxes.first else { continue }
                        var elims: [(Int, CandidateSet)] = []
                        for other in 0..<9 where !base.contains(other) {
                            for c in covers {
                                let i = index(other, c)
                                if Grid.box(of: i) == finBox && grid.cells[i] == 0 && cands[i].contains(digit: d) {
                                    elims.append((i, CandidateSet(digit: d)))
                                }
                            }
                        }
                        if !elims.isEmpty {
                            let corners = combo.flatMap { line, crosses in
                                crosses.filter { coverSet.contains($0) }.map { index(line, $0) }
                            }.sorted()
                            let technique = fishName(size, finned: true)
                            let axis = rowBased ? "rows" : "columns"
                            let crossAxis = rowBased ? "columns" : "rows"
                            let baseNames = base.sorted().map { "\($0 + 1)" }.joined(separator: ", ")
                            let coverNames = covers.sorted().map { "\($0 + 1)" }.joined(separator: ", ")
                            let baseFish = fishName(size, finned: false).displayName
                            let article = baseFish.hasPrefix("X") ? "an" : "a"
                            let finWord = fins.count == 1 ? "the fin" : "the fins"
                            return Deduction(
                                kind: .eliminate(elims),
                                technique: technique,
                                patternCells: (corners + fins).sorted(),
                                keyDigits: CandidateSet(digit: d),
                                patternCandidates: corners.map { CandidateRef(cell: $0, digit: d) },
                                secondaryCandidates: fins.sorted().map { CandidateRef(cell: $0, digit: d) },
                                reasoning: "In \(axis) \(baseNames), the \(d)s almost make \(article) \(baseFish) on \(crossAxis) \(coverNames), except for the extra \(fins.count == 1 ? "candidate" : "candidates") at \(cellList(fins.sorted())) (\(finWord)). Either a fin is a \(d), or none is and the clean \(baseFish) holds. A \(d) inside Box \(finBox + 1) that sits in \(crossAxis) \(coverNames) is ruled out in both cases: it sees \(finWord), and it's in the fish's cover."
                            )
                        }
                    }
                }
            }
        }
        return nil
    }
}
