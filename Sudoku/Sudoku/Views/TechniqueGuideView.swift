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
        TechniqueSection("Basics", [nakedSingle, hiddenSingle]),
        TechniqueSection("Intermediate", [lockedCandidates, nakedPair, hiddenPair, nakedTriple]),
        TechniqueSection("Advanced", [xWing, xyWing]),
        TechniqueSection("Master Territory", [forcingChains]),
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
            "Select a number (or tap one of its placements) to light up its coverage — rows and columns where it's already settled — and every cell where it's still penciled. Scan digits 1–9 this way.",
            "Hunt eliminations: Locked Candidates, then pairs and triples, then X-Wing and XY-Wing. After each elimination, re-sweep singles.",
            "Still stuck? That's chain territory — add a Layer and test a candidate (see Forcing Chains).",
        ]
    )

    static let nakedSingle = TechniqueTopic(
        name: "Naked Single",
        tagline: "A cell with only one candidate left",
        description: """
        When a cell's row, column, and box together contain eight different \
        digits, only one digit can still go there. With full pencil marks \
        these cells show a single note — place it immediately.
        """,
        steps: [
            "Scan for cells showing exactly one pencil mark.",
            "Place the digit; the eliminations it causes often create new naked singles.",
        ],
        example: TechniqueExample(
            values: "000000000000000000000000000000000000123406789000000000000000000000000000000000000",
            marks: [40: [5]],
            pattern: [40],
            keyDigits: [5],
            caption: "Row 5 already holds 1, 2, 3, 4, 6, 7, 8, and 9 — the middle cell can only be 5."
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
        """,
        steps: [
            "In a unit with several two- and three-candidate cells, test whether three of them cover only three digits in total.",
            "Erase those digits from the rest of the unit.",
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

    static let forcingChains = TechniqueTopic(
        name: "Forcing Chains & Layers",
        tagline: "Test a candidate with a what-if sheet",
        description: """
        When patterns run out, follow the logic forward: assume a candidate, \
        propagate the consequences, and see what breaks or repeats. This is \
        exactly what the Layer button is for — a translucent sheet over the \
        real game where trial moves are sandboxed and every change is marked \
        (orange = trial digit, struck-through = eliminated note, green = new \
        note, bold orange = a forced cell).
        """,
        steps: [
            "Pick a promising cell — ideally two candidates, in a crowded region. Add a Layer.",
            "Place one candidate as a trial digit. Its eliminations show struck through; follow any forced cells (bold orange) with more trial placements.",
            "Contradiction (a cell with no candidates, or a unit that can't fit a digit)? The assumption was false — the other candidate is real. Clear the layers and play it in the real game.",
            "No contradiction? Add another Layer and test the other candidate. Any cell that resolves the same way in both branches is certain either way — play that.",
            "Flip between the Game and layer chips to compare branches; peel sheets with the minus button as you backtrack.",
        ]
    )
}
