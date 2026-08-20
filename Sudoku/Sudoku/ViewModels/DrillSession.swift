import Foundation
import SudokuKit

/// One training session: read the lesson, step through a worked example,
/// then find the pattern yourself on real positions. Mixed practice skips
/// the reading and withholds the technique's name — recognition, not recall.
///
/// A drill is "clean" when the pattern is found with no hints and no wrong
/// answers; three clean finds master a lesson. Hints escalate exactly like
/// the in-game coach (where to look → the pattern → the resolution), so
/// what's practiced here is what the coach will later expect.
@MainActor
@Observable
final class DrillSession {
    enum Phase: Int, Comparable {
        case learn
        case example
        case practice
        case summary

        static func < (lhs: Phase, rhs: Phase) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    enum Feedback: Equatable {
        case neutral(String)
        case success(String)
        case miss(String)

        var text: String {
            switch self {
            case .neutral(let s), .success(let s), .miss(let s): s
            }
        }
    }

    /// The reveal ladder for the current drill. Mixed practice adds the
    /// technique's name as a first rung, since it isn't given up front.
    enum HintTier: Int, Comparable {
        case none = 0
        case technique
        case location
        case pattern
        case answer

        static func < (lhs: HintTier, rhs: HintTier) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    static let drillsPerSession = 3
    /// The worked example's reveal steps: name → where → pattern → resolution.
    static let exampleSteps = 4

    /// Nil for mixed practice.
    let lesson: Lesson?
    /// Techniques drilled this session.
    let techniques: [Technique]
    private let store: TrainingStore

    private(set) var phase: Phase
    var isMixed: Bool { lesson == nil }
    /// Whether the board shows the solver's notes. Singles are practiced
    /// bare — scanning for them without notes is the whole skill.
    var showsNotes: Bool {
        isMixed || (lesson?.band ?? .easy) > .easy
    }

    // MARK: Worked example

    private(set) var example: Drill?
    private(set) var exampleDeduction: Deduction?
    private(set) var exampleStep = 0

    // MARK: Practice

    private(set) var drillIndex = 0
    private(set) var current: Drill?
    private(set) var deduction: Deduction?
    private var accepted = DrillAnswerSet()
    var selected: Int?
    private(set) var annotations = BoardAnnotations()
    /// The board as displayed: the drill position, plus a placement the
    /// player just made.
    private(set) var displayGrid = Grid()
    /// Candidates the player has struck (correct eliminations), drawn slashed.
    private(set) var struck: Set<BoardAnnotations.Candidate> = []
    private(set) var feedback: Feedback?
    private(set) var hintTier: HintTier = .none
    private(set) var misses = 0
    private(set) var isSolved = false
    private(set) var results: [DrillOutcome] = []
    private(set) var isLoading = false

    private var queue: [Drill] = []
    private var miner: Task<Void, Never>?

    // MARK: - Init

    init(lesson: Lesson, store: TrainingStore) {
        self.lesson = lesson
        self.techniques = lesson.techniques
        self.store = store
        phase = .learn
    }

    /// Mixed practice over every technique the player has started (or the
    /// first few lessons when nothing has been), technique names withheld.
    init(mixedFrom store: TrainingStore) {
        lesson = nil
        let started = Curriculum.lessons.filter { store.record(for: $0.id).isStarted }
        let pool = started.isEmpty ? Array(Curriculum.lessons.prefix(4)) : started
        techniques = pool.flatMap(\.techniques)
        self.store = store
        phase = .practice
    }

    // MARK: - Lifecycle

    /// Load the worked example and the first batch of drills. Instant from
    /// the shipped bank; a background miner then adds fresh positions.
    func start() {
        guard current == nil, example == nil else { return }
        if let lesson {
            example = DrillSupply.example(for: lesson)
            exampleDeduction = example?.deduction
        }
        loadQueue()
        if phase == .practice { nextDrill() }
    }

    func stop() {
        miner?.cancel()
        miner = nil
    }

    private func loadQueue() {
        var recent: Set<String> = []
        for t in techniques {
            if let l = Curriculum.lesson(for: t) {
                recent.formUnion(store.record(for: l.id).recentDrills)
            }
        }
        queue = DrillSupply.bankDrills(for: techniques, avoiding: recent, count: Self.drillsPerSession)
        // Fresh positions arrive asynchronously and replace bank drills the
        // player hasn't reached yet — the bank is a floor, not the ceiling.
        let techniques = self.techniques
        miner?.cancel()
        miner = Task { [weak self] in
            let mined = await DrillSupply.mine(techniques: techniques, count: Self.drillsPerSession)
            guard !Task.isCancelled, let self, !mined.isEmpty else { return }
            self.absorb(mined)
        }
    }

    private func absorb(_ fresh: [Drill]) {
        // Keep whatever hasn't been served yet, but prefer fresh drills.
        var merged = fresh
        for d in queue where !merged.contains(d) { merged.append(d) }
        queue = merged
    }

    // MARK: - Phases

    func goTo(_ phase: Phase) {
        guard phase != self.phase else { return }
        self.phase = phase
        if phase == .practice && current == nil {
            nextDrill()
        }
    }

    // MARK: - Worked example

    var exampleAnnotations: BoardAnnotations {
        guard let d = exampleDeduction else { return BoardAnnotations() }
        switch exampleStep {
        case 0: return BoardAnnotations()
        case 1: return BoardAnnotations(deduction: d, reveal: .location)
        case 2: return BoardAnnotations(deduction: d, reveal: .pattern)
        default: return BoardAnnotations(deduction: d, reveal: .full)
        }
    }

    var exampleText: String {
        guard let d = exampleDeduction else {
            return "No worked example is available for this lesson yet."
        }
        switch exampleStep {
        case 0:
            return "This position holds a \(d.technique.displayName) — and nothing simpler applies. Step through how the coach would reveal it."
        case 1:
            return CoachPhrasing.locationHint(for: d)
        case 2:
            return "These cells form the \(d.technique.displayName). Before revealing the answer, ask: what does the pattern let you place or remove?"
        default:
            return d.explanation
        }
    }

    /// The example's board: after the final step, a placement is shown made.
    var exampleGrid: Grid {
        guard let ex = example else { return Grid() }
        var g = ex.grid
        if exampleStep >= Self.exampleSteps - 1, case .place(let cell, let digit)? = exampleDeduction?.kind {
            g.cells[cell] = digit
        }
        return g
    }

    func exampleNext() {
        if exampleStep < Self.exampleSteps - 1 {
            exampleStep += 1
        } else {
            goTo(.practice)
        }
    }

    func exampleBack() {
        if exampleStep > 0 { exampleStep -= 1 }
    }

    // MARK: - Practice: drill flow

    /// What the current drill asks for.
    var wantsPlacement: Bool {
        if case .place? = deduction?.kind { return true }
        return false
    }

    var prompt: String {
        guard let d = deduction else { return "" }
        let name = isMixed && hintTier < .technique ? "next move" : d.technique.displayName
        if wantsPlacement {
            return isMixed && hintTier < .technique
                ? "The next move places a digit. Tap the cell, then the digit."
                : "Find the \(name): tap the cell it fills, then the digit."
        }
        return isMixed && hintTier < .technique
            ? "The next move crosses out a candidate. Tap a cell, then the digit to rule out."
            : "Find the \(name): tap a cell, then a candidate it lets you cross out."
    }

    var canHint: Bool { !isSolved && hintTier < .answer }
    var canAdvance: Bool { isSolved }
    var isLastDrill: Bool { drillIndex >= Self.drillsPerSession }
    var progressText: String { "Drill \(min(drillIndex, Self.drillsPerSession)) of \(Self.drillsPerSession)" }

    /// A stable key for "recently served" bookkeeping.
    nonisolated static func key(for drill: Drill) -> String {
        String(TrainingEngine.encode(drill).prefix(81)) + "#\(drill.grid.clueCount)"
    }

    private func nextDrill() {
        guard drillIndex < Self.drillsPerSession else {
            phase = .summary
            return
        }
        guard let drill = takeDrill() else {
            // Bank exhausted and mining found nothing yet — an unlikely
            // combination, but never leave the player staring at nothing.
            feedback = .neutral("No practice position is available for this lesson right now.")
            isLoading = true
            return
        }
        isLoading = false
        drillIndex += 1
        current = drill
        deduction = drill.deduction
        accepted = TrainingEngine.acceptedAnswers(for: drill)
        displayGrid = drill.grid
        struck = []
        selected = nil
        annotations = BoardAnnotations()
        feedback = nil
        hintTier = .none
        misses = 0
        isSolved = false
    }

    private func takeDrill() -> Drill? {
        // The queue may hold several techniques; serve the easiest first so
        // a multi-technique lesson escalates within the session.
        guard !queue.isEmpty else { return nil }
        let i = queue.indices.min { queue[$0].technique < queue[$1].technique } ?? 0
        return queue.remove(at: i)
    }

    /// Advance past a solved drill.
    func advance() {
        guard isSolved else { return }
        nextDrill()
    }

    /// Restart practice with a fresh set of drills.
    func practiceAgain() {
        drillIndex = 0
        results = []
        current = nil
        loadQueue()
        phase = .practice
        nextDrill()
    }

    // MARK: - Practice: input

    func selectCell(_ index: Int) {
        guard !isSolved else { return }
        selected = index
    }

    func tapDigit(_ digit: UInt8) {
        guard !isSolved, let drill = current, let d = deduction else { return }
        guard let cell = selected else {
            feedback = .neutral("Tap a cell first.")
            return
        }
        guard drill.grid.cells[cell] == 0 else {
            feedback = .neutral("That cell is already filled — pick an empty one.")
            return
        }
        let name = CoachPhrasing.cellName(cell)
        if wantsPlacement {
            let verdict = TrainingEngine.check(.place(cell: cell, digit: digit), against: drill, accepted: accepted)
            switch verdict {
            case .correct:
                displayGrid.cells[cell] = digit
                solve(with: "Yes — \(name) is \(digit). \(d.explanation)")
            case .trueButOffTopic:
                misses += 1
                feedback = .miss("True, \(name) is \(digit) — but not by a \(d.technique.displayName). Find the one the pattern forces.")
                Haptics.warning()
            case .incorrect:
                misses += 1
                feedback = .miss("Not \(digit) in \(name). Look again.")
                Haptics.warning()
            }
        } else {
            guard drill.candidates[cell].contains(digit: digit) else {
                feedback = .neutral("There's no \(digit) note in \(name) to cross out.")
                return
            }
            let verdict = TrainingEngine.check(.eliminate(cell: cell, digit: digit), against: drill, accepted: accepted)
            switch verdict {
            case .correct:
                struck.insert(BoardAnnotations.Candidate(cell: cell, digit: digit))
                solve(with: "Right — \(digit) can't go in \(name). \(d.explanation)")
            case .trueButOffTopic:
                misses += 1
                feedback = .miss("\(digit) can indeed be ruled out of \(name), but that isn't what the \(d.technique.displayName) here removes. Find the pattern.")
                Haptics.warning()
            case .incorrect:
                misses += 1
                feedback = .miss("\(digit) can't be ruled out of \(name) here. Look again.")
                Haptics.warning()
            }
        }
    }

    private func solve(with message: String) {
        guard let d = deduction else { return }
        isSolved = true
        annotations = BoardAnnotations(deduction: d, reveal: .full)
        // Show every elimination the pattern makes, not just the one tapped.
        if case .eliminate(let elims) = d.kind {
            for (cell, digits) in elims {
                for digit in digits.digits {
                    struck.insert(BoardAnnotations.Candidate(cell: cell, digit: digit))
                }
            }
        }
        feedback = .success(message)
        let outcome: DrillOutcome = hintTier == .none && misses == 0 ? .clean : .assisted
        finish(outcome)
        Haptics.success()
    }

    /// Escalate the reveal ladder: (name, in mixed mode →) where to look →
    /// the pattern → the answer. Reaching the answer ends the drill.
    func hint() {
        guard canHint, let d = deduction else { return }
        let next: HintTier
        switch hintTier {
        case .none: next = isMixed ? .technique : .location
        case .technique: next = .location
        case .location: next = .pattern
        case .pattern, .answer: next = .answer
        }
        hintTier = next
        switch next {
        case .technique:
            feedback = .neutral("It's a \(d.technique.displayName).")
        case .location:
            annotations = BoardAnnotations(deduction: d, reveal: .location)
            feedback = .neutral(CoachPhrasing.locationHint(for: d))
        case .pattern:
            annotations = BoardAnnotations(deduction: d, reveal: .pattern)
            feedback = .neutral("These cells form the \(d.technique.displayName). What does it let you \(wantsPlacement ? "place" : "cross out")?")
        case .answer:
            reveal()
        case .none:
            break
        }
        Haptics.light()
    }

    /// Give up on this drill: show the resolution and record it as revealed.
    func reveal() {
        guard !isSolved, let d = deduction else { return }
        hintTier = .answer
        isSolved = true
        annotations = BoardAnnotations(deduction: d, reveal: .full)
        switch d.kind {
        case .place(let cell, let digit):
            displayGrid.cells[cell] = digit
        case .eliminate(let elims):
            for (cell, digits) in elims {
                for digit in digits.digits {
                    struck.insert(BoardAnnotations.Candidate(cell: cell, digit: digit))
                }
            }
        }
        feedback = .neutral(d.explanation)
        finish(.revealed)
    }

    private func finish(_ outcome: DrillOutcome) {
        results.append(outcome)
        guard let drill = current, let l = lesson ?? Curriculum.lesson(for: drill.technique) else { return }
        store.record(outcome, lessonID: l.id, drillKey: Self.key(for: drill))
    }

    // MARK: - Summary

    var cleanCount: Int { results.count { $0 == .clean } }
    var assistedCount: Int { results.count { $0 == .assisted } }
    var revealedCount: Int { results.count { $0 == .revealed } }
}
