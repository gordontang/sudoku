import SwiftUI

@main
struct SudokuApp: App {
    init() {
        UITestSupport.resetIfRequested()
    }

    var body: some Scene {
        WindowGroup {
            // RootView opens the model container behind a loading screen and
            // injects it once ready; nothing above it touches SwiftData.
            RootView()
        }
    }
}
