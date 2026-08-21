import SwiftData
import SwiftUI

/// The app's first view: shows the loading screen while the store opens,
/// then crossfades into Home with the model container in place.
///
/// Opening the SwiftData store is the one piece of launch work that can
/// take a visible moment (first run creates it; updates can migrate it), and
/// `.modelContainer(for:)` would do it synchronously on the main thread while
/// the window sits blank. Here it runs off the main actor behind a screen
/// that is drawn immediately.
struct RootView: View {
    @State private var container: ModelContainer?
    @State private var failure: Error?
    @State private var attempt = 0
    @AppStorage(SettingsKeys.appearance) private var appearanceRaw = AppearanceMode.auto.rawValue

    /// Keep the screen up at least this long so a fast launch reads as a
    /// deliberate hand-off rather than a flicker.
    private static let minimumHold: Duration = .milliseconds(700)
    private static let crossfade: Animation = .easeInOut(duration: 0.35)

    private var colorScheme: ColorScheme? {
        switch AppearanceMode(rawValue: appearanceRaw) ?? .auto {
        case .auto: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var body: some View {
        ZStack {
            if let container {
                HomeView()
                    .modelContainer(container)
                    .transition(.opacity)
            } else {
                LaunchLoadingView(failure: failure) {
                    failure = nil
                    attempt += 1
                }
                .transition(.opacity)
            }
        }
        .task(id: attempt) { await open() }
        .preferredColorScheme(colorScheme)
    }

    private func open() async {
        guard container == nil else { return }
        let started = ContinuousClock.now
        do {
            let opened = try await AppStore.open()
            let elapsed = ContinuousClock.now - started
            if elapsed < Self.minimumHold {
                try? await Task.sleep(for: Self.minimumHold - elapsed)
            }
            withAnimation(Self.crossfade) { container = opened }
        } catch {
            failure = error
        }
    }
}

enum AppStore {
    /// Every model the app persists. `UITestSupport.resetIfRequested()` must
    /// run before the first call so a reset wipes the store before it opens.
    static let schema = Schema([SavedGame.self, CompletedGame.self])

    /// Opens (creating or migrating as needed) the on-disk store, off the
    /// main actor.
    static func open() async throws -> ModelContainer {
        try await Task.detached(priority: .userInitiated) {
            try ModelContainer(for: schema)
        }.value
    }
}
