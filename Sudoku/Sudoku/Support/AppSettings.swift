import Foundation

enum MistakeMode: String, CaseIterable, Identifiable {
    case instantSolution
    case instantConflict
    case onDemand

    var id: String { rawValue }

    var label: String {
        switch self {
        case .instantSolution: "Instant (vs. solution)"
        case .instantConflict: "Instant (conflicts only)"
        case .onDemand: "On demand"
        }
    }

    var detail: String {
        switch self {
        case .instantSolution: "Wrong digits are flagged the moment you place them."
        case .instantConflict: "Only digits that clash with a row, column, or box are flagged."
        case .onDemand: "No live feedback — tap Check to reveal errors."
        }
    }
}

/// What the coverage highlight shades when a number is active.
enum CoverageMode: String, CaseIterable, Identifiable {
    /// Rows, columns, and boxes of every placement of the digit.
    case allPlacements
    /// Only the selected cell's own row, column, and box.
    case selectedCell
    case off

    var id: String { rawValue }

    var label: String {
        switch self {
        case .allPlacements: "All placements"
        case .selectedCell: "Selected cell"
        case .off: "Off"
        }
    }
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case auto, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .auto: "Auto"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

enum SettingsKeys {
    static let mistakeMode = "mistakeMode"
    static let autoClearPencil = "autoClearPencil"
    static let haptics = "haptics"
    static let highlightPeers = "highlightPeers"
    static let errorLimitEnabled = "errorLimitEnabled"
    static let highlightSameDigits = "highlightSameDigits"
    static let highlightCoverage = "highlightCoverage" // legacy Bool, migrated to coverageMode
    static let coverageMode = "coverageMode"
    static let showLayerEliminations = "showLayerEliminations"
    static let showTimer = "showTimer"
    static let showScore = "showScore"
    static let soundEffects = "soundEffects"
    static let keepScreenOn = "keepScreenOn"
    static let autoApplyAutoComplete = "autoApplyAutoComplete"
    static let appearance = "appearance"
}

/// Read-side access to settings for non-View code. Views bind via @AppStorage
/// with the same keys.
enum AppSettings {
    static var mistakeMode: MistakeMode {
        MistakeMode(rawValue: UserDefaults.standard.string(forKey: SettingsKeys.mistakeMode) ?? "") ?? .instantSolution
    }

    static var autoClearPencil: Bool {
        UserDefaults.standard.object(forKey: SettingsKeys.autoClearPencil) as? Bool ?? true
    }

    static var hapticsEnabled: Bool {
        UserDefaults.standard.object(forKey: SettingsKeys.haptics) as? Bool ?? true
    }

    static var highlightPeers: Bool {
        UserDefaults.standard.object(forKey: SettingsKeys.highlightPeers) as? Bool ?? true
    }

    static var errorLimitEnabled: Bool {
        UserDefaults.standard.object(forKey: SettingsKeys.errorLimitEnabled) as? Bool ?? false
    }

    static var highlightSameDigits: Bool {
        UserDefaults.standard.object(forKey: SettingsKeys.highlightSameDigits) as? Bool ?? true
    }

    static var coverageMode: CoverageMode {
        if let raw = UserDefaults.standard.string(forKey: SettingsKeys.coverageMode),
           let mode = CoverageMode(rawValue: raw) {
            return mode
        }
        // Migrate the retired on/off toggle: an explicit "off" is preserved.
        if UserDefaults.standard.object(forKey: SettingsKeys.highlightCoverage) as? Bool == false {
            return .off
        }
        return .selectedCell
    }

    static var showLayerEliminations: Bool {
        UserDefaults.standard.object(forKey: SettingsKeys.showLayerEliminations) as? Bool ?? true
    }

    static var showTimer: Bool {
        UserDefaults.standard.object(forKey: SettingsKeys.showTimer) as? Bool ?? true
    }

    static var showScore: Bool {
        UserDefaults.standard.object(forKey: SettingsKeys.showScore) as? Bool ?? true
    }

    static var soundEffects: Bool {
        UserDefaults.standard.object(forKey: SettingsKeys.soundEffects) as? Bool ?? true
    }

    static var keepScreenOn: Bool {
        UserDefaults.standard.object(forKey: SettingsKeys.keepScreenOn) as? Bool ?? false
    }

    static var autoApplyAutoComplete: Bool {
        UserDefaults.standard.object(forKey: SettingsKeys.autoApplyAutoComplete) as? Bool ?? false
    }
}
