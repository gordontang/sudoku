import SudokuKit
import SwiftUI

// MARK: - Guide view

/// In-game reference manual: solving techniques from singles to chains.
/// Presented as a sheet during play so it can be consulted mid-puzzle. The
/// content (`TechniqueGuide`) lives in SudokuKit, where its example boards
/// are checked against the real technique finders.
struct TechniqueGuideView: View {
    /// Shows a Done button when presented as a sheet.
    var isSheet = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(TechniqueGuide.sections) { section in
                Section(section.title) {
                    ForEach(section.topics) { topic in
                        // Pages are addressed by topic id so a presenter can
                        // deep-link (the coach's "Learn more") by seeding
                        // its navigation path with the id.
                        NavigationLink(value: topic.id) {
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
        .navigationDestination(for: String.self) { id in
            if let index = TechniqueGuide.allTopics.firstIndex(where: { $0.id == id }) {
                TechniqueDetailView(index: index, isSheet: isSheet)
            }
        }
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

/// One technique page, with Previous/Next to walk the whole ladder in
/// reading order without going back to the list.
private struct TechniqueDetailView: View {
    @State var index: Int
    var isSheet = false
    @Environment(\.dismiss) private var dismiss

    private var topic: TechniqueTopic { TechniqueGuide.allTopics[index] }
    private var previous: TechniqueTopic? {
        index > 0 ? TechniqueGuide.allTopics[index - 1] : nil
    }
    private var next: TechniqueTopic? {
        index + 1 < TechniqueGuide.allTopics.count ? TechniqueGuide.allTopics[index + 1] : nil
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Color.clear.frame(height: 0).id("top")
                    TechniqueTopicBody(topic: topic)
                }
                .padding(16)
                .padding(.bottom, 8)
            }
            .safeAreaInset(edge: .bottom) {
                pager
            }
            .onChange(of: index) {
                proxy.scrollTo("top", anchor: .top)
            }
        }
        .navigationTitle(topic.name)
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

    /// Previous / Next, each labelled with the neighbouring page's name.
    private var pager: some View {
        HStack(spacing: 12) {
            pagerButton(previous, systemImage: "chevron.left", edge: .leading, id: "guide_prev") {
                withAnimation(.easeInOut(duration: 0.2)) { index -= 1 }
            }
            pagerButton(next, systemImage: "chevron.right", edge: .trailing, id: "guide_next") {
                withAnimation(.easeInOut(duration: 0.2)) { index += 1 }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    @ViewBuilder
    private func pagerButton(
        _ target: TechniqueTopic?, systemImage: String, edge: HorizontalEdge, id: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if edge == .leading { Image(systemName: systemImage) }
                VStack(alignment: edge == .leading ? .leading : .trailing, spacing: 1) {
                    Text(edge == .leading ? "Previous" : "Next")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(target?.name ?? "")
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)
                }
                if edge == .trailing { Image(systemName: systemImage) }
            }
            .frame(maxWidth: .infinity, alignment: edge == .leading ? .leading : .trailing)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
        .disabled(target == nil)
        .opacity(target == nil ? 0 : 1)
        .accessibilityIdentifier(id)
        .accessibilityLabel(edge == .leading ? "Previous technique" : "Next technique")
        .accessibilityValue(target?.name ?? "")
    }
}

private extension Text {
    /// Guide copy uses light inline Markdown (*emphasis*); `Text(String)`
    /// shows the asterisks literally, so parse it.
    init(markdown: String) {
        let parsed = try? AttributedString(
            markdown: markdown,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )
        self.init(parsed ?? AttributedString(markdown))
    }
}

/// A topic's teaching content — description, example boards, and steps.
/// The guide shows it on its own page; a training lesson embeds it as the
/// "Learn" step.
struct TechniqueTopicBody: View {
    let topic: TechniqueTopic

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(markdown: topic.description)
                .font(.callout)

            ForEach(Array(topic.examples.enumerated()), id: \.offset) { _, example in
                VStack(alignment: .leading, spacing: 8) {
                    MiniBoardView(example: example)
                        .frame(maxWidth: 340)
                        .frame(maxWidth: .infinity)
                    Text(markdown: example.caption)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if !topic.steps.isEmpty {
                Text("How to use it")
                    .font(.headline)
                    .padding(.top, 4)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(topic.steps.enumerated()), id: \.offset) { i, step in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text("\(i + 1).")
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(Color.accentColor)
                            Text(markdown: step)
                                .font(.callout)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Mini board renderer

/// Draws an example board the way the game board draws coach annotations:
/// pattern cells tinted, pattern candidates in the accent colour, the
/// second polarity in orange, eliminations in red, chain links drawn
/// candidate to candidate.
private struct MiniBoardView: View {
    let example: TechniqueExample

    private var patternCells: Set<Int> { example.patternCells }
    private var eliminatedCells: Set<Int> { example.eliminatedCells }
    private var patternCandidates: Set<CandidateRef> { example.patternCandidates }
    private var alternateCandidates: Set<CandidateRef> { example.alternateCandidates }
    private var eliminatedCandidates: Set<CandidateRef> { example.eliminatedCandidates }

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
        .overlay {
            if !example.allLinks.isEmpty {
                ChainLinksOverlay(links: example.allLinks)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .accessibilityHidden(true)
    }

    private func cell(_ index: Int) -> some View {
        ZStack {
            Rectangle().fill(background(index))
            let value = example.values[index]
            if value != 0 {
                let isTrial = example.trials.contains(index)
                let isKey = example.keyDigits.contains(digit: value)
                Text("\(value)")
                    .font(.system(size: 15, weight: isKey || isTrial ? .bold : .regular))
                    .minimumScaleFactor(0.4)
                    .foregroundStyle(isTrial ? Theme.trialText : (isKey ? Color.accentColor : Theme.givenText))
            } else if let marks = example.marks[index] {
                markGrid(index, marks)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func background(_ index: Int) -> Color {
        if patternCells.contains(index) { return Theme.cellSameDigit }
        if eliminatedCells.contains(index) { return Theme.cellMistake }
        return .clear
    }

    private func markGrid(_ index: Int, _ marks: CandidateSet) -> some View {
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { c in
                        let digit = UInt8(r * 3 + c + 1)
                        let present = marks.contains(digit: digit)
                        let struck = example.struck[index]?.contains(digit: digit) == true
                        let (color, weight) = markStyle(index, digit, present: present)
                        Text(present ? "\(digit)" : " ")
                            .font(.system(size: 7, weight: weight))
                            .minimumScaleFactor(0.5)
                            .foregroundStyle(color)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .overlay {
                                if struck {
                                    MiniStrike()
                                        .stroke(Theme.mistakeText, lineWidth: 0.8)
                                        .padding(1.5)
                                }
                            }
                    }
                }
            }
        }
        .padding(1)
    }

    /// Colour and weight for one pencil mark, in the board's own vocabulary:
    /// eliminated red, pattern accent, alternate orange; key digits bold.
    private func markStyle(_ index: Int, _ digit: UInt8, present: Bool) -> (Color, Font.Weight) {
        guard present else { return (.clear, .regular) }
        let ref = CandidateRef(cell: index, digit: digit)
        if eliminatedCandidates.contains(ref) { return (Theme.mistakeText, .bold) }
        if patternCandidates.contains(ref) { return (Color.accentColor, .bold) }
        if alternateCandidates.contains(ref) { return (Theme.annotationAlt, .bold) }
        if example.keyDigits.contains(digit: digit) {
            if patternCells.contains(index) { return (Color.accentColor, .bold) }
            if eliminatedCells.contains(index) { return (Theme.mistakeText, .bold) }
            return (Theme.pencilText, .bold)
        }
        return (Theme.pencilText, .regular)
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

/// Bottom-left to top-right slash over a struck-out pencil mark.
private struct MiniStrike: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}
