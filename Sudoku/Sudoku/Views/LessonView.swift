import SudokuKit
import SwiftUI

/// The lesson player: Learn (the guide topic) → Example (a real position,
/// revealed the way the coach would) → Practice (find it yourself) →
/// Summary. Mixed practice reuses the practice half with the technique's
/// name withheld.
struct LessonView: View {
    @State private var session: DrillSession
    @Environment(\.dismiss) private var dismiss

    init(lesson: Lesson, store: TrainingStore) {
        _session = State(initialValue: DrillSession(lesson: lesson, store: store))
    }

    init(mixedFrom store: TrainingStore) {
        _session = State(initialValue: DrillSession(mixedFrom: store))
    }

    var body: some View {
        VStack(spacing: 0) {
            if !session.isMixed {
                phasePicker
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }
            switch session.phase {
            case .learn:
                LearnPhase(session: session)
            case .example:
                ExamplePhase(session: session)
            case .practice:
                PracticePhase(session: session)
            case .summary:
                SummaryPhase(session: session, done: { dismiss() })
            }
        }
        .navigationTitle(session.lesson?.title ?? "Mixed Practice")
        .navigationBarTitleDisplayMode(.inline)
        .task { session.start() }
        .onDisappear { session.stop() }
    }

    private var phasePicker: some View {
        Picker("Step", selection: Binding(
            get: { session.phase == .summary ? .practice : session.phase },
            set: { session.goTo($0) }
        )) {
            Text("Learn").tag(DrillSession.Phase.learn)
            Text("Example").tag(DrillSession.Phase.example)
            Text("Practice").tag(DrillSession.Phase.practice)
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("lesson_phase")
    }
}

// MARK: - Learn

private struct LearnPhase: View {
    @Bindable var session: DrillSession

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let lesson = session.lesson {
                    TechniqueTopicBody(topic: lesson.topic)
                    if lesson.techniques.count > 1 {
                        Text("Practice draws from: " + lesson.techniques.map(\.displayName).joined(separator: ", ") + ".")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Button {
                    session.goTo(.example)
                } label: {
                    Text("See it on a real board")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("lesson_to_example")
            }
            .padding(16)
        }
    }
}

// MARK: - Worked example

private struct ExamplePhase: View {
    @Bindable var session: DrillSession

    var body: some View {
        VStack(spacing: 12) {
            if let example = session.example {
                SnapshotBoardView(
                    values: session.exampleGrid,
                    givens: example.givens,
                    marks: session.showsNotes ? example.candidates : Array(repeating: CandidateSet(), count: 81),
                    annotations: session.exampleAnnotations
                )
                .padding(.horizontal, 8)
            } else {
                ContentUnavailableView("No example available", systemImage: "square.grid.3x3")
            }

            ScrollView {
                Text(session.exampleText)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 12)
                    .accessibilityIdentifier("example_text")
            }

            HStack(spacing: 6) {
                ForEach(0..<DrillSession.exampleSteps, id: \.self) { i in
                    Circle()
                        .fill(i <= session.exampleStep ? Color.accentColor : Color.secondary.opacity(0.25))
                        .frame(width: 7, height: 7)
                }
            }
            .accessibilityHidden(true)

            HStack(spacing: 12) {
                Button("Back") { session.exampleBack() }
                    .buttonStyle(.bordered)
                    .disabled(session.exampleStep == 0)
                    .accessibilityIdentifier("example_back")
                Button(session.exampleStep < DrillSession.exampleSteps - 1 ? "Reveal more" : "Practice it") {
                    session.exampleNext()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("example_next")
            }
            .padding(.bottom, 12)
        }
        .padding(.top, 8)
    }
}

// MARK: - Practice

private struct PracticePhase: View {
    @Bindable var session: DrillSession

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(session.progressText)
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .accessibilityIdentifier("drill_progress")
                Spacer()
                if let d = session.deduction, !session.isMixed || session.hintTier >= .technique {
                    Text(d.technique.displayName)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                }
            }
            .padding(.horizontal, 16)

            if let drill = session.current {
                Text(session.prompt)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .accessibilityIdentifier("drill_prompt")

                SnapshotBoardView(
                    values: session.displayGrid,
                    givens: drill.givens,
                    marks: session.showsNotes ? drill.candidates : Array(repeating: CandidateSet(), count: 81),
                    annotations: session.annotations,
                    struck: session.struck,
                    selected: session.selected,
                    identifierPrefix: "drill",
                    onTap: { session.selectCell($0) }
                )
                .padding(.horizontal, 8)

                feedbackBanner

                DrillPad(enabled: !session.isSolved) { session.tapDigit($0) }
                    .padding(.horizontal, 8)

                controls
            } else if session.isLoading {
                Spacer()
                ContentUnavailableView(
                    "Nothing to practice",
                    systemImage: "square.grid.3x3",
                    description: Text(session.feedback?.text ?? "")
                )
                Spacer()
            } else {
                Spacer()
                ProgressView("Loading drills…")
                Spacer()
            }
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var feedbackBanner: some View {
        if let feedback = session.feedback {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: icon(for: feedback))
                    .foregroundStyle(color(for: feedback))
                ScrollView {
                    Text(feedback.text)
                        .font(.footnote)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 64)
            }
            .padding(10)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 12)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("drill_feedback")
        } else {
            // Reserve the space so the board doesn't jump when feedback appears.
            Color.clear.frame(height: 30)
        }
    }

    private func icon(for f: DrillSession.Feedback) -> String {
        switch f {
        case .neutral: "graduationcap.fill"
        case .success: "checkmark.circle.fill"
        case .miss: "xmark.circle.fill"
        }
    }

    private func color(for f: DrillSession.Feedback) -> Color {
        switch f {
        case .neutral: Color.accentColor
        case .success: .green
        case .miss: Theme.mistakeText
        }
    }

    private var controls: some View {
        HStack(spacing: 12) {
            if session.isSolved {
                Button {
                    session.advance()
                } label: {
                    Text(session.isLastDrill ? "Finish" : "Next drill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("drill_next")
            } else {
                Button {
                    session.hint()
                } label: {
                    Label(hintLabel, systemImage: "lightbulb")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .disabled(!session.canHint)
                .accessibilityIdentifier("drill_hint")
                Button {
                    session.reveal()
                } label: {
                    Label("Show answer", systemImage: "eye")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("drill_reveal")
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private var hintLabel: String {
        switch session.hintTier {
        case .none: session.isMixed ? "Hint" : "Where to look"
        case .technique: "Where to look"
        case .location: "Show pattern"
        case .pattern, .answer: "Show answer"
        }
    }
}

/// A plain 1–9 pad: no remaining-counts, no locking — one tap, one answer.
private struct DrillPad: View {
    let enabled: Bool
    let tap: (UInt8) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...9, id: \.self) { digit in
                Button {
                    tap(UInt8(digit))
                } label: {
                    Text("\(digit)")
                        .font(.title2.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.secondarySystemBackground)))
                }
                .buttonStyle(.plain)
                .disabled(!enabled)
                .opacity(enabled ? 1 : 0.4)
                .accessibilityLabel("Digit \(digit)")
                .accessibilityIdentifier("drill_digit_\(digit)")
            }
        }
    }
}

// MARK: - Summary

private struct SummaryPhase: View {
    @Bindable var session: DrillSession
    @Environment(TrainingStore.self) private var store
    let done: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                let record = session.lesson.map { store.record(for: $0.id) }
                if let record {
                    MasteryRing(fraction: record.masteryFraction, isMastered: record.isMastered)
                        .frame(width: 72, height: 72)
                        .padding(.top, 24)
                    Text(record.isMastered ? "Mastered" : "\(record.cleanSolves) of \(LessonRecord.masteryTarget) clean finds")
                        .font(.title3.weight(.semibold))
                        .accessibilityIdentifier("summary_mastery")
                } else {
                    Image(systemName: "shuffle")
                        .font(.system(size: 40))
                        .foregroundStyle(Color.accentColor)
                        .padding(.top, 24)
                    Text("Mixed practice complete")
                        .font(.title3.weight(.semibold))
                }

                HStack(spacing: 24) {
                    stat("Clean", session.cleanCount, "checkmark.circle.fill", .green)
                    stat("With help", session.assistedCount, "lightbulb.fill", .yellow)
                    stat("Revealed", session.revealedCount, "eye.fill", .secondary)
                }
                .padding(.vertical, 8)

                Text(summaryLine)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 24)

                VStack(spacing: 12) {
                    Button {
                        session.practiceAgain()
                    } label: {
                        Text("Practice again")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("summary_again")
                    Button {
                        done()
                    } label: {
                        Text("Done")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("summary_done")
                }
                .padding(.horizontal, 32)
            }
        }
    }

    private var summaryLine: String {
        if session.cleanCount == DrillSession.drillsPerSession {
            return "Every pattern found unaided. That's the eye the coach expects in a real game."
        }
        if session.revealedCount == DrillSession.drillsPerSession {
            return "Nothing found yet — that's what the worked example is for. Step through it again and watch where the pattern sits."
        }
        return "Only unaided finds count toward mastery. Hints are free here; in a game, ask the coach for the same ladder."
    }

    private func stat(_ title: String, _ value: Int, _ symbol: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: symbol)
                .foregroundStyle(color)
            Text("\(value)")
                .font(.title2.weight(.semibold))
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 70)
        .accessibilityElement(children: .combine)
    }
}
