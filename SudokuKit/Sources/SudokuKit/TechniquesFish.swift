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
                        let baseNames = base.sorted().map { "\($0 + 1)" }.joined(separator: ", ")
                        return Deduction(
                            kind: .eliminate(elims),
                            technique: technique,
                            patternCells: corners,
                            keyDigits: CandidateSet(digit: d),
                            patternCandidates: corners.map { CandidateRef(cell: $0, digit: d) },
                            explanation: "\(technique.displayName) on \(d) in \(axis) \(baseNames): the digit is trapped in \(size) \(rowBased ? "columns" : "rows"), so it dies elsewhere in them."
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
                            return Deduction(
                                kind: .eliminate(elims),
                                technique: technique,
                                patternCells: (corners + fins).sorted(),
                                keyDigits: CandidateSet(digit: d),
                                patternCandidates: corners.map { CandidateRef(cell: $0, digit: d) },
                                secondaryCandidates: fins.sorted().map { CandidateRef(cell: $0, digit: d) },
                                explanation: "\(technique.displayName) on \(d): the fish's spare candidates (fins) all sit in Box \(finBox + 1), so the eliminations survive only there."
                            )
                        }
                    }
                }
            }
        }
        return nil
    }
}
