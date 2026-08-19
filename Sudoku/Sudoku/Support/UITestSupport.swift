import Foundation
import SudokuKit

/// Hooks used only by the UI test suite, activated via launch arguments.
enum UITestSupport {
    static var isReset: Bool {
        ProcessInfo.processInfo.arguments.contains("-uitest-reset")
    }

    static var useFixedPuzzle: Bool {
        ProcessInfo.processInfo.arguments.contains("-uitest-fixed-puzzle")
    }

    /// A pre-generated Easy puzzle (SeededRNG seed 2026) so UI tests know the
    /// full solution. Cell r1c1 is empty and its answer is 8.
    static var fixedPuzzle: Puzzle {
        let givens = SudokuKit.Grid(string:
            "003560920006823000100900863070632054400000002230745080684007001000416300017098500")!
        let solution = SudokuKit.Grid(string:
            "843561927796823415152974863978632154465189732231745689684357291529416378317298546")!
        return Puzzle(givens: givens, solution: solution, difficulty: .easy)
    }

    /// Wipe persisted state for a clean test run. Call before the model
    /// container opens the store.
    static func resetIfRequested() {
        guard isReset else { return }
        let fm = FileManager.default
        if let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            for name in ["default.store", "default.store-shm", "default.store-wal"] {
                try? fm.removeItem(at: support.appendingPathComponent(name))
            }
        }
        for key in [
            SettingsKeys.mistakeMode,
            SettingsKeys.autoClearPencil,
            SettingsKeys.haptics,
            SettingsKeys.highlightPeers,
            SettingsKeys.errorLimitEnabled,
            SettingsKeys.highlightSameDigits,
            SettingsKeys.highlightCoverage,
            SettingsKeys.coverageMode,
            SettingsKeys.showLayerEliminations,
            SettingsKeys.showTimer,
            SettingsKeys.showScore,
            SettingsKeys.soundEffects,
            SettingsKeys.keepScreenOn,
            SettingsKeys.autoApplyAutoComplete,
            SettingsKeys.appearance,
            SettingsKeys.trainingProgress,
        ] {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
