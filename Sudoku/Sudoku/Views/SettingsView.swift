import SwiftUI

struct SettingsView: View {
    @AppStorage(SettingsKeys.mistakeMode) private var mistakeModeRaw = MistakeMode.instantSolution.rawValue
    @AppStorage(SettingsKeys.autoClearPencil) private var autoClearPencil = true
    @AppStorage(SettingsKeys.haptics) private var haptics = true
    @AppStorage(SettingsKeys.highlightPeers) private var highlightPeers = true
    @AppStorage(SettingsKeys.errorLimitEnabled) private var errorLimitEnabled = false
    @AppStorage(SettingsKeys.highlightSameDigits) private var highlightSameDigits = true
    @AppStorage(SettingsKeys.highlightCoverage) private var highlightCoverage = true
    @AppStorage(SettingsKeys.showTimer) private var showTimer = true
    @AppStorage(SettingsKeys.showScore) private var showScore = true
    @AppStorage(SettingsKeys.soundEffects) private var soundEffects = true
    @AppStorage(SettingsKeys.keepScreenOn) private var keepScreenOn = false
    @AppStorage(SettingsKeys.autoApplyAutoComplete) private var autoApplyAutoComplete = false
    @AppStorage(SettingsKeys.appearance) private var appearanceRaw = AppearanceMode.auto.rawValue

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Appearance", selection: $appearanceRaw) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.label).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                Toggle("Show timer", isOn: $showTimer)
                Toggle("Show score", isOn: $showScore)
            }

            Section {
                Picker("Mistake feedback", selection: $mistakeModeRaw) {
                    ForEach(MistakeMode.allCases) { mode in
                        Text(mode.label).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("Mistake Feedback")
            } footer: {
                Text(MistakeMode(rawValue: mistakeModeRaw)?.detail ?? "")
            }

            Section {
                Toggle("Limit to \(GameViewModel.errorLimit) mistakes", isOn: $errorLimitEnabled)
            } footer: {
                Text("The game ends after \(GameViewModel.errorLimit) mistakes and is recorded as a loss.")
            }

            Section {
                Toggle("Auto-clear pencil marks", isOn: $autoClearPencil)
                Toggle("Highlight row, column & box", isOn: $highlightPeers)
                Toggle("Highlight same numbers", isOn: $highlightSameDigits)
                Toggle("Highlight covered rows & columns", isOn: $highlightCoverage)
                Toggle("Apply auto-complete instantly", isOn: $autoApplyAutoComplete)
                Toggle("Keep screen awake", isOn: $keepScreenOn)
            } header: {
                Text("Gameplay")
            } footer: {
                Text("Long-press a number on the pad to lock it, then tap cells to place it repeatedly. When covered rows & columns are highlighted, selecting a number shades everywhere it can no longer go. When auto-complete applies instantly, the endgame fills itself the moment it's all forced moves.")
            }

            Section("Sound & Haptics") {
                Toggle("Sound effects", isOn: $soundEffects)
                Toggle("Haptic feedback", isOn: $haptics)
            }
        }
        .navigationTitle("Settings")
    }
}
