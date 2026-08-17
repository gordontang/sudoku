import SudokuKit
import SwiftUI

struct BoardView: View {
    @Bindable var vm: GameViewModel
    @AppStorage(SettingsKeys.highlightPeers) private var highlightPeers = true
    @AppStorage(SettingsKeys.highlightSameDigits) private var highlightSameDigits = true
    @AppStorage(SettingsKeys.highlightCoverage) private var highlightCoverage = true

    var body: some View {
        let digit = vm.isPaused ? 0 : activeDigit
        let covered = coveredCells(by: digit)
        let diff = vm.isPaused ? nil : vm.diffBaseState
        VStack(spacing: 0) {
            ForEach(0..<9, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<9, id: \.self) { col in
                        cell(row: row, col: col, activeDigit: digit, covered: covered, diff: diff)
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .background(Theme.boardBackground)
        .overlay(GridLines(major: false).stroke(Theme.gridLineMinor, lineWidth: 0.5))
        .overlay(GridLines(major: true).stroke(Theme.gridLineMajor, lineWidth: 2))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Sudoku board")
    }

    /// One board cell. Broken out of `body` with plain `let` bindings — the
    /// inlined version was a single expression too complex for the
    /// type-checker.
    private func cell(
        row: Int,
        col: Int,
        activeDigit: UInt8,
        covered: Set<Int>,
        // SudokuKit qualification: SwiftUI also declares a `Grid` view.
        diff: (values: SudokuKit.Grid, pencil: [CandidateSet])?
    ) -> some View {
        let index = row * 9 + col
        // Hide the position while paused — no free thinking time.
        let value: UInt8 = vm.isPaused ? 0 : vm.displayValues.cells[index]
        let marks: CandidateSet = vm.isPaused ? CandidateSet() : vm.displayPencil[index]
        // Diffs vs the sheet underneath, so eliminations stay visible (red)
        // and new marks read as green.
        var removed = CandidateSet()
        var added = CandidateSet()
        if let diff {
            if value == 0 {
                removed = diff.pencil[index].subtracting(marks)
            }
            added = marks.subtracting(diff.pencil[index])
        }
        let isTrial = diff != nil && value != 0 && vm.values.cells[index] == 0
        // Mistakes describe the real game, not a sheet.
        let isMistake = !vm.isPaused && vm.viewedLayer == nil && vm.mistakes.contains(index)
        return CellView(
            identifier: "cell_\(row)_\(col)",
            value: value,
            isGiven: vm.givens.cells[index] != 0,
            pencil: marks,
            highlightDigit: highlightSameDigits ? activeDigit : 0,
            pencilAdded: added,
            pencilRemoved: removed,
            isTrial: isTrial,
            background: background(for: index, activeDigit: activeDigit, covered: covered),
            isMistake: isMistake,
            isSelected: vm.selected == index
        ) {
            vm.cellTouched(index)
        }
    }

    /// The digit the player is working with: the selected cell's value, or
    /// the locked pad digit (number-first mode). An empty selection with no
    /// lock means no highlight — deliberately, so it never feels sticky.
    private var activeDigit: UInt8 {
        if let selected = vm.selected, vm.displayValues.cells[selected] != 0 {
            return vm.displayValues.cells[selected]
        }
        return vm.lockedDigit ?? 0
    }

    /// Every cell in a row or column already containing the digit — the places
    /// it can no longer go.
    private func coveredCells(by digit: UInt8) -> Set<Int> {
        guard highlightCoverage, digit != 0 else { return [] }
        var covered: Set<Int> = []
        for i in 0..<81 where vm.displayValues.cells[i] == digit {
            let row = i / 9, col = i % 9
            for k in 0..<9 {
                covered.insert(row * 9 + k)
                covered.insert(k * 9 + col)
            }
        }
        return covered
    }

    private func background(for index: Int, activeDigit: UInt8, covered: Set<Int>) -> Color {
        guard !vm.isPaused else { return .clear }
        if vm.flashCells.contains(index) {
            return Theme.cellSameDigit
        }
        if vm.viewedLayer == nil && vm.mistakes.contains(index) {
            return Theme.cellMistake
        }
        if index == vm.selected {
            return Theme.cellSelected
        }
        // Only placed digits tint the whole cell. A matching pencil mark is
        // indicated by the chip on the mark itself — tinting those cells too
        // (on top of coverage shading) drowned the board in highlights.
        if highlightSameDigits && activeDigit != 0 && vm.displayValues.cells[index] == activeDigit {
            return Theme.cellSameDigit
        }
        if let selected = vm.selected, highlightPeers, SudokuKit.Grid.peers[selected].contains(index) {
            return Theme.cellPeer
        }
        if covered.contains(index) {
            return Theme.cellPeer
        }
        return .clear
    }
}

private struct CellView: View {
    let identifier: String
    let value: UInt8
    let isGiven: Bool
    let pencil: CandidateSet
    let highlightDigit: UInt8
    /// Marks present here but not in the sheet underneath (chain view).
    let pencilAdded: CandidateSet
    /// Marks eliminated relative to the sheet underneath — still drawn,
    /// struck through and faded, so the chain's eliminations stay visible
    /// without reading as errors.
    let pencilRemoved: CandidateSet
    /// A hypothetical digit placed in a chain layer, not in the real game.
    let isTrial: Bool
    let background: Color
    let isMistake: Bool
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
            ZStack {
                Rectangle()
                    .fill(background)
                    .animation(.easeOut(duration: 0.4), value: background)
                if value != 0 {
                    Text("\(value)")
                        .font(.title3.weight(isGiven ? .bold : .regular))
                        .minimumScaleFactor(0.4)
                        .foregroundStyle(textColor)
                } else if !pencil.isEmpty || !pencilRemoved.isEmpty {
                    pencilGrid
                }
                if isMistake {
                    // Corner marker so mistakes read without color alone.
                    VStack {
                        HStack {
                            Spacer()
                            Circle()
                                .fill(Theme.mistakeText)
                                .frame(width: 5, height: 5)
                                .padding(2)
                        }
                        Spacer()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            // Select on touch-down, not touch-up — a Button waits for the
            // finger to lift, which reads as lag on a game board.
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isSelected { select() }
                    }
            )
            // One accessibility element per cell (the Button used to provide
            // this); otherwise each pencil-mark Text leaks out as a duplicate.
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction { select() }
            .accessibilityLabel(accessibilityText)
            .accessibilityIdentifier(identifier)
    }

    private var textColor: Color {
        if isMistake { return Theme.mistakeText }
        if isTrial { return Theme.trialText }
        return isGiven ? Theme.givenText : Theme.playerText
    }

    private var pencilGrid: some View {
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { c in
                        let digit = UInt8(r * 3 + c + 1)
                        let present = pencil.contains(digit: digit)
                        let removed = !present && pencilRemoved.contains(digit: digit)
                        let isHighlighted = present && digit == highlightDigit
                        Text(present || removed ? "\(digit)" : " ")
                            .font(.system(size: 9, weight: isHighlighted ? .bold : .regular))
                            .strikethrough(removed)
                            .minimumScaleFactor(0.5)
                            .foregroundStyle(markColor(
                                digit: digit, present: present, removed: removed,
                                isHighlighted: isHighlighted
                            ))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            // A filled chip so the matching note is findable at
                            // a glance, not just a bolder glyph.
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(isHighlighted ? Color.accentColor : Color.clear)
                                    .padding(0.5)
                            )
                    }
                }
            }
        }
        .padding(1)
    }

    // Only the player's own changes get styling — added marks green, removed
    // marks struck through. No "forced cell" emphasis: inside a hypothesis
    // the app shouldn't suggest which digits are right.
    private func markColor(
        digit: UInt8, present: Bool, removed: Bool, isHighlighted: Bool
    ) -> Color {
        if isHighlighted { return .white }
        if removed { return Theme.pencilRemovedText }
        if pencilAdded.contains(digit: digit) { return Theme.pencilAddedText }
        return Theme.pencilText
    }

    private var accessibilityText: String {
        var label = ""
        if value == 0 {
            label = pencil.isEmpty
                ? "empty"
                : "notes " + pencil.digits.map(String.init).joined(separator: ", ")
        } else {
            label = "contains \(value)"
            if isGiven { label += ", given" }
            if isMistake { label += ", incorrect" }
        }
        return label
    }
}

/// Board grid lines: minor cell separators or major box borders.
private struct GridLines: Shape {
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
