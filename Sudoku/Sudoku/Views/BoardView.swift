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
        VStack(spacing: 0) {
            ForEach(0..<9, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<9, id: \.self) { col in
                        let index = row * 9 + col
                        CellView(
                            identifier: "cell_\(row)_\(col)",
                            // Hide the position while paused — no free thinking time.
                            value: vm.isPaused ? 0 : vm.values.cells[index],
                            isGiven: vm.givens.cells[index] != 0,
                            pencil: vm.isPaused ? CandidateSet() : vm.pencil[index],
                            highlightDigit: highlightSameDigits ? digit : 0,
                            background: background(for: index, activeDigit: digit, covered: covered),
                            isMistake: !vm.isPaused && vm.mistakes.contains(index),
                            isSelected: vm.selected == index
                        ) {
                            vm.cellTouched(index)
                        }
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

    /// The digit the player is working with: the selected cell's value, or in
    /// number-first mode the locked pad digit.
    private var activeDigit: UInt8 {
        if let selected = vm.selected, vm.values.cells[selected] != 0 {
            return vm.values.cells[selected]
        }
        return vm.lockedDigit ?? 0
    }

    /// Every cell in a row or column already containing the digit — the places
    /// it can no longer go.
    private func coveredCells(by digit: UInt8) -> Set<Int> {
        guard highlightCoverage, digit != 0 else { return [] }
        var covered: Set<Int> = []
        for i in 0..<81 where vm.values.cells[i] == digit {
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
        if vm.mistakes.contains(index) {
            return Theme.cellMistake
        }
        if index == vm.selected {
            return Theme.cellSelected
        }
        if highlightSameDigits && activeDigit != 0 {
            if vm.values.cells[index] == activeDigit {
                return Theme.cellSameDigit
            }
            if vm.values.cells[index] == 0 && vm.pencil[index].contains(digit: activeDigit) {
                return Theme.cellSameDigit
            }
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
                } else if !pencil.isEmpty {
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
        return isGiven ? Theme.givenText : Theme.playerText
    }

    private var pencilGrid: some View {
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { c in
                        let digit = UInt8(r * 3 + c + 1)
                        let isHighlighted = digit == highlightDigit && pencil.contains(digit: digit)
                        Text(pencil.contains(digit: digit) ? "\(digit)" : " ")
                            .font(.system(size: 9, weight: isHighlighted ? .bold : .regular))
                            .minimumScaleFactor(0.5)
                            .foregroundStyle(isHighlighted ? .white : Theme.pencilText)
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
