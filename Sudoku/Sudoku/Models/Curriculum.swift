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
            Lesson(TechniqueGuide.fullHouse, [.fullHouse]),
            Lesson(TechniqueGuide.nakedSingle, [.nakedSingle]),
            Lesson(TechniqueGuide.hiddenSingle, [.hiddenSingle]),
        ]),
        LessonSection("Intermediate", [
            Lesson(TechniqueGuide.lockedCandidates, [.lockedCandidates]),
            Lesson(TechniqueGuide.nakedPair, [.nakedPair, .lockedPair]),
            Lesson(TechniqueGuide.hiddenPair, [.hiddenPair]),
            Lesson(TechniqueGuide.nakedTriple, [.nakedTriple, .lockedTriple]),
            Lesson(TechniqueGuide.hiddenTriple, [.hiddenTriple]),
            Lesson(TechniqueGuide.quadruples, [.nakedQuad, .hiddenQuad]),
        ]),
        LessonSection("Advanced", [
            Lesson(TechniqueGuide.xWing, [.xWing]),
            Lesson(TechniqueGuide.skyscraper, [.skyscraper]),
            Lesson(TechniqueGuide.twoStringKite, [.twoStringKite, .turbotFish]),
            Lesson(TechniqueGuide.emptyRectangle, [.emptyRectangle]),
            Lesson(TechniqueGuide.xyWing, [.xyWing]),
        ]),
        LessonSection("Master Patterns", [
            Lesson(TechniqueGuide.biggerFish, [.swordfish, .jellyfish]),
            Lesson(TechniqueGuide.finnedFish, [.finnedXWing, .finnedSwordfish, .finnedJellyfish]),
            Lesson(TechniqueGuide.xyzWing, [.xyzWing]),
            Lesson(TechniqueGuide.wWing, [.wWing]),
            Lesson(TechniqueGuide.remotePair, [.remotePair]),
            Lesson(TechniqueGuide.uniqueness, [.uniqueRectangle, .hiddenRectangle, .avoidableRectangle, .bugPlusOne]),
            Lesson(TechniqueGuide.coloring, [.simpleColors, .multiColors]),
            Lesson(TechniqueGuide.xChains, [.xChain, .xyChain]),
            Lesson(TechniqueGuide.alsFamily, [.alsXZ, .sueDeCoq]),
            Lesson(TechniqueGuide.aicTopic, [.aic]),
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
