import Foundation
import Observation

/// Per-lesson practice history. Mastery is earned by finding the pattern
/// unaided — a drill counts as clean when it's solved with no hints and no
/// wrong answers — and never lost: the record only accumulates.
struct LessonRecord: Codable, Equatable {
    var attempts = 0
    var cleanSolves = 0
    /// Consecutive clean solves, reset by any assisted or failed drill.
    var streak = 0
    var bestStreak = 0
    var lastPracticed: Date?
    /// Recently served drills (stable keys), so a lesson doesn't repeat the
    /// same position while fresher ones exist.
    var recentDrills: [String] = []

    static let masteryTarget = 3

    var isMastered: Bool { cleanSolves >= Self.masteryTarget }
    var isStarted: Bool { attempts > 0 }
    /// 0…1 toward mastery.
    var masteryFraction: Double {
        min(1, Double(cleanSolves) / Double(Self.masteryTarget))
    }
}

/// How one drill ended.
enum DrillOutcome {
    /// Found without hints or wrong answers.
    case clean
    /// Found, but only after a hint or a miss.
    case assisted
    /// The answer was revealed or the drill skipped.
    case revealed
}

/// Training progress for every lesson, persisted as one JSON blob in
/// UserDefaults — small, migration-free, and readable from any screen.
@MainActor
@Observable
final class TrainingStore {
    private(set) var records: [String: LessonRecord] = [:]
    private let defaults: UserDefaults

    static let recentDrillLimit = 12

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: SettingsKeys.trainingProgress),
           let decoded = try? JSONDecoder().decode([String: LessonRecord].self, from: data) {
            records = decoded
        }
    }

    func record(for lessonID: String) -> LessonRecord {
        records[lessonID] ?? LessonRecord()
    }

    var masteredCount: Int {
        Curriculum.lessons.count { record(for: $0.id).isMastered }
    }

    var startedCount: Int {
        Curriculum.lessons.count { record(for: $0.id).isStarted }
    }

    /// Record a finished drill against its lesson.
    func record(_ outcome: DrillOutcome, lessonID: String, drillKey: String) {
        var r = record(for: lessonID)
        r.attempts += 1
        r.lastPracticed = Date()
        switch outcome {
        case .clean:
            r.cleanSolves += 1
            r.streak += 1
            r.bestStreak = max(r.bestStreak, r.streak)
        case .assisted, .revealed:
            r.streak = 0
        }
        r.recentDrills.append(drillKey)
        if r.recentDrills.count > Self.recentDrillLimit {
            r.recentDrills.removeFirst(r.recentDrills.count - Self.recentDrillLimit)
        }
        records[lessonID] = r
        save()
    }

    func reset() {
        records = [:]
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(records) {
            defaults.set(data, forKey: SettingsKeys.trainingProgress)
        }
    }
}
