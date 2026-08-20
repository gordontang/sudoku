/// The in-app technique manual: plain-language explanations of every rung of
/// the solving ladder, each with an example board.
///
/// The content lives in the engine package (not the app) so that example
/// boards can be checked against the real technique finders: an example that
/// claims to show a Skyscraper is run through the Skyscraper finder, and the
/// highlights the app draws come from that deduction — the same cells,
/// candidates, and chain links the coach would draw on a live game.

// MARK: - Example boards

/// An illustrative board snippet: a few placed digits and pencil marks, just
/// enough to show a pattern's shape. Not a valid puzzle — only the cells that
/// matter are filled in.
///
/// Where an example names a `technique`, the engine's finder for that
/// technique is run on the snippet and its deduction supplies the highlights
/// (pattern cells and candidates, the alternate colour, eliminations, chain
/// links). Hand-set highlights are added on top, for examples the finders
/// don't cover (forcing chains) or to emphasise something extra.
public struct TechniqueExample: Sendable {
    public let values: [UInt8]
    public let marks: [Int: CandidateSet]
    /// The finder that should recognise this snippet, if any.
    public let technique: Technique?
    /// Cells forming the pattern (hand-set; unioned with the finder's).
    public let pattern: Set<Int>
    /// Cells losing candidates. When a `technique` is set, this is the
    /// expected answer, which the package tests check against the finder.
    public let eliminated: Set<Int>
    /// Digits to emphasise wherever they appear.
    public let keyDigits: CandidateSet
    /// Cells shown as trial (what-if) placements, purple like an Alt sheet.
    public let trials: Set<Int>
    /// Pencil marks drawn struck through — notes a trial has knocked out.
    public let struck: [Int: CandidateSet]
    /// Chain links to draw (hand-set; unioned with the finder's).
    public let links: [ChainLink]
    public let caption: String

    /// The finder's deduction for this snippet, computed once.
    public let deduction: Deduction?

    public init(
        values: String = String(repeating: "0", count: 81),
        marks: [Int: [UInt8]] = [:],
        technique: Technique? = nil,
        pattern: Set<Int> = [],
        eliminated: Set<Int> = [],
        keyDigits: [UInt8] = [],
        trials: Set<Int> = [],
        struck: [Int: [UInt8]] = [:],
        links: [ChainLink] = [],
        caption: String
    ) {
        self.values = values.map { UInt8(String($0)) ?? 0 }
        self.marks = marks.mapValues { CandidateSet(digits: $0) }
        self.technique = technique
        self.pattern = pattern
        self.eliminated = eliminated
        self.keyDigits = CandidateSet(digits: keyDigits)
        self.trials = trials
        self.struck = struck.mapValues { CandidateSet(digits: $0) }
        self.links = links
        self.caption = caption
        if let technique {
            let grid = Grid(cells: self.values)
            var cands = Array(repeating: CandidateSet(), count: 81)
            for (i, set) in self.marks { cands[i] = set }
            deduction = Techniques.finder(for: technique)(grid, cands)
        } else {
            deduction = nil
        }
    }

    // MARK: Resolved highlights (hand-set ∪ finder)

    /// Cells tinted as the pattern.
    public var patternCells: Set<Int> {
        pattern.union(deduction?.patternCells ?? [])
    }

    /// Cells tinted as losing candidates.
    public var eliminatedCells: Set<Int> {
        var cells = eliminated
        if case .eliminate(let elims)? = deduction?.kind {
            for (cell, _) in elims { cells.insert(cell) }
        }
        return cells
    }

    /// Candidate marks in the pattern's main colour.
    public var patternCandidates: Set<CandidateRef> {
        var refs = Set(deduction?.patternCandidates ?? [])
        if case .place(let cell, let digit)? = deduction?.kind {
            refs.insert(CandidateRef(cell: cell, digit: digit))
        }
        return refs
    }

    /// Candidate marks in the pattern's second colour (fins, colour B, the
    /// other polarity of a chain).
    public var alternateCandidates: Set<CandidateRef> {
        Set(deduction?.secondaryCandidates ?? [])
    }

    /// Candidate marks the pattern removes.
    public var eliminatedCandidates: Set<CandidateRef> {
        var refs = Set<CandidateRef>()
        if case .eliminate(let elims)? = deduction?.kind {
            for (cell, digits) in elims {
                for d in digits.digits { refs.insert(CandidateRef(cell: cell, digit: d)) }
            }
        }
        // Hand-set eliminations: the key digits in the marked cells.
        for cell in eliminated {
            for d in keyDigits.digits where marks[cell]?.contains(digit: d) == true {
                refs.insert(CandidateRef(cell: cell, digit: d))
            }
        }
        return refs
    }

    /// Chain links to draw.
    public var allLinks: [ChainLink] {
        links + (deduction?.links ?? [])
    }
}

// MARK: - Topics

public struct TechniqueTopic: Identifiable, Sendable {
    public let id: String
    public let name: String
    /// One line under the name in the list.
    public let tagline: String
    /// One plain sentence saying what the pattern is — the coach quotes it
    /// when it names a technique.
    public let summary: String
    public let description: String
    public let steps: [String]
    public let examples: [TechniqueExample]
    /// Engine techniques this page explains, so the coach and review can
    /// open the right page.
    public let techniques: [Technique]

    public init(
        name: String,
        tagline: String,
        summary: String,
        description: String,
        steps: [String] = [],
        examples: [TechniqueExample] = [],
        techniques: [Technique] = []
    ) {
        id = name
        self.name = name
        self.tagline = tagline
        self.summary = summary
        self.description = description
        self.steps = steps
        self.examples = examples
        self.techniques = techniques
    }
}

public struct TechniqueSection: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let topics: [TechniqueTopic]

    public init(_ title: String, _ topics: [TechniqueTopic]) {
        id = title
        self.title = title
        self.topics = topics
    }
}

// MARK: - Finder lookup

extension Techniques {
    /// The finder that recognises a technique, for running one technique in
    /// isolation (the guide's example boards; tests).
    static func finder(for technique: Technique, givens: Grid? = nil) -> (Grid, [CandidateSet]) -> Deduction? {
        switch technique {
        case .fullHouse: fullHouse
        case .nakedSingle: nakedSingle
        case .hiddenSingle: hiddenSingle
        case .lockedCandidates: lockedCandidates
        case .lockedPair, .nakedPair: { nakedSubset($0, $1, size: 2) }
        case .hiddenPair: { hiddenSubset($0, $1, size: 2) }
        case .lockedTriple, .nakedTriple: { nakedSubset($0, $1, size: 3) }
        case .hiddenTriple: { hiddenSubset($0, $1, size: 3) }
        case .nakedQuad: { nakedSubset($0, $1, size: 4) }
        case .hiddenQuad: { hiddenSubset($0, $1, size: 4) }
        case .xWing: { basicFish($0, $1, size: 2) }
        case .swordfish: { basicFish($0, $1, size: 3) }
        case .jellyfish: { basicFish($0, $1, size: 4) }
        case .finnedXWing: { finnedFish($0, $1, size: 2) }
        case .finnedSwordfish: { finnedFish($0, $1, size: 3) }
        case .finnedJellyfish: { finnedFish($0, $1, size: 4) }
        case .skyscraper, .twoStringKite, .turbotFish: turbotFamily
        case .emptyRectangle: emptyRectangle
        case .xyWing: xyWing
        case .xyzWing: xyzWing
        case .wWing: wWing
        case .remotePair: remotePair
        case .bugPlusOne: bugPlusOne
        case .uniqueRectangle: uniqueRectangle
        case .hiddenRectangle: hiddenRectangle
        case .avoidableRectangle: { avoidableRectangle($0, $1, givens: givens) }
        case .simpleColors: simpleColors
        case .multiColors: multiColors
        case .xChain: { xChain($0, $1) }
        case .xyChain: { xyChain($0, $1) }
        case .sueDeCoq: sueDeCoq
        case .alsXZ: alsXZ
        case .aic: { aic($0, $1) }
        }
    }
}

// MARK: - Content

/// Row/column (1-based) to cell index — keeps the example boards readable.
private func rc(_ row: Int, _ col: Int) -> Int { (row - 1) * 9 + (col - 1) }

public enum TechniqueGuide {
    public static let sections: [TechniqueSection] = [
        TechniqueSection("Getting Unstuck", [strategy]),
        TechniqueSection("Basics", [fullHouse, nakedSingle, hiddenSingle]),
        TechniqueSection("Intermediate", [lockedCandidates, nakedPair, hiddenPair, nakedTriple, hiddenTriple, quadruples]),
        TechniqueSection("Advanced", [xWing, skyscraper, twoStringKite, emptyRectangle, xyWing]),
        TechniqueSection("Master Patterns", [
            biggerFish, finnedFish, xyzWing, wWing, remotePair,
            coloring, xChains, uniqueness, alsFamily, aicTopic,
        ]),
        TechniqueSection("Last Resort", [forcingChains]),
    ]

    /// Every topic in reading order — what Previous/Next step through.
    public static let allTopics: [TechniqueTopic] = sections.flatMap(\.topics)

    /// The page that explains an engine technique.
    public static func topic(for technique: Technique) -> TechniqueTopic? {
        allTopics.first { $0.techniques.contains(technique) }
    }

    // MARK: Getting unstuck

    public static let strategy = TechniqueTopic(
        name: "Working a Hard Puzzle",
        tagline: "What to try, and in what order, when nothing jumps out",
        summary: "A routine for hard puzzles: fill in your pencil marks, sweep for singles, then hunt for eliminations from cheapest to dearest.",
        description: """
        Hard puzzles are built so that plain scanning stops working at some \
        point. That's not you getting worse — it's the puzzle asking for \
        the next tool. When you stall, work through this list from the top. \
        Each step is quicker than the one after it, and one good elimination \
        often sets off a run of easy placements.

        A quick word on words: your "candidates" are the digits that can \
        still go in a cell — the little pencil marks. Nearly everything past \
        the basics works on candidates rather than on placed digits, so \
        keeping them complete and honest is the price of admission.
        """,
        steps: [
            "Fill in every candidate. Long-press the Pencil button and each empty cell shows exactly the digits it can still take. Advanced patterns only work if your notes are complete and accurate.",
            "Sweep for singles: a cell with only one candidate left, or a digit with only one place left in a row, column, or box.",
            "Pick a digit and study it on its own. Select it (or tap one of its placements) to light up every row, column, and box it already covers, plus every cell where it's still pencilled in. Do this for 1 through 9. (The Covered Cells setting chooses whether coverage comes from every placement or just the selected one.)",
            "Hunt for eliminations, cheapest first: Locked Candidates, then pairs, triples, and quadruples, then X-Wings and the other single-digit patterns, then wings. Every time you erase a candidate, sweep for singles again.",
            "Still stuck, and your notes are honest? Ask the Coach. It tells you the cheapest technique that works right now, and reveals more only when you ask: first the name, then where to look, then the pattern itself.",
            "If even the Coach says no pattern applies, you're in chain territory. Add an Alt and test one candidate of a two-candidate cell — see Forcing Chains.",
        ]
    )

    // MARK: Basics

    public static let fullHouse = TechniqueTopic(
        name: "Full House",
        tagline: "The last empty cell in a row, column, or box",
        summary: "A row, column, or box with only one empty cell left — the one missing digit goes there.",
        description: """
        When a row, column, or box has eight of its nine digits placed, \
        there's exactly one gap and exactly one digit that hasn't been used. \
        That digit fills the gap. It's the friendliest move in sudoku, and \
        worth looking for on purpose: every digit you place might complete \
        a row, column, or box somewhere else.
        """,
        steps: [
            "After each placement, glance at the row, the column, and the box you just touched.",
            "Is any of them down to a single empty cell? Work out which digit is missing and place it.",
        ],
        examples: [TechniqueExample(
            values: String(repeating: "0", count: 27)
                + "000123000" + "000406000" + "000789000"
                + String(repeating: "0", count: 27),
            marks: [rc(5, 5): [5]],
            technique: .fullHouse,
            keyDigits: [5],
            caption: "The middle box has every digit except 5, so its last empty cell must be the 5."
        )],
        techniques: [.fullHouse]
    )

    public static let nakedSingle = TechniqueTopic(
        name: "Naked Single",
        tagline: "A cell with only one candidate left",
        summary: "A cell where only one digit can still go, because its row, column, and box between them already contain the other eight.",
        description: """
        Sometimes a cell is forced even though nothing around it looks \
        close to finished. Its row rules out a few digits, its column a few \
        more, its box the rest — and only one digit survives. With full \
        pencil marks these cells are easy to spot: they show a single note. \
        Place it straight away.
        """,
        steps: [
            "Look for cells showing exactly one pencil mark.",
            "Place that digit. Erasing it from the neighbours often creates the next naked single.",
        ],
        examples: [TechniqueExample(
            values: "000050000000060000000000000000700000123000400000008000000000000000000000000000000",
            marks: [rc(5, 5): [9]],
            technique: .nakedSingle,
            keyDigits: [9],
            caption: "Nothing near the centre cell is close to done. But its row rules out 1, 2, 3 and 4, its column 5 and 6, and its box 7 and 8. Only 9 is left."
        )],
        techniques: [.nakedSingle]
    )

    public static let hiddenSingle = TechniqueTopic(
        name: "Hidden Single",
        tagline: "A digit with only one place left in a row, column, or box",
        summary: "A digit that fits in only one cell of a row, column, or box — so that cell must take it, whatever else it could have been.",
        description: """
        A cell can have several candidates and still be forced. If a digit \
        can go in only one cell of a row, column, or box, that cell has to \
        take it — the other candidates in the cell are just noise. This is \
        the cross-hatching you already do on easy puzzles; on hard ones it \
        hides among busy pencil marks, so it pays to look for it deliberately.
        """,
        steps: [
            "Pick a digit and a box. Select one of the digit's placements to light up the rows and columns it already covers.",
            "If only one cell of the box escapes that coverage, the digit lives there — no matter what other candidates that cell shows.",
            "Do this for each digit, box by box, then try the same idea on rows and columns.",
        ],
        examples: [TechniqueExample(
            values: "000000000000005000000000050000000000050000000000000000005000000000000000000000000",
            marks: [rc(1, 1): [5]],
            technique: .hiddenSingle,
            eliminated: [1, 2, 9, 10, 11, 18, 19, 20],
            keyDigits: [5],
            caption: "The 5s in rows 2 and 3 and in columns 2 and 3 cover every cell of the top-left box except one. So the box's 5 has to go in the corner."
        )],
        techniques: [.hiddenSingle]
    )

    // MARK: Intermediate

    public static let lockedCandidates = TechniqueTopic(
        name: "Locked Candidates",
        tagline: "A box pins a digit to one row or column",
        summary: "All of a digit's candidates in a box sit in one row or column, so the digit can't appear elsewhere in that row or column.",
        description: """
        Look at where a digit can still go inside one box. If all of those \
        spots line up in a single row (or column), then the box is going to \
        take its copy of that digit from that row — and the row only gets \
        one. So the digit can be erased from the rest of that row, outside \
        the box.

        It works the other way round too: if a row can only fit a digit \
        inside one box, that box's copy is spoken for, and the digit can be \
        erased from the rest of the box.
        """,
        steps: [
            "For each box and each digit, look at where the digit's pencil marks sit.",
            "Are they all in one row or one column? Erase that digit from the rest of that line, outside the box.",
            "Then look for new singles — this often creates one.",
        ],
        examples: [TechniqueExample(
            values: "001000000080000000503000000000000000000000000000000000000000000000000000000000000",
            marks: [
                rc(1, 1): [2, 7], rc(1, 2): [7, 9],
                rc(2, 1): [2, 9], rc(2, 3): [4, 6], rc(3, 2): [4, 6],
                rc(1, 5): [6, 7], rc(1, 8): [7, 8],
            ],
            technique: .lockedCandidates,
            eliminated: [rc(1, 5), rc(1, 8)],
            keyDigits: [7],
            caption: "In the top-left box, 7 can only go in the first row. Wherever it lands, that's the row's 7 — so erase 7 from the rest of the row."
        )],
        techniques: [.lockedCandidates]
    )

    public static let nakedPair = TechniqueTopic(
        name: "Naked Pair",
        tagline: "Two cells that share the same two candidates",
        summary: "Two cells in one row, column, or box that both show exactly the same two candidates — those two digits are used up, so no other cell there can take either.",
        description: """
        Find two cells in the same row, column, or box that each show \
        exactly the same two candidates — say 4 and 9. You don't know which \
        cell gets the 4 and which the 9, but between them they take both. \
        That means no other cell in that row, column, or box can be a 4 or a \
        9. Erase them.

        If the two cells also happen to share a box (or a line), the pair is \
        "locked": erase both digits from the rest of the row *and* the rest \
        of the box in one go.
        """,
        steps: [
            "Look for two cells in the same row, column, or box showing the identical two pencil marks.",
            "Erase those two digits from every other cell in that row, column, or box.",
            "The slimmed-down cells often turn into singles.",
        ],
        examples: [TechniqueExample(
            values: "000000000000000000010368070000000000000000000000000000000000000000000000000000000",
            marks: [
                rc(3, 1): [4, 5, 9],
                rc(3, 3): [4, 9],
                rc(3, 7): [4, 9],
                rc(3, 9): [2, 4, 9],
            ],
            technique: .nakedPair,
            eliminated: [rc(3, 1), rc(3, 9)],
            keyDigits: [4, 9],
            caption: "Two cells in row 3 both show just 4 and 9. Between them they take both digits, so 4 and 9 come off the row's other cells — leaving a lone 5 and a lone 2."
        )],
        techniques: [.nakedPair, .lockedPair]
    )

    public static let hiddenPair = TechniqueTopic(
        name: "Hidden Pair",
        tagline: "Two digits that only fit in the same two cells",
        summary: "Two digits that can each go in only the same two cells of a row, column, or box — those cells must hold that pair, so their other candidates go.",
        description: """
        This is the naked pair seen from the other side. Instead of two \
        cells with the same two candidates, look for two *digits* that can \
        each go in only the same two cells of a row, column, or box. Those \
        two cells have to hold those two digits — so any other candidates \
        in them are noise and can be erased. It's harder to spot than a \
        naked pair because the two cells usually look busy.
        """,
        steps: [
            "Go digit by digit through a row, column, or box and note which cells each digit could go in. Selecting a digit lights up its remaining spots.",
            "Found two digits that share the same two cells? Erase every other candidate from those two cells.",
        ],
        examples: [TechniqueExample(
            values: "000000000000000000000000000000000000000000000000000000100046000000000000000000000",
            marks: [
                rc(7, 2): [2, 5, 7],
                rc(7, 3): [5, 8],
                rc(7, 4): [3, 5, 8],
                rc(7, 7): [2, 7, 8],
                rc(7, 8): [8, 9],
                rc(7, 9): [3, 9],
            ],
            technique: .hiddenPair,
            eliminated: [rc(7, 2), rc(7, 7)],
            keyDigits: [2, 7],
            caption: "In row 7, both 2 and 7 can only go in the same two cells. Those cells belong to the pair, so their other notes (5 and 8) can be erased."
        )],
        techniques: [.hiddenPair]
    )

    public static let nakedTriple = TechniqueTopic(
        name: "Naked Triple",
        tagline: "Three cells that share three digits between them",
        summary: "Three cells in one row, column, or box whose candidates add up to only three digits — those digits are used up, so no other cell there can take them.",
        description: """
        A naked pair, one size up. Find three cells in the same row, column, \
        or box whose candidates, put together, come to only three digits. \
        Those three cells will use up those three digits, so erase them from \
        every other cell in that row, column, or box.

        The cells don't each need all three digits. Cells showing {2, 6}, \
        {2, 9}, and {6, 9} make a perfectly good triple on 2, 6, and 9. \
        And if the three cells also share a box, the triple is locked: clear \
        the rest of the line and the rest of the box in one step.
        """,
        steps: [
            "In a row, column, or box with several two- and three-candidate cells, ask whether any three of them add up to just three digits.",
            "Erase those digits from the rest of the row, column, or box.",
        ],
        examples: [TechniqueExample(
            values: "000000000000000000000000000000000000000057080000000000000000000000000000000000000",
            marks: [
                rc(5, 1): [2, 6], rc(5, 4): [2, 9], rc(5, 7): [6, 9],
                rc(5, 2): [1, 2, 4, 6], rc(5, 3): [1, 3, 4, 6], rc(5, 9): [1, 3, 4, 9],
            ],
            technique: .nakedTriple,
            eliminated: [rc(5, 2), rc(5, 3), rc(5, 9)],
            keyDigits: [2, 6, 9],
            caption: "In row 5, three cells hold only 2, 6 and 9 between them: {2,6}, {2,9} and {6,9}. Those three digits are spoken for, so they come off the row's other cells."
        )],
        techniques: [.nakedTriple, .lockedTriple]
    )

    public static let hiddenTriple = TechniqueTopic(
        name: "Hidden Triple",
        tagline: "Three digits that only fit in the same three cells",
        summary: "Three digits that can each go only within the same three cells of a row, column, or box — those cells belong to the trio, so everything else in them goes.",
        description: """
        Like the hidden pair, but with three digits: if three digits can \
        each go only within the same three cells of a row, column, or box, \
        those cells belong to that trio and every other candidate in them \
        can be erased. Each digit just has to stay inside the three cells — \
        it doesn't have to appear in all of them.

        This is the hardest of the intermediate patterns to see, because the \
        cells look busy and nothing about them stands out. Hunt where the \
        pencil marks are thickest.
        """,
        steps: [
            "Work one digit at a time. In each row, column, or box, note the digits that can go in three or fewer cells.",
            "Three digits that share the same three cells? Erase everything else from those cells.",
        ],
        examples: [TechniqueExample(
            marks: [
                rc(3, 1): [1, 2, 7, 8],
                rc(3, 2): [2, 3, 7, 8],
                rc(3, 3): [1, 3, 7, 8],
                rc(3, 4): [4, 5, 6],
                rc(3, 5): [4, 6, 9],
                rc(3, 6): [5, 9],
                rc(3, 7): [6, 7, 9],
                rc(3, 8): [4, 8, 9],
                rc(3, 9): [5, 6, 7],
            ],
            technique: .hiddenTriple,
            eliminated: [rc(3, 1), rc(3, 2), rc(3, 3)],
            keyDigits: [1, 2, 3],
            caption: "In row 3, the digits 1, 2 and 3 can only go in the first three cells. Those cells belong to the trio, so the 7s and 8s cluttering them can be erased."
        )],
        techniques: [.hiddenTriple]
    )

    public static let quadruples = TechniqueTopic(
        name: "Quadruples",
        tagline: "Pairs and triples, one size bigger",
        summary: "Four cells sharing only four digits (naked), or four digits confined to four cells (hidden) — the same idea as pairs and triples, one size up.",
        description: """
        Both subset patterns stretch to four. Four cells whose candidates \
        add up to only four digits form a naked quadruple: erase those \
        digits from the rest of the row, column, or box. Four digits that \
        can only go in the same four cells form a hidden quadruple: erase \
        everything else from those cells.

        They're rare, and there's a handy shortcut. In a row, column, or \
        box, a naked quadruple always comes paired with a hidden set in the \
        remaining cells — so whichever half is smaller is the one to look \
        for.
        """,
        steps: [
            "Look in rows, columns, and boxes with few placed digits — quadruples need room.",
            "Four cells whose candidates add up to four digits: erase those digits from the rest of the row, column, or box.",
            "Four digits that only fit in four cells: erase the other candidates from those cells.",
        ],
        examples: [TechniqueExample(
            values: "000000000000000000060000000000000000000000000000000000000000000000000000000000000",
            marks: [
                rc(1, 1): [1, 3], rc(1, 2): [3, 5], rc(2, 1): [5, 7], rc(2, 2): [1, 7],
                rc(1, 3): [1, 3, 8, 9], rc(2, 3): [2, 4, 9], rc(3, 1): [2, 5, 7, 8], rc(3, 3): [4, 8, 9],
            ],
            technique: .nakedQuad,
            eliminated: [rc(1, 3), rc(3, 1)],
            keyDigits: [1, 3, 5, 7],
            caption: "In the top-left box, four cells hold only 1, 3, 5 and 7 between them. Those four digits are used up, so they come off the box's other cells."
        )],
        techniques: [.nakedQuad, .hiddenQuad]
    )

    // MARK: Advanced

    public static let xWing = TechniqueTopic(
        name: "X-Wing",
        tagline: "A rectangle that traps one digit",
        summary: "One digit has only two places in each of two rows, and those places line up in the same two columns — so the digit can be erased from those columns everywhere else.",
        description: """
        Pick a digit. Find two rows where it can go in only two cells each — \
        and the same two columns in both rows, so the four cells make a \
        rectangle. Each of those rows needs the digit, and the two copies \
        can't share a column, so they must sit on opposite corners. Either \
        way, both columns get their copy of the digit from these two rows. \
        So the digit can be erased from those two columns everywhere else.

        The same thing works with rows and columns swapped.
        """,
        steps: [
            "Select a digit so its remaining spots light up, then go row by row.",
            "Two rows where the digit fits in only the same two columns form the rectangle.",
            "Erase the digit from those two columns, outside the two rows.",
        ],
        examples: [TechniqueExample(
            marks: [
                rc(2, 3): [3], rc(2, 7): [3],
                rc(8, 3): [3], rc(8, 7): [3],
                rc(4, 3): [3, 8],
                rc(6, 7): [3, 4],
            ],
            technique: .xWing,
            eliminated: [rc(4, 3), rc(6, 7)],
            keyDigits: [3],
            caption: "Rows 2 and 8 can each take a 3 in only these two columns. The two 3s must sit on opposite corners, so both columns are covered either way — the other 3s in those columns go."
        )],
        techniques: [.xWing]
    )

    public static let skyscraper = TechniqueTopic(
        name: "Skyscraper",
        tagline: "Two towers of one digit on a shared base",
        summary: "One digit has only two places in each of two rows, and one place from each shares a column — so at least one of the two other places must be the digit.",
        description: """
        This is the first pattern built from what solvers call a strong \
        link: when a digit has only two places left in a row, column, or \
        box, those two spots are tied together — if one of them isn't the \
        digit, the other must be.

        Find a digit with exactly two spots in each of two rows, where one \
        spot from each row sits in the same column. Picture two towers \
        standing on a shared base: the base cells can't both be the digit \
        (they share a column), so at least one tower has its digit up on \
        the roof. Any cell that can see both roofs can't be that digit.

        Works just the same with columns and rows swapped.
        """,
        steps: [
            "Select a digit to light up where it can still go.",
            "Look for two rows with exactly two spots each that share one column. The shared column is the base; the other two spots are the roofs.",
            "Erase the digit from any cell that sees both roofs — same row or column as one, and same box as the other.",
        ],
        examples: [TechniqueExample(
            marks: [
                rc(2, 2): [4, 9], rc(2, 4): [4, 6],
                rc(6, 2): [1, 4], rc(6, 6): [3, 4],
                rc(5, 4): [4, 7], rc(1, 6): [4, 8],
            ],
            technique: .skyscraper,
            eliminated: [rc(1, 6), rc(5, 4)],
            keyDigits: [4],
            caption: "Rows 2 and 6 each have just two spots for a 4, and both use column 2. Those two base cells can't both be 4, so one of the roofs is — and the red cells can see both roofs."
        )],
        techniques: [.skyscraper]
    )

    public static let twoStringKite = TechniqueTopic(
        name: "2-String Kite & Turbot Fish",
        tagline: "A row link and a column link tied together in a box",
        summary: "One digit has only two places in a row and only two in a column, with one end of each in the same box — so a cell that sees the other two ends can't be the digit.",
        description: """
        Another two-link pattern. Take a digit with exactly two spots in a \
        row and exactly two in a column, where one end of each sits in the \
        same box. Those two box ends can't both be the digit. Follow the \
        logic outward: if one box end is out, its far end must be the digit \
        — so the two far ends can't both be empty. The cell where the far \
        ends' row and column cross can't be the digit.

        Versions of this that use a box's own two spots as one of the links \
        are called Turbot Fish. The reasoning is identical.
        """,
        steps: [
            "Look for digits with exactly two spots left in a row, column, or box — these strong links are the raw material for every chain pattern.",
            "Find a row link and a column link whose near ends share a box.",
            "Erase the digit from the cell where the two far ends' row and column cross.",
        ],
        examples: [TechniqueExample(
            marks: [
                rc(3, 3): [2, 7], rc(3, 8): [5, 7],
                rc(1, 1): [3, 7], rc(7, 1): [7, 8],
                rc(7, 8): [4, 7],
                rc(7, 5): [7, 9], rc(9, 8): [1, 7],
            ],
            technique: .twoStringKite,
            eliminated: [rc(7, 8)],
            keyDigits: [7],
            caption: "Row 3 has two spots for a 7, and so does column 1; one end of each is in the top-left box. Those two can't both be 7, so one of the far ends is — and the red cell sees both far ends."
        )],
        techniques: [.twoStringKite, .turbotFish]
    )

    public static let emptyRectangle = TechniqueTopic(
        name: "Empty Rectangle",
        tagline: "A box whose candidates for a digit form a cross",
        summary: "In one box, a digit's candidates all lie on one row and one column; paired with a two-spot line elsewhere, that rules the digit out of one specific cell.",
        description: """
        Look at one digit inside one box. If every place it can go lies on \
        a single row or a single column of that box — a cross shape — then \
        wherever the digit lands, it covers one arm of the cross: that row \
        or that column.

        Now find a row or column outside the box where the digit has only \
        two spots, with one of them lined up on the cross's column. If that \
        spot is the digit, it blocks the cross's column, so the box's digit \
        must be on the cross's row. If it isn't, the link's other spot is \
        the digit. Either way, the cell where the link's other spot meets \
        the cross's row can't be the digit.
        """,
        steps: [
            "For each box and digit, check whether the candidates collapse onto one row plus one column.",
            "Find a two-spot row or column for the digit with one end lined up on the cross's column (or row).",
            "The cell where the link's other end meets the cross's row (or column) loses the digit.",
        ],
        examples: [TechniqueExample(
            marks: [
                rc(5, 4): [2, 5], rc(5, 6): [5, 8], rc(4, 5): [3, 5], rc(6, 5): [5, 7],
                rc(8, 5): [5, 6], rc(8, 1): [5, 9],
                rc(5, 1): [4, 5],
            ],
            technique: .emptyRectangle,
            eliminated: [rc(5, 1)],
            keyDigits: [5],
            caption: "In the middle box, every 5 sits on row 5 or column 5. Row 8 has just two spots for a 5, one of them in column 5. If that one is the 5, the box's 5 must be on row 5; if not, the other spot is. Both cases rule out the red cell."
        )],
        techniques: [.emptyRectangle]
    )

    public static let xyWing = TechniqueTopic(
        name: "XY-Wing",
        tagline: "Three two-candidate cells, one shared victim",
        summary: "A cell with two candidates sees two other two-candidate cells that each share one of its digits and one common third digit — one wing must end up as that third digit.",
        description: """
        Start with a cell holding just two candidates, say 2 and 7 — call it \
        the pivot. Look for two more two-candidate cells that the pivot can \
        see: one holding 2 and some third digit, one holding 7 and the same \
        third digit. Say that third digit is 5.

        If the pivot is 2, the first wing loses its 2 and becomes 5. If the \
        pivot is 7, the second wing becomes 5. One way or the other, one of \
        the wings ends up as 5. So any cell that can see both wings can't \
        be a 5.

        Two-candidate cells are the raw material here — hunt for them first.
        """,
        steps: [
            "List the cells with exactly two candidates.",
            "Find a pivot {X, Y} that sees a wing {X, Z} and a wing {Y, Z}.",
            "Erase Z from every cell that sees both wings.",
        ],
        examples: [TechniqueExample(
            marks: [
                rc(5, 5): [2, 7],
                rc(5, 2): [2, 5],
                rc(2, 5): [5, 7],
                rc(2, 2): [5, 9],
            ],
            technique: .xyWing,
            eliminated: [rc(2, 2)],
            keyDigits: [5],
            caption: "The pivot {2,7} sees a wing {2,5} and a wing {5,7}. If the pivot is 2, the left wing is 5; if it's 7, the top wing is 5. Either way a 5 lands where the red cell can see it."
        )],
        techniques: [.xyWing]
    )

    // MARK: Master patterns

    public static let biggerFish = TechniqueTopic(
        name: "Swordfish & Jellyfish",
        tagline: "The X-Wing, one and two sizes up",
        summary: "One digit's spots in three rows all fall in the same three columns (Swordfish), or four rows in four columns (Jellyfish) — the digit comes off those columns everywhere else.",
        description: """
        The X-Wing's logic scales up. Find three rows where a digit's \
        remaining spots all fall inside the same three columns. Those three \
        rows each need the digit, and the three copies can't share a column, \
        so between them they use up all three columns. Erase the digit from \
        those columns everywhere outside the three rows. That's a Swordfish. \
        Four rows and four columns make a Jellyfish.

        As with naked triples, the rows don't each need all the columns — \
        two spots per row is fine, as long as the columns add up to three \
        (or four).
        """,
        steps: [
            "Work one digit at a time, with full notes.",
            "List rows where the digit has 2 or 3 spots (2 to 4 for a Jellyfish). Look for three (four) rows whose spots between them use exactly three (four) columns.",
            "Erase the digit from those columns outside the chosen rows. Then swap the roles of rows and columns and look again.",
        ],
        examples: [TechniqueExample(
            marks: [
                rc(2, 1): [6], rc(2, 5): [6],
                rc(5, 5): [6], rc(5, 9): [6],
                rc(8, 1): [6], rc(8, 9): [6],
                rc(4, 1): [3, 6], rc(7, 5): [6, 8], rc(1, 9): [2, 6],
            ],
            technique: .swordfish,
            eliminated: [rc(1, 9), rc(4, 1), rc(7, 5)],
            keyDigits: [6],
            caption: "In rows 2, 5 and 8 the 6 can only go in columns 1, 5 and 9 — two spots per row, three columns in total. Those three rows use up the 6 in all three columns, so the other 6s in them go."
        )],
        techniques: [.swordfish, .jellyfish]
    )

    public static let finnedFish = TechniqueTopic(
        name: "Finned Fish",
        tagline: "An X-Wing (or bigger) with one loose end",
        summary: "An almost-X-Wing with one spare candidate spoiling it — if the spare sits in a box with some of the fish's cover cells, the eliminations still hold inside that box.",
        description: """
        Sometimes an X-Wing (or Swordfish, or Jellyfish) is spoiled by one \
        or two extra candidates hanging off one of its rows. Solvers call \
        those extras fins. If all the fins sit in one box, the fish still \
        works — but only near the fins.

        Here's why. Either a fin is the digit, or it isn't. If it isn't, \
        you have a clean fish and its usual eliminations. If it is, it \
        rules the digit out of everything else in its box. So a cell that \
        would be eliminated by the clean fish *and* sits in the fin's box is \
        ruled out in both cases. Cells outside that box aren't safe to \
        erase.
        """,
        steps: [
            "Spot a would-be fish with one spare candidate hanging off one of its rows.",
            "Check that the spare (the fin) shares a box with some of the fish's cover cells.",
            "Erase the digit from the cover cells inside that box only.",
        ],
        examples: [TechniqueExample(
            marks: [
                rc(3, 2): [2, 5], rc(3, 8): [2, 9],
                rc(7, 2): [2, 3], rc(7, 8): [2, 6], rc(7, 9): [2, 4],
                rc(8, 8): [2, 5], rc(9, 8): [2, 7],
                rc(1, 8): [2, 9],
            ],
            technique: .finnedXWing,
            eliminated: [rc(8, 8), rc(9, 8)],
            keyDigits: [2],
            caption: "Rows 3 and 7 would make an X-Wing on 2 in columns 2 and 8, except for the extra 2 (orange, the fin) at the end of row 7. The fin shares the bottom-right box with two column-8 cells, so those lose their 2s. The 2 up in row 1 is outside the fin's box and survives."
        )],
        techniques: [.finnedXWing, .finnedSwordfish, .finnedJellyfish]
    )

    public static let xyzWing = TechniqueTopic(
        name: "XYZ-Wing",
        tagline: "An XY-Wing whose pivot keeps the third digit",
        summary: "Like an XY-Wing, but the pivot holds all three digits — so only cells that see the pivot and both wings lose the shared digit.",
        description: """
        Same idea as the XY-Wing, with one twist: the pivot holds all three \
        digits, {X, Y, Z}, instead of just two. The two wings hold {X, Z} \
        and {Y, Z} as before.

        Whatever the pivot turns out to be, one of the three cells ends up \
        as Z — if the pivot is Z, that's it; if it's X or Y, it knocks that \
        digit out of one wing, leaving that wing as Z. But now the pivot is \
        in the running too, so only a cell that sees *all three* — the \
        pivot and both wings — can be sure it isn't a Z. Fewer eliminations \
        than an XY-Wing, and easier to overlook.
        """,
        steps: [
            "Find a three-candidate cell whose row, column, or box holds two two-candidate cells covering its digits.",
            "The digit shared by both wings is Z.",
            "Erase Z only from cells that see the pivot and both wings.",
        ],
        examples: [TechniqueExample(
            marks: [
                rc(5, 5): [1, 4, 7],
                rc(5, 2): [1, 7],
                rc(4, 6): [4, 7],
                rc(5, 4): [3, 7], rc(5, 6): [7, 9],
                rc(5, 8): [2, 7],
            ],
            technique: .xyzWing,
            eliminated: [rc(5, 4), rc(5, 6)],
            keyDigits: [7],
            caption: "The pivot {1,4,7} sees wings {1,7} and {4,7}. One of the three must be a 7. The two red cells see the pivot and both wings, so they can't be — but the 7 at the right end of the row only sees the pivot and one wing, so it stays."
        )],
        techniques: [.xyzWing]
    )

    public static let wWing = TechniqueTopic(
        name: "W-Wing",
        tagline: "Twin two-candidate cells joined by a strong link",
        summary: "Two cells with the same two candidates that don't see each other, bridged by a two-spot line on one of the digits — one twin must be the other digit.",
        description: """
        Find two cells that both hold exactly the same two candidates — say \
        {3, 8} — but don't see each other. On their own they prove nothing. \
        Now find a row, column, or box where 8 has only two spots, with one \
        spot seeing the first twin and the other seeing the second.

        Suppose the first twin were 8. Then the link's near spot can't be, \
        so its far spot must be 8 — and the second twin, which sees it, \
        must be 3. Run it the other way and you get the mirror image. So \
        one twin or the other is a 3, and any cell that sees both twins \
        can't be.
        """,
        steps: [
            "Collect the two-candidate cells that share the same pair.",
            "For two of them that don't see each other, look for a row, column, or box where one of their digits has only two spots — one spot seeing each twin.",
            "Erase the other digit from every cell that sees both twins.",
        ],
        examples: [TechniqueExample(
            marks: [
                rc(2, 3): [3, 8], rc(7, 6): [3, 8],
                rc(5, 3): [2, 8], rc(5, 6): [4, 8],
                rc(2, 6): [3, 5], rc(7, 3): [3, 6],
            ],
            technique: .wWing,
            eliminated: [rc(2, 6), rc(7, 3)],
            keyDigits: [3],
            caption: "The two {3,8} twins don't see each other, but row 5 has only two spots for an 8, and each spot looks up or down a column at one twin. If either twin were 8, the link would push the other twin to 3. So one of them is a 3, and the red cells see both."
        )],
        techniques: [.wWing]
    )

    public static let remotePair = TechniqueTopic(
        name: "Remote Pair",
        tagline: "A chain of cells all holding the same pair",
        summary: "A chain of cells all showing the same two candidates, each seeing the next — the digits must alternate along it, so its far ends hold different digits.",
        description: """
        Find a run of cells that all hold exactly the same two candidates, \
        say {4, 9}, where each cell sees the next one. Along the chain the \
        digits have to alternate: 4, 9, 4, 9… So any two chain cells that \
        are an odd number of steps apart hold different digits, and between \
        them they use up both 4 and 9. Any cell that sees both of them can't \
        be either.

        Think of it as a naked pair stretched across the board.
        """,
        steps: [
            "Find four or more cells sharing the same two candidates that link up into a chain, each seeing the next.",
            "Colour them alternately along the chain.",
            "Erase both digits from any cell that sees two chain cells of opposite colours.",
        ],
        examples: [TechniqueExample(
            marks: [
                rc(1, 1): [4, 9], rc(3, 2): [4, 9], rc(3, 6): [4, 9], rc(7, 6): [4, 9],
                rc(7, 1): [2, 4, 9],
            ],
            technique: .remotePair,
            eliminated: [rc(7, 1)],
            keyDigits: [4, 9],
            caption: "Four {4,9} cells link up: box, then row, then column. Their digits must alternate (blue, orange, blue, orange), so the two ends hold different digits — and the red cell sees both ends. Its 4 and 9 go, leaving a 2."
        )],
        techniques: [.remotePair]
    )

    public static let coloring = TechniqueTopic(
        name: "Coloring",
        tagline: "Paint one digit's strong links in two colours",
        summary: "For one digit, chain together every row, column, and box with only two spots, and paint the spots in two alternating colours — one colour is entirely true, the other entirely false.",
        description: """
        Pick one digit. Everywhere it has exactly two spots left in a row, \
        column, or box, those two spots are a strong link: one of them is \
        the digit. Now paint: give one spot blue, the other orange, and keep \
        alternating along every link you can reach. In the whole cluster, \
        one colour is entirely true and the other entirely false — you just \
        don't know which yet.

        That gives you two kinds of elimination. If two cells of the same \
        colour share a row, column, or box, that colour can't be the true \
        one — erase every cell of it. And any candidate outside the cluster \
        that sees a blue cell and an orange cell is ruled out either way.

        Multi-colouring plays two separate clusters against each other with \
        the same reasoning.
        """,
        steps: [
            "Pick a digit and join up its two-spot rows, columns, and boxes into clusters.",
            "Alternate colours along every link.",
            "Same colour twice in one row, column, or box: that colour is false everywhere. A candidate that sees both colours: false.",
        ],
        examples: [TechniqueExample(
            marks: [
                rc(1, 2): [3, 8], rc(1, 7): [3, 5],
                rc(6, 2): [3, 4], rc(5, 3): [3, 7],
                rc(5, 7): [3, 6],
                rc(5, 9): [3, 8], rc(9, 7): [1, 3],
            ],
            technique: .simpleColors,
            eliminated: [rc(5, 7)],
            keyDigits: [3],
            caption: "For the digit 3, row 1, column 2 and the middle-left box each have only two spots, so they chain up. Painting them alternately gives blue and orange. The red cell sees an orange 3 (in its column) and a blue 3 (in its row) — one of them is real, so it can't be a 3."
        )],
        techniques: [.simpleColors, .multiColors]
    )

    public static let xChains = TechniqueTopic(
        name: "X-Chain & XY-Chain",
        tagline: "Chains of links, on one digit or through two-candidate cells",
        summary: "A chain that alternates strong and weak links, starting and ending strong — one end must be true, so anything that sees both ends is false.",
        description: """
        Skyscrapers, kites, and W-Wings are all short chains. Here's the \
        general version.

        An X-Chain follows one digit. Solid links join the only two spots \
        for the digit in some row, column, or box (if one isn't it, the \
        other is). Dashed links join two spots that see each other (if one \
        is it, the other isn't). Alternate them — solid, dashed, solid — \
        starting and ending with a solid link. Suppose the first cell isn't \
        the digit: the chain forces the last cell to be. So one end or the \
        other is the digit, and it comes off any cell that sees both ends.

        An XY-Chain does the same thing through two-candidate cells. Each \
        cell passes its "other" digit to the next: if this one isn't 1 it's \
        2, so the next isn't 2 and must be 3, and so on. If the first cell \
        and the last cell both offer the same digit, one of them is it.
        """,
        steps: [
            "A strong link is a row, column, or box with exactly two spots for a digit — or a cell with exactly two candidates.",
            "Chain them: strong, weak, strong… starting and ending strong.",
            "Erase the digit from every cell that sees both ends of the chain.",
        ],
        examples: [
            TechniqueExample(
                marks: [
                    rc(2, 1): [3, 5], rc(2, 5): [5, 8],
                    rc(5, 5): [1, 5], rc(5, 9): [4, 5],
                    rc(8, 9): [2, 5], rc(8, 3): [5, 7],
                    rc(3, 3): [5, 6], rc(9, 1): [2, 5],
                    rc(1, 4): [2, 5], rc(3, 1): [5, 9], rc(3, 5): [4, 5], rc(3, 9): [5, 6], rc(6, 3): [5, 9],
                ],
                technique: .xChain,
                eliminated: [rc(3, 3), rc(9, 1)],
                keyDigits: [5],
                caption: "An X-Chain on 5. Rows 2, 5 and 8 each have just two spots for a 5, so those are solid links. The steps between them run down columns 5 and 9, which have more spots, so those are dashed. If the top-left end isn't a 5, the chain forces the bottom-left end to be — so one of them is, and the red cells see both."
            ),
            TechniqueExample(
                marks: [
                    rc(1, 1): [1, 2], rc(1, 6): [2, 3], rc(4, 6): [3, 4], rc(4, 9): [1, 4],
                    rc(1, 9): [1, 5], rc(4, 1): [1, 7],
                ],
                technique: .xyChain,
                eliminated: [rc(1, 9), rc(4, 1)],
                keyDigits: [1],
                caption: "An XY-Chain. Suppose the top-left {1,2} isn't 1: it's 2, so the next cell is 3, so the next is 4, so the last is 1. Either the first cell or the last is a 1 — and the red cells see both."
            ),
        ],
        techniques: [.xChain, .xyChain]
    )

    public static let uniqueness = TechniqueTopic(
        name: "Uniqueness Arguments",
        tagline: "The puzzle has exactly one solution — use that",
        summary: "Four cells on two rows, two columns, and two boxes can't all end up as the same two digits (that would give the puzzle two solutions), so whatever would cause that is false.",
        description: """
        A proper sudoku has exactly one solution, and you can use that fact \
        as a tool. Picture four cells on two rows, two columns, and two \
        boxes — a rectangle. If all four ended up holding the same two \
        digits, you could swap the two digits around the rectangle and get \
        a second valid solution. Since that can't happen, anything that \
        would leave the rectangle that way is false.

        The simplest version: three corners are already down to the same \
        two candidates. Then the fourth corner can't be either of them — \
        erase both. Other versions read the same rectangle in cleverer ways \
        (an extra candidate in the roof cells must be the real one; a digit \
        trapped in the rectangle's rows and columns is forced onto one \
        diagonal).

        BUG+1 applies the same idea to the whole board: if placing one \
        candidate would leave every empty cell with exactly two candidates, \
        that candidate must be the true one.
        """,
        steps: [
            "Watch for rectangles across exactly two boxes whose corners share the same pair of candidates.",
            "Three corners down to the bare pair? The fourth can't be either digit. Roof cells sharing one extra digit? It's real, so cells that see both roofs lose it.",
            "Every empty cell down to two candidates except one? That's BUG+1: the odd candidate out is the true one.",
        ],
        examples: [TechniqueExample(
            marks: [
                rc(2, 2): [4, 7], rc(2, 7): [4, 7],
                rc(3, 2): [4, 7], rc(3, 7): [4, 7, 9],
            ],
            technique: .uniqueRectangle,
            eliminated: [rc(3, 7)],
            keyDigits: [4, 7],
            caption: "Three corners of this rectangle are down to {4,7}. If the fourth were too, the 4s and 7s could be swapped for a second solution. So the fourth corner can't be 4 or 7 — it's the 9."
        )],
        techniques: [.uniqueRectangle, .hiddenRectangle, .avoidableRectangle, .bugPlusOne]
    )

    public static let alsFamily = TechniqueTopic(
        name: "ALS & Sue de Coq",
        tagline: "Groups of cells one digit short of locked",
        summary: "Two groups of cells that are each one digit short of a locked set, tied together by a digit that can only be in one of them — the other group locks, and a second shared digit is ruled out where it sees both.",
        description: """
        An "almost locked set" is a group of cells in one row, column, or \
        box that holds one more digit than it has cells — two cells with \
        three digits between them, say. One elimination away from a naked \
        pair. (A single two-candidate cell is the smallest one.)

        Take two such groups that share a digit — call it X — where every X \
        in the first group sees every X in the second. Then only one group \
        can actually contain X. Whichever group loses it becomes a proper \
        locked set, and a locked set uses up all its remaining digits. So \
        if the two groups share another digit, Z, one group or the other \
        definitely holds a Z — and any cell that sees every Z in both \
        groups can't be one.

        Sue de Coq is the same counting argument, done where a row or \
        column crosses a box.
        """,
        steps: [
            "Two-candidate cells are the smallest almost locked sets — every wing you know is secretly ALS logic.",
            "Find two groups (in different rows, columns, or boxes) that each hold one more digit than they have cells.",
            "A shared digit whose copies all see each other is the tie. Any other shared digit is ruled out wherever it sees every copy in both groups.",
        ],
        examples: [TechniqueExample(
            marks: [
                rc(2, 4): [2, 6], rc(2, 5): [2, 6, 9],
                rc(1, 6): [3, 9], rc(7, 6): [3, 6],
                rc(2, 6): [6, 7], rc(3, 6): [4, 6],
            ],
            technique: .alsXZ,
            eliminated: [rc(2, 6), rc(3, 6)],
            keyDigits: [6, 9],
            caption: "Two cells in row 2 hold {2,6,9}; two cells in column 6 hold {3,6,9}. The 9s (orange) see each other, so only one group gets the 9. The other locks and must contain a 6. The red cells see every 6 in both groups, so they can't be 6."
        )],
        techniques: [.alsXZ, .sueDeCoq]
    )

    public static let aicTopic = TechniqueTopic(
        name: "Alternating Inference Chains",
        tagline: "The general chain that every pattern descends from",
        summary: "A chain over individual candidates, alternating \"if not this, then that\" with \"if this, then not that\" — its two ends can't both be false.",
        description: """
        This is the most general form of chain, and every pattern in this \
        guide is a special case of it. It runs over individual candidates \
        rather than cells.

        A solid link means "if not this, then that": the only other \
        candidate in a cell, or the only other spot for a digit in a row, \
        column, or box. A dashed link means "if this, then not that": two \
        candidates that can't both be true. Alternate them, starting and \
        ending with a solid link, and you've proved the two ends can't both \
        be false. So any candidate that either end would knock out is gone.

        You don't have to find these yourself. When the Coach finds one it \
        draws it on the board — solid lines for strong links, dashed for \
        weak — so you can follow the argument step by step.
        """,
        steps: [
            "Read a chain from one end: \"if this isn't true, then that must be, so this can't be, so that must be…\"",
            "Check it starts and ends with a solid link. Then one end is true, whichever it is.",
            "Erase any candidate that a true end would rule out — from either end.",
        ],
        examples: [TechniqueExample(
            marks: [
                rc(3, 3): [4, 7], rc(3, 8): [2, 7, 9], rc(3, 5): [7, 8],
                rc(7, 8): [4, 7], rc(7, 3): [4, 9],
                rc(5, 3): [4, 6], rc(9, 3): [1, 4], rc(8, 1): [4, 8],
            ],
            technique: .aic,
            eliminated: [rc(5, 3), rc(9, 3)],
            keyDigits: [4],
            caption: "Read it from the top-left {4,7}. If it isn't a 4, it's a 7 (solid: the cell's only other candidate). Then the cell at the right end of row 3 can't be a 7 (dashed: same row), so column 8's 7 must be the lower cell (solid: the column's only other spot). That cell is then not a 4 (dashed: same cell), so row 7's other 4 spot must take it (solid). Both ends are 4s in column 3, and one of them is real — the red 4s between them go."
        )],
        techniques: [.aic]
    )

    // MARK: Last resort

    public static let forcingChains = TechniqueTopic(
        name: "Forcing Chains & Alts",
        tagline: "Test a candidate on a what-if sheet",
        summary: "When patterns run out: assume one candidate, follow the consequences on an Alt sheet, and see whether it breaks the puzzle.",
        description: """
        When no pattern applies, you can still reason forward. Pick a \
        candidate, assume it's true, and follow the consequences. Either \
        you hit a contradiction — which proves the candidate was wrong — or \
        both possibilities lead to the same result somewhere, which makes \
        that result certain.

        That's exactly what the Alt button is for. An Alt is a practice \
        copy of the real game: anything you try there is sandboxed, and \
        every change is marked so you can follow the argument — purple for \
        a trial digit, struck through for a note the trial knocked out, \
        green for a note you added.
        """,
        steps: [
            "Pick a promising cell — ideally one with two candidates in a crowded area. Add an Alt.",
            "Place one candidate as a trial digit. Its eliminations show struck through. When a cell is left with a single note, follow it with another trial placement, and keep going.",
            "Hit a contradiction — a cell with no candidates left, or a row, column, or box that can't fit some digit? The assumption was wrong, so the other candidate is right. Discard the Alt and play it in the real game.",
            "No contradiction? Add another Alt and test the other candidate. Any cell that comes out the same in both branches is certain either way — play that.",
            "Every sheet branches from the real game, so you can flip between the chips to compare paths side by side. The trash button removes a refuted branch.",
        ],
        examples: [TechniqueExample(
            values: "000000010000000000000000000000000000000030060000000000000000000000000000000000000",
            marks: [rc(2, 5): [1, 3]],
            eliminated: [rc(2, 5)],
            trials: [rc(5, 5), rc(5, 8), rc(1, 8)],
            struck: [rc(2, 5): [1, 3]],
            caption: "On an Alt, we tried a 3 in the middle cell (purple). That forced the 6 to its right, which forced the 1 at the top of that column, which left the red cell in row 2 with no candidates at all — its 3 is blocked by the trial, its 1 by the new 1. Contradiction, so the middle cell isn't 3: it's the 8."
        )]
    )
}
