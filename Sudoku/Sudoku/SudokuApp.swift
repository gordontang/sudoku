import SwiftData
import SwiftUI

@main
struct SudokuApp: App {
    init() {
        UITestSupport.resetIfRequested()
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        .modelContainer(for: [SavedGame.self, CompletedGame.self])
    }
}
