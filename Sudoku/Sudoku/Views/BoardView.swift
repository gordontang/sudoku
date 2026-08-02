import SudokuKit
import SwiftUI

struct BoardView: View {
    @Bindable var vm: GameViewModel
    @AppStorage(SettingsKeys.highlightPeers) private var highlightPeers = true
    @AppStorage(SettingsKeys.highlightSameDigits) private var highlightSameDigits = true

    var body: some View {
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
                            background: background(for: index),
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

    private func background(for index: Int) -> Color {
        guard !vm.isPaused else { return .clear }
        if vm.flashCells.contains(index) {
            return Theme.cellSameDigit
        }
        if vm.mistakes.contains(index) {
            return Theme.cellMistake
        }
        guard let selected = vm.selected else { return .clear }
        if index == selected {
            return Theme.cellSelected
        }
        let selectedDigit = vm.values.cells[selected]
        if highlightSameDigits && selectedDigit != 0 && vm.values.cells[index] == selectedDigit {
            return Theme.cellSameDigit
        }
        if highlightPeers && SudokuKit.Grid.peers[selected].contains(index) {
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
                        Text(pencil.contains(digit: digit) ? "\(digit)" : " ")
                            .font(.system(size: 9))
                            .minimumScaleFactor(0.5)
                            .foregroundStyle(Theme.pencilText)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
