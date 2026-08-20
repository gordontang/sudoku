import SudokuKit
import SwiftData
import SwiftUI

enum Route: Hashable {
    case newGame(Difficulty)
    case resume
    case stats
    case settings
    case guide
    case training
    case lesson(String)
    case mixedPractice
}

struct HomeView: View {
    @Query private var savedGames: [SavedGame]
    @State private var path: [Route] = []
    @State private var trainingStore = TrainingStore()
    @AppStorage(SettingsKeys.appearance) private var appearanceRaw = AppearanceMode.auto.rawValue

    private var colorScheme: ColorScheme? {
        switch AppearanceMode(rawValue: appearanceRaw) ?? .auto {
        case .auto: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if let saved = savedGames.first {
                    Section {
                        NavigationLink(value: Route.resume) {
                            ResumeCard(saved: saved)
                        }
                    }
                }

                Section("New Game") {
                    ForEach(Difficulty.allCases) { difficulty in
                        NavigationLink(value: Route.newGame(difficulty)) {
                            HStack {
                                Text(difficulty.displayName)
                                Spacer()
                                difficultyDots(difficulty)
                            }
                        }
                    }
                }

                Section("Learn") {
                    NavigationLink(value: Route.training) {
                        TrainingCard(store: trainingStore)
                    }
                    .accessibilityIdentifier("training")
                }
            }
            .navigationTitle("Sudoku")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: Route.guide) {
                        Label("Techniques", systemImage: "book")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: Route.stats) {
                        Label("Statistics", systemImage: "chart.bar")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: Route.settings) {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
            .onAppear {
                // UI-test/screenshot hook: jump straight into a game.
                if ProcessInfo.processInfo.arguments.contains("-uitest-autostart"), path.isEmpty {
                    path.append(.newGame(.easy))
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .newGame(let difficulty):
                    GameView(mode: .new(difficulty))
                case .resume:
                    GameView(mode: .resume)
                case .stats:
                    StatsView()
                case .settings:
                    SettingsView()
                case .guide:
                    TechniqueGuideView()
                case .training:
                    TrainingView()
                case .lesson(let id):
                    if let lesson = Curriculum.lesson(id: id) {
                        LessonView(lesson: lesson, store: trainingStore)
                    }
                case .mixedPractice:
                    LessonView(mixedFrom: trainingStore)
                }
            }
        }
        .environment(trainingStore)
        .preferredColorScheme(colorScheme)
    }

    private func difficultyDots(_ difficulty: Difficulty) -> some View {
        HStack(spacing: 3) {
            ForEach(0..<5) { i in
                Circle()
                    .fill(i <= difficulty.rawValue ? Color.accentColor : Color.secondary.opacity(0.25))
                    .frame(width: 6, height: 6)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct TrainingCard: View {
    let store: TrainingStore

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "graduationcap.fill")
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 4) {
                Text("Training")
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var detail: String {
        let total = Curriculum.lessons.count
        if store.startedCount == 0 {
            return "Lessons and drills for every technique, singles to chains"
        }
        if store.masteredCount == total {
            return "All \(total) lessons mastered"
        }
        if let next = Curriculum.nextLesson(given: store) {
            return "\(store.masteredCount) of \(total) mastered · next: \(next.title)"
        }
        return "\(store.masteredCount) of \(total) mastered"
    }
}

private struct ResumeCard: View {
    let saved: SavedGame

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Continue", systemImage: "play.circle.fill")
                .font(.headline)
            Text("\(saved.difficulty.displayName) · \(saved.elapsedSeconds.timerString) · \(saved.mistakeCount) mistakes")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
