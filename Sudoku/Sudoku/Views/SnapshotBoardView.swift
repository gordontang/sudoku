import SudokuKit
import SwiftUI

/// A board that isn't a game: a fixed position with explicit notes, drawn
/// with the same highlight vocabulary as the live board. Game review shows
/// past moments on it; training drills take taps on it. Rendering scales to
/// whatever width it's given, so it works as a 360-pt review snapshot and a
/// full-width practice board alike.
struct SnapshotBoardView: View {
    let values: SudokuKit.Grid
    /// Original clues, drawn bold; other digits read as entries. Nil means
    /// every digit is a given.
    var givens: SudokuKit.Grid? = nil
    let marks: [CandidateSet]
    var annotations = BoardAnnotations()
    /// Notes drawn slashed — eliminations the pattern has made.
    var struck: Set<BoardAnnotations.Candidate> = []
    var selected: Int? = nil
    /// Accessibility identifier prefix for cells (`prefix_r_c`); nil hides
    /// the cells from accessibility as one decorative element.
    var identifierPrefix: String? = nil
    var onTap: ((Int) -> Void)? = nil

    /// The digit to spotlight: the selected cell's value, if any.
    private var activeDigit: UInt8 {
        guard let selected, values.cells[selected] != 0 else { return 0 }
        return values.cells[selected]
    }

    var body: some View {
        GeometryReader { geo in
            let cell = geo.size.width / 9
            VStack(spacing: 0) {
                ForEach(0..<9, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<9, id: \.self) { col in
                            cellView(row * 9 + col, size: cell)
                        }
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .background(Theme.boardBackground)
        .overlay(SnapshotGridLines(major: false).stroke(Theme.gridLineMinor, lineWidth: 0.5))
        .overlay(SnapshotGridLines(major: true).stroke(Theme.gridLineMajor, lineWidth: 1.5))
        .overlay {
            if !annotations.links.isEmpty {
                ChainLinksOverlay(links: annotations.links)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .accessibilityElement(children: identifierPrefix == nil ? .ignore : .contain)
        .accessibilityLabel(identifierPrefix == nil ? "Board" : "Practice board")
    }

    private func cellView(_ index: Int, size: CGFloat) -> some View {
        let value = values.cells[index]
        let isGiven = givens.map { $0.cells[index] != 0 } ?? true
        let content = ZStack {
            Rectangle().fill(background(index))
            if value != 0 {
                Text("\(value)")
                    .font(.system(size: size * 0.5, weight: isGiven ? .bold : .regular))
                    .minimumScaleFactor(0.4)
                    .foregroundStyle(isGiven ? Theme.givenText : Theme.playerText)
            } else if !marks[index].isEmpty {
                markGrid(index, marks: marks[index], size: size)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())

        return Group {
            if let onTap {
                content
                    // Touch-down selection, like the game board.
                    .gesture(DragGesture(minimumDistance: 0).onChanged { _ in
                        if selected != index { onTap(index) }
                    })
                    .accessibilityElement(children: .ignore)
                    .accessibilityAddTraits(selected == index ? [.isButton, .isSelected] : .isButton)
                    .accessibilityAction { onTap(index) }
                    .accessibilityLabel(accessibilityText(index))
                    .accessibilityIdentifier(identifierPrefix.map { "\($0)_\(index / 9)_\(index % 9)" } ?? "")
            } else {
                content
            }
        }
    }

    private func background(_ index: Int) -> Color {
        if index == selected { return Theme.cellSelected }
        switch annotations.cells[index] {
        case .pattern, .alternate: return Theme.cellSameDigit
        case .elimination: return Theme.cellMistake
        case .context, nil: break
        }
        if activeDigit != 0 && values.cells[index] == activeDigit {
            return Theme.cellSameDigit
        }
        if annotations.cells[index] == .context {
            return Theme.cellPeer
        }
        return .clear
    }

    private func markGrid(_ index: Int, marks: CandidateSet, size: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { c in
                        let digit = UInt8(r * 3 + c + 1)
                        let present = marks.contains(digit: digit)
                        let candidate = BoardAnnotations.Candidate(cell: index, digit: digit)
                        let role = annotations.candidates[candidate]
                        let isStruck = present && struck.contains(candidate)
                        let isHighlighted = present && digit == activeDigit && role == nil
                        Text(present ? "\(digit)" : " ")
                            .font(.system(size: size * 0.24, weight: role != nil || isHighlighted ? .bold : .regular))
                            .minimumScaleFactor(0.5)
                            .foregroundStyle(markColor(present: present, role: role, highlighted: isHighlighted))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(isHighlighted ? Color.accentColor : Color.clear)
                                    .padding(0.5)
                            )
                            .overlay {
                                if isStruck {
                                    SnapshotStrike()
                                        .stroke(Theme.mistakeText, lineWidth: 1.2)
                                        .padding(size * 0.06)
                                }
                            }
                    }
                }
            }
        }
        .padding(1)
    }

    private func markColor(present: Bool, role: BoardAnnotations.Role?, highlighted: Bool) -> Color {
        guard present else { return .clear }
        if highlighted { return .white }
        switch role {
        case .pattern: return Color.accentColor
        case .alternate: return Theme.annotationAlt
        case .elimination: return Theme.mistakeText
        case .context, nil: return Theme.pencilText
        }
    }

    private func accessibilityText(_ index: Int) -> String {
        let value = values.cells[index]
        if value != 0 {
            return "contains \(value)"
        }
        return marks[index].isEmpty
            ? "empty"
            : "notes " + marks[index].digits.map(String.init).joined(separator: ", ")
    }
}

/// Bottom-left to top-right slash over a struck note.
private struct SnapshotStrike: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

private struct SnapshotGridLines: Shape {
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
