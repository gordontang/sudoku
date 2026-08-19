import SudokuKit
import SwiftUI

/// The training home: the curriculum in ladder order with per-lesson
/// mastery, a suggested next lesson, and mixed practice across everything
/// the player has started.
struct TrainingView: View {
    @Environment(TrainingStore.self) private var store
    @State private var showResetConfirmation = false

    var body: some View {
        List {
            Section {
                if let next = Curriculum.nextLesson(given: store) {
                    NavigationLink(value: Route.lesson(next.id)) {
                        VStack(alignment: .leading, spacing: 4) {
                            Label(store.record(for: next.id).isStarted ? "Continue" : "Up next", systemImage: "graduationcap.fill")
                                .font(.headline)
                            Text("\(next.title) · \(next.tagline)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .accessibilityIdentifier("training_next")
                } else {
                    Label("Every lesson mastered — the whole ladder is yours.", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(Color.accentColor)
                }
                NavigationLink(value: Route.mixedPractice) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Mixed Practice", systemImage: "shuffle")
                            .font(.headline)
                        Text(store.startedCount == 0
                             ? "Positions from the first lessons, technique unnamed — spot the move yourself."
                             : "Positions from every lesson you've started, technique unnamed — spot the move yourself.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .accessibilityIdentifier("training_mixed")
            } footer: {
                Text("Each lesson: read the technique, step through a worked example, then find it yourself on real positions. Three clean finds — no hints, no misses — master a lesson.")
            }

            ForEach(Curriculum.sections) { section in
                Section(section.title) {
                    ForEach(section.lessons) { lesson in
                        NavigationLink(value: Route.lesson(lesson.id)) {
                            LessonRow(lesson: lesson, record: store.record(for: lesson.id))
                        }
                        .accessibilityIdentifier("lesson_\(lesson.techniques.first?.rawValue ?? 0)")
                    }
                }
            }

            if store.startedCount > 0 {
                Section {
                    Button("Reset Training Progress", role: .destructive) {
                        showResetConfirmation = true
                    }
                }
            }
        }
        .navigationTitle("Training")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Reset training progress?",
            isPresented: $showResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset", role: .destructive) { store.reset() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Every lesson goes back to unstarted.")
        }
    }
}

private struct LessonRow: View {
    let lesson: Lesson
    let record: LessonRecord

    var body: some View {
        HStack(spacing: 12) {
            MasteryRing(fraction: record.masteryFraction, isMastered: record.isMastered)
                .frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(lesson.title)
                Text(lesson.tagline)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if record.isMastered {
                Text("Mastered")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            } else if record.isStarted {
                Text("\(record.cleanSolves)/\(LessonRecord.masteryTarget)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var s = "\(lesson.title), \(lesson.tagline)"
        if record.isMastered {
            s += ", mastered"
        } else if record.isStarted {
            s += ", \(record.cleanSolves) of \(LessonRecord.masteryTarget) clean finds"
        }
        return s
    }
}

/// Progress toward mastery as a ring; a filled check once earned.
struct MasteryRing: View {
    let fraction: Double
    let isMastered: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.25), lineWidth: 3)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if isMastered {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .accessibilityHidden(true)
    }
}
