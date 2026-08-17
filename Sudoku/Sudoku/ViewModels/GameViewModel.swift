import Foundation
import SudokuKit
import SwiftData

/// One user action's worth of reversible state. A single undo restores
/// everything the action changed — including auto-cleared pencil marks and
/// bulk fills like auto-complete.
struct Move {
    var valueChanges: [(cell: Int, old: UInt8)]
    var pencilChanges: [(cell: Int, old: CandidateSet)]
}

/// A chain-analysis sheet: an editable copy of board state layered on top of
/// the real game, used to follow "what if this cell were X" chains without
/// touching real progress, mistakes, or score.
struct ChainLayer {
    var values: Grid
    var pencil: [CandidateSet]
    var undoStack: [Move] = []
}

@MainActor
@Observable
final class GameViewModel {
    static let errorLimit = 3

    let difficulty: Difficulty
    let givens: Grid
    let solution: Grid
    private(set) var values: Grid
    private(set) var pencil: [CandidateSet]
    var selected: Int?
    var pencilMode = false
    private(set) var mistakes: Set<Int> = []
    private(set) var mistakeCount = 0
    private(set) var hintsUsed = 0
    private(set) var undoStack: [Move] = []
    private(set) var isComplete = false
    private(set) var isFailed = false
    private(set) var isPaused = false
    private(set) var score = 0
    var scoreFlash: ScoreFlash?
    /// Number-first mode: a long-pressed pad digit; tapping cells places it.
    private(set) var lockedDigit: UInt8?
    /// The digit most recently placed or noted. Drives same-number
    /// highlighting when the selection itself doesn't name a digit (e.g.
    /// penciling into empty cells), so patterns stay visible while noting.
    private(set) var lastDigit: UInt8?
    /// What-if sheets stacked on the real game for following chains. Each
    /// layer is a full editable copy of board state; the real game and lower
    /// layers stay frozen underneath. Transient — not persisted.
    private(set) var layers: [ChainLayer] = []
    /// Which state the board shows: nil = the real game. Only the top layer
    /// accepts edits while any layers exist.
    private(set) var viewedLayer: Int?
    /// Cells of a just-completed row/column/box, briefly highlighted.
    private(set) var flashCells: Set<Int> = []
    private var flashID = UUID()
    var showVictory = false
    var showFailure = false
    var hintMessage: String?
    private(set) var victoryIsRecord = false
    private(set) var victoryPreviousBest: TimeInterval?
    let startedAt: Date

    // Wall-clock timer: accumulated + (now - runningSince). Never tick-counted,
    // so backgrounded time is never over-counted.
    private var accumulatedSeconds: TimeInterval
    private var runningSince: Date?

    private let modelContext: ModelContext
    private var saved: SavedGame?

    var elapsed: TimeInterval {
        accumulatedSeconds + (runningSince.map { Date().timeIntervalSince($0) } ?? 0)
    }

    var isGameOver: Bool { isComplete || isFailed }

    struct ScoreFlash: Equatable {
        let amount: Int
        let id: UUID
    }

    /// Points per correct placement, by difficulty.
    var placementPoints: Int {
        switch difficulty {
        case .easy: 10
        case .medium: 15
        case .hard: 20
        case .expert: 25
        case .master: 30
        }
    }

    // MARK: - Init

    /// Start a new game, abandoning any existing saved game.
    init(puzzle: Puzzle, context: ModelContext) {
        difficulty = puzzle.difficulty
        givens = puzzle.givens
        solution = puzzle.solution
        values = puzzle.givens
        pencil = Array(repeating: CandidateSet(), count: 81)
        accumulatedSeconds = 0
        runningSince = Date()
        startedAt = Date()
        modelContext = context
        abandonExistingSavedGames()
        save()
    }

    /// Resume from a saved game.
    init?(saved record: SavedGame, context: ModelContext) {
        guard
            let g = Grid(data: record.givensData),
            let s = Grid(data: record.solutionData),
            let v = Grid(data: record.valuesData),
            let p = PencilCoding.decode(record.pencilData)
        else { return nil }
        difficulty = record.difficulty
        givens = g
        solution = s
        values = v
        pencil = p
        mistakeCount = record.mistakeCount
        hintsUsed = record.hintsUsed
        score = record.score
        accumulatedSeconds = record.elapsedSeconds
        runningSince = Date()
        startedAt = record.startedAt
        modelContext = context
        saved = record
        recomputeMistakes()
    }

    private func abandonExistingSavedGames() {
        let existing = (try? modelContext.fetch(FetchDescriptor<SavedGame>())) ?? []
        for record in existing {
            modelContext.insert(CompletedGame(
                difficultyRaw: record.difficultyRaw,
                seconds: record.elapsedSeconds,
                mistakes: record.mistakeCount,
                hints: record.hintsUsed,
                completed: false,
                finishedAt: Date()
            ))
            modelContext.delete(record)
        }
        try? modelContext.save()
    }

    // MARK: - Timer

    func pause() {
        guard runningSince != nil else { return }
        accumulatedSeconds = elapsed
        runningSince = nil
        if !isGameOver {
            saved?.elapsedSeconds = accumulatedSeconds
            try? modelContext.save()
        }
    }

    func resume() {
        // While user-paused, only resumeGame() restarts the clock — a scene
        // becoming active must not silently unpause.
        guard !isGameOver, !isPaused, runningSince == nil else { return }
        runningSince = Date()
    }

    // MARK: - Pause & restart

    func pauseGame() {
        guard !isGameOver else { return }
        isPaused = true
        pause()
    }

    func resumeGame() {
        isPaused = false
        resume()
    }

    /// Reset the same puzzle to its givens for a fresh attempt.
    func restart() {
        guard !isGameOver else { return }
        values = givens
        pencil = Array(repeating: CandidateSet(), count: 81)
        mistakes = []
        mistakeCount = 0
        hintsUsed = 0
        score = 0
        undoStack = []
        selected = nil
        lockedDigit = nil
        lastDigit = nil
        layers = []
        viewedLayer = nil
        hintMessage = nil
        scoreFlash = nil
        flashCells = []
        accumulatedSeconds = 0
        runningSince = Date()
        isPaused = false
        save()
    }

    // MARK: - Chain layers

    static let layerLimit = 5

    /// The board state currently displayed (viewed layer, or the real game).
    var displayValues: Grid {
        viewedLayer.map { layers[$0].values } ?? values
    }

    var displayPencil: [CandidateSet] {
        viewedLayer.map { layers[$0].pencil } ?? pencil
    }

    /// The state directly beneath the viewed layer — what diffs compare
    /// against. Nil when viewing the real game.
    var diffBaseState: (values: Grid, pencil: [CandidateSet])? {
        guard let vi = viewedLayer else { return nil }
        return vi == 0 ? (values, pencil) : (layers[vi - 1].values, layers[vi - 1].pencil)
    }

    /// Whether the currently viewed state accepts edits. While layers exist,
    /// only the top sheet is editable; the real game resumes once cleared.
    var canEditViewedState: Bool {
        layers.isEmpty || viewedLayer == layers.count - 1
    }

    /// Add a new sheet copying the top of the stack (or the real game).
    func addLayer() {
        guard !isGameOver, !isPaused, layers.count < Self.layerLimit else { return }
        let top = layers.last
        layers.append(ChainLayer(values: top?.values ?? values, pencil: top?.pencil ?? pencil))
        viewedLayer = layers.count - 1
        Haptics.light()
    }

    /// Peel off the top sheet (a refuted chain step).
    func dropTopLayer() {
        guard !layers.isEmpty else { return }
        layers.removeLast()
        if layers.isEmpty {
            viewedLayer = nil
        } else if let vi = viewedLayer {
            viewedLayer = min(vi, layers.count - 1)
        }
        Haptics.light()
    }

    /// Discard all sheets and return to the real game.
    func clearLayers() {
        guard !layers.isEmpty else { return }
        layers = []
        viewedLayer = nil
        Haptics.light()
    }

    /// Switch which state the board shows (nil = the real game).
    func viewLayer(_ index: Int?) {
        guard index == nil || (0..<layers.count).contains(index!) else { return }
        viewedLayer = index
    }

    // MARK: - Input

    func select(_ index: Int) {
        selected = index
    }

    /// Board touch: select, and in number-first mode place the locked digit.
    func cellTouched(_ index: Int) {
        selected = index
        if let digit = lockedDigit, !isPaused, givens.cells[index] == 0 {
            tapDigit(digit)
        }
    }

    /// Long-press on a pad digit toggles number-first lock.
    func toggleLock(_ digit: UInt8) {
        lockedDigit = lockedDigit == digit ? nil : digit
        Haptics.light()
    }

    func tapDigit(_ digit: UInt8) {
        guard !isGameOver, !isPaused, let cell = selected, givens.cells[cell] == 0 else { return }

        if !layers.isEmpty {
            tapDigitInLayer(digit, cell: cell)
            return
        }

        if pencilMode {
            guard values.cells[cell] == 0 else { return }
            // Adding a note for a digit already in the row, column, or box is
            // never valid — reject it. Removing an existing note stays allowed
            // so stale marks can always be cleaned up.
            if !pencil[cell].contains(digit: digit) && !values.candidateSet(at: cell).contains(digit: digit) {
                Haptics.warning()
                return
            }
            lastDigit = digit
            undoStack.append(Move(valueChanges: [], pencilChanges: [(cell, pencil[cell])]))
            pencil[cell].toggle(digit: digit)
            Haptics.light()
            save()
            return
        }

        lastDigit = digit
        let old = values.cells[cell]
        if old == digit {
            // Tapping the digit already in the cell clears it.
            undoStack.append(Move(valueChanges: [(cell, old)], pencilChanges: []))
            values.cells[cell] = 0
            recomputeMistakes()
            save()
            return
        }

        var move = Move(valueChanges: [(cell, old)], pencilChanges: [(cell, pencil[cell])])
        if AppSettings.autoClearPencil {
            for p in Grid.peers[cell] where pencil[p].contains(digit: digit) {
                move.pencilChanges.append((p, pencil[p]))
                pencil[p].remove(digit: digit)
            }
        }
        pencil[cell] = CandidateSet()
        values.cells[cell] = digit
        undoStack.append(move)
        if values.cells[cell] == solution.cells[cell] {
            award(placementPoints)
            flashCompletedUnits(around: cell)
        }
        evaluatePlacement(at: cell)
        // Number-first: release the lock once a digit is used up.
        if let locked = lockedDigit, remaining(of: locked) == 0 {
            lockedDigit = nil
        }
        checkCompletion()
        save()
        if AppSettings.autoApplyAutoComplete && canAutoComplete {
            autoComplete()
        }
    }

    /// Chain-mode input: edits go to the top sheet only, with no score,
    /// mistakes, completion, or persistence — it's all hypothetical.
    private func tapDigitInLayer(_ digit: UInt8, cell: Int) {
        guard let vi = viewedLayer, vi == layers.count - 1 else {
            // Viewing a frozen state (the real game or a lower sheet).
            Haptics.warning()
            return
        }
        lastDigit = digit
        var layer = layers[vi]
        if pencilMode {
            guard layer.values.cells[cell] == 0 else { return }
            if !layer.pencil[cell].contains(digit: digit)
                && !layer.values.candidateSet(at: cell).contains(digit: digit) {
                Haptics.warning()
                return
            }
            layer.undoStack.append(Move(valueChanges: [], pencilChanges: [(cell, layer.pencil[cell])]))
            layer.pencil[cell].toggle(digit: digit)
        } else {
            let old = layer.values.cells[cell]
            if old == digit {
                layer.undoStack.append(Move(valueChanges: [(cell, old)], pencilChanges: []))
                layer.values.cells[cell] = 0
            } else {
                var move = Move(valueChanges: [(cell, old)], pencilChanges: [(cell, layer.pencil[cell])])
                // Always propagate a trial digit into peers' candidates —
                // those eliminations are the chain step being followed.
                for p in Grid.peers[cell] where layer.pencil[p].contains(digit: digit) {
                    move.pencilChanges.append((p, layer.pencil[p]))
                    layer.pencil[p].remove(digit: digit)
                }
                layer.pencil[cell] = CandidateSet()
                layer.values.cells[cell] = digit
                layer.undoStack.append(move)
            }
        }
        layers[vi] = layer
        Haptics.light()
    }

    private func award(_ points: Int) {
        score += points
        scoreFlash = ScoreFlash(amount: points, id: UUID())
    }

    /// Briefly highlight any row/column/box that this placement completed.
    private func flashCompletedUnits(around cell: Int) {
        let unitIndices = [cell / 9, 9 + cell % 9, 18 + Grid.box(of: cell)]
        var completed: Set<Int> = []
        for u in unitIndices {
            let unit = Grid.units[u]
            if unit.allSatisfy({ values.cells[$0] != 0 && values.cells[$0] == solution.cells[$0] }) {
                completed.formUnion(unit)
            }
        }
        guard !completed.isEmpty else { return }
        flashCells = completed
        let id = UUID()
        flashID = id
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(0.7))
            guard let self, self.flashID == id else { return }
            self.flashCells = []
        }
    }

    func erase() {
        guard !isGameOver, !isPaused, let cell = selected, givens.cells[cell] == 0 else { return }
        if !layers.isEmpty {
            guard let vi = viewedLayer, vi == layers.count - 1 else {
                Haptics.warning()
                return
            }
            var layer = layers[vi]
            guard layer.values.cells[cell] != 0 || !layer.pencil[cell].isEmpty else { return }
            layer.undoStack.append(Move(
                valueChanges: [(cell, layer.values.cells[cell])],
                pencilChanges: [(cell, layer.pencil[cell])]
            ))
            layer.values.cells[cell] = 0
            layer.pencil[cell] = CandidateSet()
            layers[vi] = layer
            return
        }
        guard values.cells[cell] != 0 || !pencil[cell].isEmpty else { return }
        undoStack.append(Move(valueChanges: [(cell, values.cells[cell])], pencilChanges: [(cell, pencil[cell])]))
        values.cells[cell] = 0
        pencil[cell] = CandidateSet()
        recomputeMistakes()
        save()
    }

    /// Whether the undo button applies to the state being viewed.
    var canUndo: Bool {
        if layers.isEmpty { return !undoStack.isEmpty }
        return viewedLayer == layers.count - 1 && !(layers.last?.undoStack.isEmpty ?? true)
    }

    func undo() {
        guard !isGameOver, !isPaused else { return }
        if !layers.isEmpty {
            guard let vi = viewedLayer, vi == layers.count - 1, !layers[vi].undoStack.isEmpty else { return }
            var layer = layers[vi]
            let move = layer.undoStack.removeLast()
            for (cell, old) in move.valueChanges {
                layer.values.cells[cell] = old
            }
            for (cell, old) in move.pencilChanges {
                layer.pencil[cell] = old
            }
            layers[vi] = layer
            return
        }
        guard let move = undoStack.popLast() else { return }
        for (cell, old) in move.valueChanges {
            values.cells[cell] = old
        }
        for (cell, old) in move.pencilChanges {
            pencil[cell] = old
        }
        recomputeMistakes()
        save()
    }

    /// Fill every empty cell's pencil marks with its currently-legal candidates.
    func fillAllCandidates() {
        guard !isGameOver, !isPaused else { return }
        if !layers.isEmpty {
            guard let vi = viewedLayer, vi == layers.count - 1 else {
                Haptics.warning()
                return
            }
            var layer = layers[vi]
            var move = Move(valueChanges: [], pencilChanges: [])
            for i in 0..<81 where layer.values.cells[i] == 0 {
                let set = layer.values.candidateSet(at: i)
                if layer.pencil[i] != set {
                    move.pencilChanges.append((i, layer.pencil[i]))
                    layer.pencil[i] = set
                }
            }
            guard !move.pencilChanges.isEmpty else { return }
            layer.undoStack.append(move)
            layers[vi] = layer
            Haptics.light()
            return
        }
        var move = Move(valueChanges: [], pencilChanges: [])
        for i in 0..<81 where values.cells[i] == 0 {
            let set = values.candidateSet(at: i)
            if pencil[i] != set {
                move.pencilChanges.append((i, pencil[i]))
                pencil[i] = set
            }
        }
        guard !move.pencilChanges.isEmpty else { return }
        undoStack.append(move)
        Haptics.light()
        save()
    }

    // MARK: - Hints

    func hint() {
        // No hints in chain mode — they reference the real solution and would
        // mislead inside a hypothetical position.
        guard !isGameOver, !isPaused, layers.isEmpty else { return }
        hintsUsed += 1
        let wrongCells = (0..<81).filter {
            givens.cells[$0] == 0 && values.cells[$0] != 0 && values.cells[$0] != solution.cells[$0]
        }
        if let wrong = wrongCells.first {
            placeHint(at: wrong, message: "Fixed R\(wrong / 9 + 1)C\(wrong % 9 + 1) — it should be \(solution.cells[wrong]).")
        } else if let h = HintEngine.hint(for: values), givens.cells[h.cell] == 0 {
            placeHint(at: h.cell, message: h.explanation)
        } else if let empty = (0..<81).first(where: { values.cells[$0] == 0 }) {
            placeHint(at: empty, message: "Revealed R\(empty / 9 + 1)C\(empty % 9 + 1): it's a \(solution.cells[empty]).")
        }
    }

    private func placeHint(at cell: Int, message: String) {
        selected = cell
        var move = Move(valueChanges: [(cell, values.cells[cell])], pencilChanges: [(cell, pencil[cell])])
        let digit = solution.cells[cell]
        lastDigit = digit
        if AppSettings.autoClearPencil {
            for p in Grid.peers[cell] where pencil[p].contains(digit: digit) {
                move.pencilChanges.append((p, pencil[p]))
                pencil[p].remove(digit: digit)
            }
        }
        pencil[cell] = CandidateSet()
        values.cells[cell] = digit
        undoStack.append(move)
        hintMessage = message
        recomputeMistakes()
        flashCompletedUnits(around: cell)
        Haptics.light()
        checkCompletion()
        save()
        if AppSettings.autoApplyAutoComplete && canAutoComplete {
            autoComplete()
        }
    }

    // MARK: - Auto-complete

    /// Auto-complete only appears in the endgame — without this cap an Easy
    /// puzzle (singles-solvable from the first move) would offer it at start,
    /// turning the button into "solve it for me".
    static let autoCompleteMaxRemaining = 20

    /// True when the endgame is routine: every filled cell is correct and the
    /// rest falls to naked and hidden singles alone — a linear finish with no
    /// advanced technique required.
    var canAutoComplete: Bool {
        guard !isGameOver, layers.isEmpty else { return false }
        var empty = 0
        for i in 0..<81 {
            if values.cells[i] == 0 {
                empty += 1
            } else if givens.cells[i] == 0 && values.cells[i] != solution.cells[i] {
                // A wrong entry can fake a "forced" cell — never offer.
                return false
            }
        }
        return empty > 0
            && empty <= Self.autoCompleteMaxRemaining
            && Solver.solveWithSingles(values) != nil
    }

    /// Fill all remaining forced cells in one undoable move.
    func autoComplete() {
        guard canAutoComplete, !isPaused else { return }
        var move = Move(valueChanges: [], pencilChanges: [])
        for i in 0..<81 where values.cells[i] == 0 {
            move.valueChanges.append((i, 0))
            if !pencil[i].isEmpty {
                move.pencilChanges.append((i, pencil[i]))
                pencil[i] = CandidateSet()
            }
            values.cells[i] = solution.cells[i]
        }
        award(placementPoints * move.valueChanges.count)
        undoStack.append(move)
        Haptics.light()
        recomputeMistakes()
        checkCompletion()
        save()
    }

    // MARK: - Mistakes

    private func evaluatePlacement(at cell: Int) {
        switch AppSettings.mistakeMode {
        case .instantSolution:
            let wrong = values.cells[cell] != solution.cells[cell]
            recomputeMistakes()
            wrong ? registerMistake() : Haptics.light()
        case .instantConflict:
            let digit = values.cells[cell]
            let conflict = Grid.peers[cell].contains { values.cells[$0] == digit }
            recomputeMistakes()
            conflict ? registerMistake() : Haptics.light()
        case .onDemand:
            mistakes.remove(cell)
            Haptics.light()
        }
    }

    private func registerMistake() {
        mistakeCount += 1
        Haptics.warning()
        if AppSettings.errorLimitEnabled && mistakeCount >= Self.errorLimit {
            fail()
        }
    }

    private func recomputeMistakes() {
        switch AppSettings.mistakeMode {
        case .instantSolution:
            mistakes = Set((0..<81).filter {
                values.cells[$0] != 0 && givens.cells[$0] == 0 && values.cells[$0] != solution.cells[$0]
            })
        case .instantConflict:
            mistakes = Set((0..<81).filter { i in
                let d = values.cells[i]
                return d != 0 && givens.cells[i] == 0 && Grid.peers[i].contains { values.cells[$0] == d }
            })
        case .onDemand:
            // Flags persist from the last Check, pruned as flagged cells change.
            mistakes = mistakes.filter {
                values.cells[$0] != 0 && values.cells[$0] != solution.cells[$0]
            }
        }
    }

    /// On-demand check: flag all wrong cells, counting newly-found ones.
    func checkNow() {
        guard !isGameOver, !isPaused, layers.isEmpty else { return }
        let wrong = Set((0..<81).filter {
            values.cells[$0] != 0 && givens.cells[$0] == 0 && values.cells[$0] != solution.cells[$0]
        })
        let newlyFound = wrong.subtracting(mistakes)
        mistakeCount += newlyFound.count
        mistakes = wrong
        hintMessage = wrong.isEmpty
            ? "No mistakes so far."
            : "\(wrong.count) incorrect \(wrong.count == 1 ? "cell" : "cells") highlighted."
        if wrong.isEmpty {
            Haptics.light()
        } else {
            Haptics.warning()
            if AppSettings.errorLimitEnabled && mistakeCount >= Self.errorLimit {
                fail()
                return
            }
        }
        save()
    }

    // MARK: - Game end

    private func checkCompletion() {
        guard values.cells == solution.cells else { return }
        score += placementPoints * 10 // completion bonus
        isComplete = true
        pause()
        let raw = difficulty.rawValue
        let descriptor = FetchDescriptor<CompletedGame>(
            predicate: #Predicate { $0.difficultyRaw == raw && $0.completed }
        )
        let prior = (try? modelContext.fetch(descriptor)) ?? []
        victoryPreviousBest = prior.map(\.seconds).min()
        victoryIsRecord = victoryPreviousBest.map { accumulatedSeconds < $0 } ?? true
        recordResult(completed: true)
        Haptics.success()
        showVictory = true
    }

    private func fail() {
        isFailed = true
        pause()
        recordResult(completed: false)
        showFailure = true
    }

    private func recordResult(completed: Bool) {
        modelContext.insert(CompletedGame(
            difficultyRaw: difficulty.rawValue,
            seconds: accumulatedSeconds,
            mistakes: mistakeCount,
            hints: hintsUsed,
            score: score,
            completed: completed,
            finishedAt: Date()
        ))
        if let saved {
            modelContext.delete(saved)
            self.saved = nil
        }
        try? modelContext.save()
    }

    // MARK: - Persistence

    private func save() {
        guard !isGameOver else { return }
        let record: SavedGame
        if let saved {
            record = saved
        } else {
            record = SavedGame(
                givensData: givens.data,
                solutionData: solution.data,
                valuesData: values.data,
                pencilData: PencilCoding.encode(pencil),
                difficultyRaw: difficulty.rawValue,
                elapsedSeconds: elapsed,
                mistakeCount: mistakeCount,
                hintsUsed: hintsUsed,
                score: score,
                startedAt: startedAt
            )
            modelContext.insert(record)
            saved = record
        }
        record.valuesData = values.data
        record.pencilData = PencilCoding.encode(pencil)
        record.elapsedSeconds = elapsed
        record.mistakeCount = mistakeCount
        record.hintsUsed = hintsUsed
        record.score = score
        try? modelContext.save()
    }

    // MARK: - Derived UI state

    /// How many of a digit remain to be placed (9 minus placements on the
    /// displayed board, so pad counts track the viewed chain sheet too).
    func remaining(of digit: UInt8) -> Int {
        max(0, 9 - displayValues.cells.count { $0 == digit })
    }

    var progressText: String {
        let filled = values.clueCount - givens.clueCount
        let total = 81 - givens.clueCount
        return "\(filled)/\(total)"
    }
}
