import SudokuKit

/// One training lesson: a guide topic to read, plus the engine techniques it
/// drills. Lessons follow the technique ladder — the curriculum spine — but
/// group siblings the guide already teaches together (the two Kite/Turbot
/// variants, the three finned fish, the uniqueness family), so a lesson
/// matches one page of the guide and its practice draws from every
/// technique on that page.
struct Lesson: Identifiable, Hashable {
    let id: String
    let topic: TechniqueTopic
    let techniques: [Technique]

    var title: String { topic.name }
    var tagline: String { topic.tagline }
    /// The band of the lesson's easiest technique — where it sits on the
    /// ladder.
    var band: Difficulty { techniques.first?.band ?? .easy }

    init(_ topic: TechniqueTopic, _ techniques: [Technique]) {
        id = topic.id
        self.topic = topic
        self.techniques = techniques
    }

    static func == (lhs: Lesson, rhs: Lesson) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct LessonSection: Identifiable {
    let id: String
    let title: String
    let lessons: [Lesson]

    init(_ title: String, _ lessons: [Lesson]) {
        id = title
        self.title = title
        self.lessons = lessons
    }
}

enum Curriculum {
    static let sections: [LessonSection] = [
        LessonSection("Basics", [
            Lesson(TechniqueContent.fullHouse, [.fullHouse]),
            Lesson(TechniqueContent.nakedSingle, [.nakedSingle]),
            Lesson(TechniqueContent.hiddenSingle, [.hiddenSingle]),
        ]),
        LessonSection("Intermediate", [
            Lesson(TechniqueContent.lockedCandidates, [.lockedCandidates]),
            Lesson(TechniqueContent.nakedPair, [.nakedPair, .lockedPair]),
            Lesson(TechniqueContent.hiddenPair, [.hiddenPair]),
            Lesson(TechniqueContent.nakedTriple, [.nakedTriple, .lockedTriple]),
            Lesson(TechniqueContent.hiddenTriple, [.hiddenTriple]),
            Lesson(TechniqueContent.quadruples, [.nakedQuad, .hiddenQuad]),
        ]),
        LessonSection("Advanced", [
            Lesson(TechniqueContent.xWing, [.xWing]),
            Lesson(TechniqueContent.skyscraper, [.skyscraper]),
            Lesson(TechniqueContent.twoStringKite, [.twoStringKite, .turbotFish]),
            Lesson(TechniqueContent.emptyRectangle, [.emptyRectangle]),
            Lesson(TechniqueContent.xyWing, [.xyWing]),
        ]),
        LessonSection("Master Patterns", [
            Lesson(TechniqueContent.biggerFish, [.swordfish, .jellyfish]),
            Lesson(TechniqueContent.finnedFish, [.finnedXWing, .finnedSwordfish, .finnedJellyfish]),
            Lesson(TechniqueContent.xyzWing, [.xyzWing]),
            Lesson(TechniqueContent.wWing, [.wWing]),
            Lesson(TechniqueContent.remotePair, [.remotePair]),
            Lesson(TechniqueContent.uniqueness, [.uniqueRectangle, .hiddenRectangle, .avoidableRectangle, .bugPlusOne]),
            Lesson(TechniqueContent.coloring, [.simpleColors, .multiColors]),
            Lesson(TechniqueContent.xChains, [.xChain, .xyChain]),
            Lesson(TechniqueContent.alsFamily, [.alsXZ, .sueDeCoq]),
            Lesson(TechniqueContent.aicTopic, [.aic]),
        ]),
    ]

    static let lessons: [Lesson] = sections.flatMap(\.lessons)

    static func lesson(id: String) -> Lesson? {
        lessons.first { $0.id == id }
    }

    /// The lesson that teaches a technique (every technique has one).
    static func lesson(for technique: Technique) -> Lesson? {
        lessons.first { $0.techniques.contains(technique) }
    }

    /// The first lesson in ladder order that isn't mastered yet — what the
    /// training home suggests. Nil once everything is mastered.
    @MainActor
    static func nextLesson(given store: TrainingStore) -> Lesson? {
        lessons.first { !store.record(for: $0.id).isMastered }
    }
}
