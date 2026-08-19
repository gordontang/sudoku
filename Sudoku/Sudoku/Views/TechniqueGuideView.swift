import SudokuKit
import SwiftUI

// MARK: - Content model

/// An illustrative (not necessarily globally-valid) board snippet: values,
/// pencil marks, and cells to tint. Enough to show a pattern's shape.
struct TechniqueExample {
    let values: [UInt8]
    let marks: [Int: [UInt8]]
    /// Cells forming the pattern (tinted blue).
    let pattern: Set<Int>
    /// Cells losing candidates because of it (tinted red).
    let eliminated: Set<Int>
    /// Digits to emphasize wherever they appear (values and marks).
    let keyDigits: Set<UInt8>
    let caption: String

    init(
        values: String = String(repeating: "0", count: 81),
        marks: [Int: [UInt8]] = [:],
        pattern: Set<Int> = [],
        eliminated: Set<Int> = [],
        keyDigits: Set<UInt8> = [],
        caption: String
    ) {
        self.values = values.map { UInt8(String($0)) ?? 0 }
        self.marks = marks
        self.pattern = pattern
        self.eliminated = eliminated
        self.keyDigits = keyDigits
        self.caption = caption
    }
}

struct TechniqueTopic: Identifiable {
    let id: String
    let name: String
    let tagline: String
    let description: String
    let steps: [String]
    let example: TechniqueExample?

    init(
        name: String,
        tagline: String,
        description: String,
        steps: [String] = [],
        example: TechniqueExample? = nil
    ) {
        id = name
        self.name = name
        self.tagline = tagline
        self.description = description
        self.steps = steps
        self.example = example
    }
}

struct TechniqueSection: Identifiable {
    let id: String
    let title: String
    let topics: [TechniqueTopic]

    init(_ title: String, _ topics: [TechniqueTopic]) {
        id = title
        self.title = title
        self.topics = topics
    }
}

// MARK: - Guide view

/// In-game reference manual: solving techniques from singles to chains.
/// Presented as a sheet during play so it can be consulted mid-puzzle.
struct TechniqueGuideView: View {
    /// Shows a Done button when presented as a sheet.
    var isSheet = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(TechniqueContent.sections) { section in
                Section(section.title) {
                    ForEach(section.topics) { topic in
                        NavigationLink {
                            TechniqueDetailView(topic: topic)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(topic.name)
                                Text(topic.tagline)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Techniques")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isSheet {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("guide_done")
                }
            }
        }
    }
}

private struct TechniqueDetailView: View {
    let topic: TechniqueTopic

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(topic.description)
                    .font(.callout)

                if let example = topic.example {
                    MiniBoardView(example: example)
                        .frame(maxWidth: 340)
                        .frame(maxWidth: .infinity)
                    Text(example.caption)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if !topic.steps.isEmpty {
                    Text("How to use it")
                        .font(.headline)
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(topic.steps.enumerated()), id: \.offset) { i, step in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text("\(i + 1).")
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(Color.accentColor)
                                Text(step)
                                    .font(.callout)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle(topic.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Mini board renderer

private struct MiniBoardView: View {
    let example: TechniqueExample

    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<9, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<9, id: \.self) { col in
                        cell(row * 9 + col)
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .background(Theme.boardBackground)
        .overlay(MiniGridLines(major: false).stroke(Theme.gridLineMinor, lineWidth: 0.5))
        .overlay(MiniGridLines(major: true).stroke(Theme.gridLineMajor, lineWidth: 1.5))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .accessibilityHidden(true)
    }

    private func cell(_ index: Int) -> some View {
        ZStack {
            Rectangle().fill(background(index))
            let value = example.values[index]
            if value != 0 {
                Text("\(value)")
                    .font(.system(size: 15, weight: example.keyDigits.contains(value) ? .bold : .regular))
                    .minimumScaleFactor(0.4)
                    .foregroundStyle(example.keyDigits.contains(value) ? Color.accentColor : Theme.givenText)
            } else if let marks = example.marks[index] {
                markGrid(marks, eliminated: example.eliminated.contains(index))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func background(_ index: Int) -> Color {
        if example.pattern.contains(index) { return Theme.cellSameDigit }
        if example.eliminated.contains(index) { return Theme.cellMistake }
        return .clear
    }

    private func markGrid(_ marks: [UInt8], eliminated: Bool) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { c in
                        let digit = UInt8(r * 3 + c + 1)
                        let present = marks.contains(digit)
                        let isKey = present && example.keyDigits.contains(digit)
                        Text(present ? "\(digit)" : " ")
                            .font(.system(size: 7, weight: isKey ? .bold : .regular))
                            .minimumScaleFactor(0.5)
                            .foregroundStyle(
                                isKey
                                    ? (eliminated ? Theme.mistakeText : Color.accentColor)
                                    : Theme.pencilText
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .padding(1)
    }
}

/// Same drawing as the game board's grid lines, local to the guide.
private struct MiniGridLines: Shape {
    let major: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let steps = major ? [0, 3, 6, 9] : [1, 2, 4, 5, 7, 8]
        for i in steps {
            let x = rect.minX + rect.width * CGFloat(i) / 9
            path.move(to: CGPoint(x: x, y: rect.minY))
            path.addLine(to: CGPoint(x: x, y: rect.maxY))
            let y = rect.minY + rect.height * CGFloat(i) / 9
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        return path
    }
}

// MARK: - Content

enum TechniqueContent {
    static let sections: [TechniqueSection] = [
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

    static let strategy = TechniqueTopic(
        name: "Working a Hard Puzzle",
        tagline: "The order of attack when nothing is obvious",
        description: """
        Master puzzles are designed so that simple scanning runs dry. When it \
        does, work up this ladder — each rung is cheaper than the one after \
        it, and every elimination can unlock a cascade of easy placements.
        """,
        steps: [
            "Fill complete candidates: long-press the Pencil button so every empty cell shows exactly its legal digits. Advanced techniques only work with complete, accurate notes.",
            "Sweep singles: any cell with one candidate, any digit with one home in a row, column, or box.",
            "Select a number (or tap one of its placements) to light up its coverage — the rows, columns, and boxes it already rules out — and every cell where it's still penciled. Scan digits 1–9 this way. (The Covered Cells setting picks whether coverage comes from every placement or just the selected cell.)",
            "Hunt eliminations: Locked Candidates, then pairs, triples, and quadruples, then fish, single-digit patterns, and wings. After each elimination, re-sweep singles.",
            "Stuck with honest notes? Ask the Coach — it names the cheapest available technique and reveals more only when you ask: name, then location, then the pattern itself.",
            "When even the coach says the patterns have run out, that's chain territory — add an Alt and test a candidate (see Forcing Chains).",
        ]
    )

    static let fullHouse = TechniqueTopic(
        name: "Full House",
        tagline: "The last empty cell of a unit",
        description: """
        A row, column, or box with eight digits placed has exactly one gap — \
        and the one missing digit fills it. The friendliest deduction there \
        is, and worth actively scanning for: every placement can complete a \
        unit somewhere else.
        """,
        steps: [
            "After each placement, glance at the row, column, and box it touched.",
            "Any of them down to a single gap? Count which digit is missing and place it.",
        ],
        example: TechniqueExample(
            values: String(repeating: "0", count: 27)
                + "000123000" + "000406000" + "000789000"
                + String(repeating: "0", count: 27),
            marks: [40: [5]],
            pattern: [40],
            keyDigits: [5],
            caption: "The center box holds every digit but 5 — its last cell takes it."
        )
    )

    static let nakedSingle = TechniqueTopic(
        name: "Naked Single",
        tagline: "A cell with only one candidate left",
        description: """
        When a cell's row, column, and box together contain eight different \
        digits, only one digit can still go there — even though no single \
        unit is anywhere near complete. With full pencil marks these cells \
        show a single note — place it immediately.
        """,
        steps: [
            "Scan for cells showing exactly one pencil mark.",
            "Place the digit; the eliminations it causes often create new naked singles.",
        ],
        example: TechniqueExample(
            values: "000050000000060000000000000000700000123000400000008000000000000000000000000000000",
            marks: [40: [9]],
            pattern: [40],
            keyDigits: [9],
            caption: "No unit is close to done, but the row rules out 1–4, the column 5 and 6, and the box 7 and 8 — only 9 fits."
        )
    )

    static let hiddenSingle = TechniqueTopic(
        name: "Hidden Single",
        tagline: "A digit with only one home in a unit",
        description: """
        A cell may have several candidates, yet still be forced: if a digit \
        fits nowhere else in its row, column, or box, that cell must take it. \
        This is the cross-hatching you do instinctively on easier puzzles — \
        on Master boards it hides among dense pencil marks.
        """,
        steps: [
            "Pick a digit and a box. Selecting one of the digit's placements highlights its covered rows and columns.",
            "If only one cell of the box escapes the coverage, the digit lives there — no matter what else that cell could hold.",
            "Repeat per digit, box by box, then rows and columns.",
        ],
        example: TechniqueExample(
            values: "000000000000005000000000050000000000050000000000000000005000000000000000000000000",
            marks: [0: [5]],
            pattern: [0],
            eliminated: [1, 2, 9, 10, 11, 18, 19, 20],
            keyDigits: [5],
            caption: "The 5s in rows 2–3 and columns 2–3 cover every cell of the top-left box except one: 5 is forced into the corner."
        )
    )

    static let lockedCandidates = TechniqueTopic(
        name: "Locked Candidates",
        tagline: "A box pins a digit to one row or column",
        description: """
        If all of a digit's candidates inside a box sit in a single row (or \
        column), the digit must occupy that row inside that box — so it can \
        be erased from the rest of the row outside the box. The same works in \
        reverse: a row confining a digit to one box clears the rest of the box.
        """,
        steps: [
            "For each box and digit, look at where the digit's marks sit.",
            "All in one row or column? Erase that digit's marks from the rest of the line outside the box.",
            "Re-sweep for new singles after each erasure.",
        ],
        example: TechniqueExample(
            values: "001000000080000000503000000000000000000000000000000000000000000000000000000000000",
            marks: [
                0: [2, 7], 1: [7, 9],
                9: [2, 9], 11: [4, 6], 19: [4, 6],
                4: [6, 7], 7: [7, 8],
            ],
            pattern: [0, 1],
            eliminated: [4, 7],
            keyDigits: [7],
            caption: "In the top-left box, 7 fits only in the first row. Wherever it lands, the row's 7 is spoken for — erase 7 from the row's other cells."
        )
    )

    static let nakedPair = TechniqueTopic(
        name: "Naked Pair",
        tagline: "Two cells locked to the same two digits",
        description: """
        Two cells in one unit that both show exactly the same two candidates \
        must take those two digits between them — which one goes where is \
        unknown, but no other cell in the unit can have either digit. Erase \
        both digits from the rest of the unit.

        When the two cells sit in a box–line intersection they form a Locked \
        Pair: the digits die in the rest of the row (or column) *and* the \
        rest of the box at once — twice the eliminations for the same find.
        """,
        steps: [
            "Look for two cells in a row, column, or box showing the identical two marks.",
            "Erase those two digits from every other cell of that unit.",
            "The slimmed-down cells often collapse into singles.",
        ],
        example: TechniqueExample(
            values: "000000000000000000010368070000000000000000000000000000000000000000000000000000000",
            marks: [
                18: [4, 5, 9],
                20: [4, 9],
                24: [4, 9],
                26: [2, 4, 9],
            ],
            pattern: [20, 24],
            eliminated: [18, 26],
            keyDigits: [4, 9],
            caption: "Two cells of row 3 hold exactly {4, 9}. Between them they consume both digits, so 4 and 9 die in the row's other cells — leaving a naked 5 and a naked 2."
        )
    )

    static let hiddenPair = TechniqueTopic(
        name: "Hidden Pair",
        tagline: "Two digits confined to the same two cells",
        description: """
        If two digits each fit in only the same two cells of a unit, those \
        cells must hold that pair — every other candidate in those two cells \
        is noise and can be erased. Harder to spot than a naked pair because \
        the cells look busy.
        """,
        steps: [
            "Per unit, note which cells each digit can occupy (highlight one digit at a time).",
            "Two digits sharing the same two-cell home? Erase all other marks from those two cells.",
        ],
        example: TechniqueExample(
            values: "000000000000000000000000000000000000000000000000000000100046000000000000000000000",
            marks: [
                55: [2, 5, 7],
                56: [5, 8],
                57: [3, 5, 8],
                60: [2, 7, 8],
                61: [8, 9],
                62: [3, 9],
            ],
            pattern: [55, 60],
            keyDigits: [2, 7],
            caption: "In row 7, digits 2 and 7 appear in just two cells. Those cells are claimed by the pair — their extra marks (5, 8) can be erased."
        )
    )

    static let nakedTriple = TechniqueTopic(
        name: "Naked Triple",
        tagline: "Three cells sharing three digits",
        description: """
        Three cells in a unit whose candidates together span only three \
        digits work like a naked pair, one size up: those three digits are \
        spoken for, and can be erased from the unit's other cells. The cells \
        don't each need all three digits — {2,6}, {2,9}, {6,9} is a valid \
        triple on {2, 6, 9}.

        Three such cells inside a box–line intersection are a Locked Triple, \
        clearing the rest of both the line and the box in one step.
        """,
        steps: [
            "In a unit with several two- and three-candidate cells, test whether three of them cover only three digits in total.",
            "Erase those digits from the rest of the unit.",
        ]
    )

    static let hiddenTriple = TechniqueTopic(
        name: "Hidden Triple",
        tagline: "Three digits confined to the same three cells",
        description: """
        If three digits each fit only within the same three cells of a unit, \
        those cells belong to the trio — every other candidate in them can be \
        erased. Like the naked triple, coverage can be partial: each digit \
        just has to stay inside the three cells, not appear in all of them. \
        The hardest of the intermediate patterns to see, because the cells \
        look busy and nothing about them stands out.
        """,
        steps: [
            "Work digit by digit: for each unit, note the digits confined to three or fewer cells.",
            "Three digits sharing the same three-cell home? Erase everything else from those cells.",
            "Hunt where pencil marks are dense — hidden subsets hide in clutter.",
        ],
        example: TechniqueExample(
            marks: [
                18: [1, 2, 7, 8],
                19: [2, 3, 7, 8],
                20: [1, 3, 7, 8],
                21: [4, 5, 6],
                22: [4, 6, 9],
                23: [5, 9],
                24: [6, 7, 9],
                25: [4, 8, 9],
                26: [5, 6, 7],
            ],
            pattern: [18, 19, 20],
            keyDigits: [1, 2, 3],
            caption: "In row 3, digits 1, 2, and 3 fit nowhere but the first three cells. The trio claims them — the 7s and 8s cluttering those cells can be erased."
        )
    )

    static let quadruples = TechniqueTopic(
        name: "Quadruples",
        tagline: "Pairs and triples, one size bigger",
        description: """
        Both subset patterns extend to four: four cells covering only four \
        digits (naked quadruple) let you erase those digits from the rest of \
        the unit, and four digits confined to four cells (hidden quadruple) \
        empty those cells of everything else. Rare — a naked quadruple in \
        one unit is always paired with a hidden set in the rest of it, so \
        whichever half is smaller is easier to spot.
        """,
        steps: [
            "Look in units with few placed digits — quadruples need room.",
            "Four cells whose candidates union to four digits: erase those digits elsewhere in the unit.",
            "Four digits whose homes union to four cells: erase the other candidates from those cells.",
        ]
    )

    static let xWing = TechniqueTopic(
        name: "X-Wing",
        tagline: "A rectangle that traps a digit",
        description: """
        Find two rows where a digit has exactly two candidate columns — the \
        same two columns in both rows. The digit must land on one diagonal of \
        that rectangle, so both columns receive it from those rows. Erase the \
        digit from the two columns everywhere else. Works the same with rows \
        and columns swapped.
        """,
        steps: [
            "Select the digit to light up its remaining spots, row by row.",
            "Two rows with the digit in only the same two columns form the rectangle.",
            "Erase the digit from both columns outside those rows.",
        ],
        example: TechniqueExample(
            marks: [
                11: [3], 15: [3],
                65: [3], 69: [3],
                29: [3, 8],
                51: [3, 4],
            ],
            pattern: [11, 15, 65, 69],
            eliminated: [29, 51],
            keyDigits: [3],
            caption: "Rows 2 and 8 each allow 3 in only these two columns. One diagonal of the rectangle must hold both 3s, so the columns are covered either way — 3 dies elsewhere in both."
        )
    )

    static let xyWing = TechniqueTopic(
        name: "XY-Wing",
        tagline: "Three two-candidate cells, one shared victim",
        description: """
        Take a pivot cell with candidates {X, Y} that sees two wing cells: \
        one {X, Z} and one {Y, Z}. Whichever way the pivot resolves, one wing \
        becomes Z. So any cell that sees both wings can never be Z — erase Z \
        from it. Bi-value cells are the raw material; hunt for them first.
        """,
        steps: [
            "List cells with exactly two candidates.",
            "Find a pivot {X, Y} seeing wings {X, Z} and {Y, Z}.",
            "Erase Z from every cell that sees both wings (peers of both).",
        ],
        example: TechniqueExample(
            marks: [
                40: [2, 7],
                37: [2, 5],
                13: [5, 7],
                10: [5, 9],
            ],
            pattern: [40, 37, 13],
            eliminated: [10],
            keyDigits: [5],
            caption: "The pivot {2,7} sees wings {2,5} and {5,7}. If pivot=2 the left wing is 5; if pivot=7 the top wing is 5. Either way a 5 lands where the red cell can see it — its 5 is dead."
        )
    )

    static let skyscraper = TechniqueTopic(
        name: "Skyscraper",
        tagline: "Two strong links, one shared base",
        description: """
        Find a digit with exactly two spots in each of two rows, where one \
        spot of each shares a column — two towers on a common base. If the \
        base cell of one tower is false, its roof is true; the bases can't \
        both be true, so at least one roof holds the digit. The digit dies \
        in every cell that sees both roofs. Works with columns too.
        """,
        steps: [
            "Select the digit to light up its remaining spots.",
            "Two rows with exactly two spots each, sharing one column: the shared column is the base, the other two spots the roofs.",
            "Erase the digit wherever both roofs are visible (same row, column, or box).",
        ]
    )

    static let twoStringKite = TechniqueTopic(
        name: "2-String Kite & Turbot Fish",
        tagline: "A row link and a column link tied in a box",
        description: """
        Take a digit with exactly two spots in a row and exactly two in a \
        column, one end of each sitting in the same box. Those box ends \
        can't both be true; the logic ripples outward and the two far ends \
        can't both be false — so the cell seeing both far ends can't hold \
        the digit. Variants that use a box's own strong link are called \
        Turbot Fish; the reasoning is identical.
        """,
        steps: [
            "Hunt digits with exactly two spots in a unit — these strong links are the raw material for every chain pattern.",
            "Find a row link and a column link whose near ends share a box.",
            "Erase the digit from the cell at the intersection of the two far ends.",
        ]
    )

    static let emptyRectangle = TechniqueTopic(
        name: "Empty Rectangle",
        tagline: "A box whose candidates form a cross",
        description: """
        When all of a digit's candidates in a box sit on one row and one \
        column (a cross), then wherever the digit lands in the box, it \
        covers that row or that column. Combine with a strong link in an \
        outside line pointing at the cross: one specific cell closing the \
        rectangle can never hold the digit.
        """,
        steps: [
            "Per box and digit, check whether the candidates collapse onto a row+column cross.",
            "Find a two-spot line for the digit with one end on the cross's column (or row).",
            "The cell aligned with the link's other end and the cross's row (or column) loses the digit.",
        ]
    )

    static let biggerFish = TechniqueTopic(
        name: "Swordfish & Jellyfish",
        tagline: "X-Wing, one and two sizes up",
        description: """
        The X-Wing's logic scales: three rows where a digit fits in only \
        the same three columns trap the digit (Swordfish); four rows and \
        four columns make a Jellyfish. The rows needn't each use all the \
        columns — coverage can be partial, as with naked triples. Erase \
        the digit from those columns everywhere outside the defining rows.
        """,
        steps: [
            "Work one digit at a time with full notes.",
            "List rows with 2–3 (or 2–4) spots; look for three (four) rows whose spots union to exactly three (four) columns.",
            "Erase the digit from those columns outside the chosen rows. Swap rows and columns and repeat.",
        ]
    )

    static let finnedFish = TechniqueTopic(
        name: "Finned Fish",
        tagline: "A fish with a loose end",
        description: """
        An almost-X-Wing (or Swordfish/Jellyfish) with one or two extra \
        candidates — fins — spoiling the pattern. If the fins all share a \
        box, the fish still works, but only near the fins: either the \
        clean fish logic holds, or a fin is true — and both cases kill the \
        digit in the cover columns *inside the fin's box*.
        """,
        steps: [
            "Spot a would-be fish with one spare candidate hanging off a base row.",
            "Check the spare (fin) shares a box with some of the fish's cover cells.",
            "Erase the digit from cover cells inside that box only.",
        ]
    )

    static let xyzWing = TechniqueTopic(
        name: "XYZ-Wing",
        tagline: "An XY-Wing whose pivot keeps the Z",
        description: """
        Like the XY-Wing, but the pivot holds all three digits {X, Y, Z}. \
        One of the three cells must be Z — but now the pivot is a \
        candidate too, so only cells seeing *all three* (pivot and both \
        wings) lose their Z. Tighter eliminations, easier to overlook.
        """,
        steps: [
            "Find a three-candidate cell whose box or lines hold two bivalue cells covering its digits.",
            "The digit shared by both wings is Z.",
            "Erase Z only from cells that see the pivot and both wings.",
        ]
    )

    static let wWing = TechniqueTopic(
        name: "W-Wing",
        tagline: "Twin bivalue cells joined by a strong link",
        description: """
        Two cells with the same two candidates {X, Y} that don't see each \
        other, plus a strong link on Y whose ends see one twin each: if \
        either twin were Y, the link forces the other to X. So one of the \
        twins is X — and X dies wherever both twins are seen.
        """,
        steps: [
            "Collect bivalue cells sharing the same pair.",
            "For twins that don't see each other, hunt a two-spot unit for one of their digits bridging them.",
            "Erase the other digit from every cell seeing both twins.",
        ]
    )

    static let remotePair = TechniqueTopic(
        name: "Remote Pair",
        tagline: "A chain of identical pairs",
        description: """
        A chain of cells all holding the same pair {X, Y}, each seeing the \
        next, must alternate X, Y, X, Y… Any two chain cells an odd number \
        of steps apart hold different digits between them — so both X and \
        Y die in any cell that sees both. A naked pair, stretched across \
        the board.
        """,
        steps: [
            "Find four or more same-pair bivalue cells linked into a chain.",
            "Color them alternately along the chain.",
            "Erase both digits from cells seeing two opposite-colored chain cells.",
        ]
    )

    static let coloring = TechniqueTopic(
        name: "Coloring",
        tagline: "Paint a digit's strong links in two colors",
        description: """
        For one digit, connect every unit that has exactly two spots — in \
        each such pair, exactly one end is true. Painting the network in \
        two alternating colors makes the whole cluster binary: one color \
        is entirely true, the other entirely false. Two same-colored cells \
        sharing a unit kill that whole color; any outside candidate seeing \
        both colors dies either way. Multi-coloring plays two clusters \
        against each other with the same logic.
        """,
        steps: [
            "Pick a digit; link up its two-spot units into clusters.",
            "Alternate colors along every link.",
            "Same color twice in one unit → that color is false everywhere. A candidate seeing both colors → false.",
        ]
    )

    static let xChains = TechniqueTopic(
        name: "X-Chain & XY-Chain",
        tagline: "Alternating chains, one digit or many",
        description: """
        An X-Chain walks a single digit through alternating strong and \
        weak links; with strong links at both ends, one end must be true, \
        so the digit dies wherever both ends are seen. An XY-Chain does \
        the same through bivalue cells: each cell passes its other digit \
        to the next, and if the chain's first and last cells both offer \
        the same digit Z, one of them is Z. The Skyscraper, Kite, and \
        Remote Pair are all short chains in disguise.
        """,
        steps: [
            "Strong link = a unit with exactly two spots (or a cell with exactly two candidates).",
            "Chain them: strong, weak, strong… starting and ending strong.",
            "Erase the chain's digit from every cell seeing both ends.",
        ]
    )

    static let uniqueness = TechniqueTopic(
        name: "Uniqueness Arguments",
        tagline: "The puzzle has one solution — exploit it",
        description: """
        Four cells on two rows, two columns, and two boxes that could all \
        reduce to the same two digits form a deadly rectangle: swapping \
        the pair would give a second solution. A proper puzzle can't \
        contain one, so whatever would create it is false. The Unique \
        Rectangle family reads this in many ways (extra candidates must \
        survive, roof cells can't take the pair); BUG+1 applies the same \
        idea board-wide: if placing one candidate would leave every cell \
        with two, that candidate must be true.
        """,
        steps: [
            "Watch for rectangles over exactly two boxes with matching pair candidates in the corners.",
            "Three bare-pair corners? The fourth sheds the pair (Type 1). Extras concentrated on one digit? It survives near the roof (Type 2).",
            "All cells down to pairs except one? BUG+1: the odd candidate out is true.",
        ]
    )

    static let alsFamily = TechniqueTopic(
        name: "ALS & Sue de Coq",
        tagline: "Sets one candidate short of locked",
        description: """
        An Almost Locked Set is k cells of a unit holding k+1 digits — one \
        elimination away from a naked subset. Tie two of them together \
        with a restricted common digit (one that can't be in both) and at \
        most one set can lose it: the other locks, and any digit common to \
        both dies where it sees every copy in both sets (ALS-XZ). Sue de \
        Coq does the same bookkeeping in a box–line intersection.
        """,
        steps: [
            "Bivalue cells are size-1 ALSs — every wing you know is secretly ALS logic.",
            "Find two cell groups (different units) each holding one digit more than their size.",
            "A shared digit whose copies all see each other is the link; other shared digits die where they see all copies in both groups.",
        ]
    )

    static let aicTopic = TechniqueTopic(
        name: "Alternating Inference Chains",
        tagline: "The general chain — every pattern's ancestor",
        description: """
        Chains over candidates: a strong link means "if not this, then \
        that" (a cell's other candidate, a digit's other spot); a weak \
        link means "if this, then not that". Alternate them, starting and \
        ending strong, and the chain proves its two ends can't both be \
        false. Anything incompatible with both ends is dead. X-Chains, \
        XY-Chains, wings, and remote pairs are all special cases — this \
        is the full instrument.
        """,
        steps: [
            "The coach draws these when it finds one: solid lines are strong links, dashed are weak.",
            "Read a chain as: NOT end A forces end B, step by step.",
            "Any candidate that a true end would kill — from either end — can be erased.",
        ]
    )

    static let forcingChains = TechniqueTopic(
        name: "Forcing Chains & Alts",
        tagline: "Test a candidate with a what-if sheet",
        description: """
        When patterns run out, follow the logic forward: assume a candidate, \
        propagate the consequences, and see what breaks or repeats. This is \
        exactly what the Alt button is for — a practice copy of the \
        real game where trial moves are sandboxed and every change is marked \
        (purple = trial digit, struck-through = eliminated note, green = new \
        note).
        """,
        steps: [
            "Pick a promising cell — ideally two candidates, in a crowded region. Add an Alt.",
            "Place one candidate as a trial digit. Its eliminations show struck through; when a cell is down to a single note, follow it with another trial placement.",
            "Contradiction (a cell with no candidates, or a unit that can't fit a digit)? The assumption was false — the other candidate is real. Discard the alts and play it in the real game.",
            "No contradiction? Add another Alt and test the other candidate. Any cell that resolves the same way in both branches is certain either way — play that.",
            "Every sheet branches from the real game, so flip between the chips to compare alternate paths side by side; remove a refuted branch with the trash button.",
        ]
    )
}
