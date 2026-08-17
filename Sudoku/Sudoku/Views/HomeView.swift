import SudokuKit
import SwiftData
import SwiftUI

enum Route: Hashable {
    case newGame(Difficulty)
    case resume
    case stats
    case settings
    case guide
}

struct HomeView: View {
    @Query private var savedGames: [SavedGame]
    @State private var path: [Route] = []
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
                }
            }
        }
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
