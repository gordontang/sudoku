import XCTest

/// End-to-end tests driving the real app on a fixed puzzle
/// (see UITestSupport.fixedPuzzle: cell r1c1 is empty, its answer is 8).
final class SudokuUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchApp(reset: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        var args = ["-uitest-fixed-puzzle"]
        if reset { args.append("-uitest-reset") }
        app.launchArguments = args
        app.launch()
        // The app opens behind a loading screen; wait for Home before tapping.
        XCTAssertTrue(app.buttons["Easy"].firstMatch.waitForExistence(timeout: 10), "Home should appear after the loading screen")
        return app
    }

    func testLoadingScreenHandsOffToHome() {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-fixed-puzzle", "-uitest-reset"]
        app.launch()
        // Home replaces the loading screen once the store is open.
        XCTAssertTrue(app.buttons["Easy"].firstMatch.waitForExistence(timeout: 10), "Home should appear")
        XCTAssertFalse(app.otherElements["loading_screen"].exists, "Loading screen should be gone once Home is up")
        XCTAssertTrue(app.navigationBars["Sudoku"].exists)
    }

    @discardableResult
    private func startEasyGame(_ app: XCUIApplication) -> XCUIElement {
        app.buttons["Easy"].firstMatch.tap()
        let cell = app.buttons["cell_0_0"]
        XCTAssertTrue(cell.waitForExistence(timeout: 10), "Board should appear")
        return cell
    }

    func testBoardAppears() {
        let app = launchApp()
        startEasyGame(app)
        XCTAssertTrue(app.buttons["digit_1"].exists)
        XCTAssertTrue(app.buttons["hint"].exists)
        XCTAssertTrue(app.buttons["cell_8_8"].exists)
    }

    func testMistakeFlaggedThenCorrected() {
        let app = launchApp()
        let cell = startEasyGame(app)
        cell.tap()
        app.buttons["digit_5"].tap() // wrong: answer is 8
        XCTAssertTrue(cell.label.contains("incorrect"), "Wrong digit must be flagged, got: \(cell.label)")
        app.buttons["digit_8"].tap() // correct it
        XCTAssertFalse(cell.label.contains("incorrect"))
        XCTAssertTrue(cell.label.contains("contains 8"))
    }

    func testPencilMarksAndUndo() {
        let app = launchApp()
        let cell = startEasyGame(app)
        // r1c1's only legal candidates are 7 and 8 — illegal notes are rejected.
        cell.tap()
        app.buttons["pencil"].tap()
        app.buttons["digit_7"].tap()
        XCTAssertTrue(cell.label.contains("notes 7"), "got: \(cell.label)")
        app.buttons["digit_8"].tap()
        XCTAssertTrue(cell.label.contains("notes 7, 8"), "got: \(cell.label)")
        app.buttons["digit_1"].tap() // illegal: 1 is already in column and box
        XCTAssertTrue(cell.label.contains("notes 7, 8"), "illegal note must be rejected, got: \(cell.label)")
        app.buttons["pencil"].tap() // pencil off
        app.buttons["digit_8"].tap() // real value replaces notes
        XCTAssertTrue(cell.label.contains("contains 8"))
        app.buttons["undo"].tap() // back to notes 7,8
        XCTAssertTrue(cell.label.contains("notes 7, 8"), "undo should restore notes, got: \(cell.label)")
        app.buttons["undo"].tap() // back to notes 7
        XCTAssertTrue(cell.label.contains("notes 7"))
        app.buttons["undo"].tap() // back to empty
        XCTAssertTrue(cell.label.contains("empty"))
    }

    func testAutoPencilFillsAllCandidates() {
        let app = launchApp()
        let cell = startEasyGame(app)
        // r1c1's only legal candidates are 7 and 8.
        app.buttons["autopencil"].tap()
        XCTAssertTrue(cell.label.contains("notes 7, 8"), "Auto pencil should note all candidates, got: \(cell.label)")
        XCTAssertFalse(cell.label.contains("contains"), "Auto pencil must not submit digits, got: \(cell.label)")
        app.buttons["undo"].tap()
        XCTAssertTrue(cell.label.contains("empty"), "One undo should clear the whole fill, got: \(cell.label)")
    }

    func testChainLayers() {
        let app = launchApp()
        let cell = startEasyGame(app)
        // Note a candidate in the real game first.
        cell.tap()
        app.buttons["pencil"].tap()
        app.buttons["digit_7"].tap()
        XCTAssertTrue(cell.label.contains("notes 7"), "got: \(cell.label)")
        app.buttons["pencil"].tap() // pencil off

        // New alt: place a trial digit; the real game must stay untouched.
        app.buttons["alt"].tap()
        XCTAssertTrue(app.buttons["layer_1"].waitForExistence(timeout: 3), "Alt bar should appear")
        cell.tap()
        app.buttons["digit_8"].tap()
        XCTAssertTrue(cell.label.contains("contains 8"), "trial digit should show in the layer, got: \(cell.label)")

        // A second alt branches from the real game, not from Alt 1.
        app.buttons["alt"].tap()
        XCTAssertTrue(app.buttons["layer_2"].waitForExistence(timeout: 3), "Second alt chip should appear")
        XCTAssertTrue(cell.label.contains("notes 7"), "new alt must copy the game, got: \(cell.label)")

        app.buttons["layer_game"].tap()
        XCTAssertTrue(cell.label.contains("notes 7"), "real game must be untouched, got: \(cell.label)")

        // Playing on the real board prompts to discard the alts first.
        app.buttons["digit_8"].tap()
        let discard = app.alerts.buttons["Discard Alts & Play"]
        XCTAssertTrue(discard.waitForExistence(timeout: 3), "Discard prompt should appear")
        discard.tap()
        XCTAssertFalse(app.buttons["layer_game"].exists, "Alt bar should disappear")
        XCTAssertTrue(cell.label.contains("contains 8"), "got: \(cell.label)")
    }

    func testSaveSolvedAltToGame() {
        let app = launchApp()
        startEasyGame(app)
        app.buttons["alt"].tap()
        XCTAssertTrue(app.buttons["layer_1"].waitForExistence(timeout: 3), "Alt bar should appear")

        // Solve the entire puzzle inside the alt (fixture strings from
        // UITestSupport.fixedPuzzle; the targets can't share code).
        let givens = Array("003560920006823000100900863070632054400000002230745080684007001000416300017098500")
        let solution = Array("843561927796823415152974863978632154465189732231745689684357291529416378317298546")
        let save = app.buttons["layer_save"]
        XCTAssertFalse(save.exists, "Save must not be offered before the alt is solved")
        for i in 0..<81 where givens[i] == "0" {
            app.buttons["cell_\(i / 9)_\(i % 9)"].tap()
            app.buttons["digit_\(solution[i])"].tap()
        }

        // Saving the solved alt finishes the real game — no re-entry by hand.
        XCTAssertTrue(save.waitForExistence(timeout: 3), "Save to Game should appear once the alt is solved")
        save.tap()
        XCTAssertTrue(app.buttons["victory_done"].waitForExistence(timeout: 5), "Saving the solved alt should complete the puzzle")
    }

    func testTechniqueGuideOpensDuringGame() {
        let app = launchApp()
        let cell = startEasyGame(app)
        app.buttons["guide"].tap()
        let topic = app.staticTexts["Naked Single"]
        XCTAssertTrue(topic.waitForExistence(timeout: 5), "Guide list should appear")
        topic.tap()
        XCTAssertTrue(app.staticTexts["How to use it"].waitForExistence(timeout: 5), "Topic detail should appear")
        app.navigationBars.buttons.firstMatch.tap() // back to the list
        app.buttons["guide_done"].tap()
        XCTAssertTrue(cell.waitForExistence(timeout: 5), "Game should still be active after closing the guide")
    }

    func testTechniqueGuidePrevNextWalksTheLadder() {
        let app = launchApp()
        startEasyGame(app)
        app.buttons["guide"].tap()
        let topic = app.staticTexts["Naked Single"]
        XCTAssertTrue(topic.waitForExistence(timeout: 5))
        topic.tap()
        XCTAssertTrue(app.navigationBars["Naked Single"].waitForExistence(timeout: 5))
        app.buttons["guide_next"].tap()
        XCTAssertTrue(app.navigationBars["Hidden Single"].waitForExistence(timeout: 5), "Next should move to the following technique")
        app.buttons["guide_prev"].tap()
        app.buttons["guide_prev"].tap()
        XCTAssertTrue(app.navigationBars["Full House"].waitForExistence(timeout: 5), "Previous should walk back up the ladder")
        // Every page shows an example board and steps.
        XCTAssertTrue(app.staticTexts["How to use it"].exists)
        app.buttons["guide_done"].tap()
        XCTAssertTrue(app.buttons["cell_0_0"].waitForExistence(timeout: 5))
    }

    /// The coach explains and highlights but never enters a digit: at the
    /// final tier of a placement there is no apply button, and the board is
    /// untouched. (On the fixed puzzle the cheapest move is a naked single.)
    func testCoachExplainsButNeverEntersTheDigit() {
        let app = launchApp()
        startEasyGame(app)
        let target = app.buttons["cell_0_1"] // R1C2, the naked single (4)
        XCTAssertTrue(target.label.contains("empty"))
        app.buttons["coach"].tap()
        let more = app.buttons["coach_more"]
        XCTAssertTrue(more.waitForExistence(timeout: 5), "Coach should offer to tell more")
        more.tap() // location
        more.tap() // pattern: the reasoning, conclusion withheld
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'what does that let you'")).firstMatch.waitForExistence(timeout: 3))
        more.tap() // resolution
        let resolution = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'enter the 4 yourself'")).firstMatch
        XCTAssertTrue(resolution.waitForExistence(timeout: 3), "Resolution should tell the player to enter the digit themselves")
        XCTAssertFalse(app.buttons["coach_apply"].exists)
        XCTAssertFalse(app.buttons["coach_erase"].exists, "Placements are never applied for the player")
        XCTAssertFalse(more.exists)
        XCTAssertTrue(target.label.contains("empty"), "Coach must not enter the digit")
        // The player makes the move.
        target.tap()
        app.buttons["digit_4"].tap()
        XCTAssertTrue(target.label.contains("contains 4"))
    }

    /// "Other moves" lists every technique available in the position and
    /// switches the coaching to the chosen one; "Learn more" opens the guide
    /// straight onto that technique's page.
    func testCoachBrowsesOtherMovesAndOpensGuide() {
        let app = launchApp()
        startEasyGame(app)
        app.buttons["coach"].tap()
        let moves = app.buttons["coach_moves"]
        XCTAssertTrue(moves.waitForExistence(timeout: 5), "Several techniques apply on the fixed puzzle")
        moves.tap()
        let hidden = app.buttons["Hidden Single"].firstMatch
        XCTAssertTrue(hidden.waitForExistence(timeout: 5), "Menu should list the other techniques")
        hidden.tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Hidden Single here'")).firstMatch.waitForExistence(timeout: 3))
        app.buttons["coach_learn"].tap()
        XCTAssertTrue(app.navigationBars["Hidden Single"].waitForExistence(timeout: 5), "Learn more should open the guide on the technique's page")
        XCTAssertTrue(app.staticTexts["How to use it"].exists)
        app.buttons["guide_done"].tap()
        XCTAssertTrue(app.buttons["cell_0_0"].waitForExistence(timeout: 5))
    }

    /// At full reveal of an elimination the coach offers to erase the
    /// disproved notes — housekeeping on request, not the answer.
    func testCoachErasesNotesOnlyOnRequest() {
        let app = launchApp()
        startEasyGame(app)
        // Give R2C2 a note the Locked Candidates elimination will remove.
        let victim = app.buttons["cell_1_1"]
        victim.tap()
        app.buttons["pencil"].tap()
        app.buttons["digit_4"].tap()
        XCTAssertTrue(victim.label.contains("notes 4"), "got: \(victim.label)")
        app.buttons["pencil"].tap()
        app.buttons["coach"].tap()
        XCTAssertTrue(app.buttons["coach_moves"].waitForExistence(timeout: 5))
        app.buttons["coach_moves"].tap()
        let locked = app.buttons["Locked Candidates"].firstMatch
        XCTAssertTrue(locked.waitForExistence(timeout: 5))
        locked.tap()
        let more = app.buttons["coach_more"]
        more.tap(); more.tap(); more.tap()
        let erase = app.buttons["coach_erase"]
        XCTAssertTrue(erase.waitForExistence(timeout: 3), "Eliminations offer to erase the notes")
        XCTAssertTrue(victim.label.contains("notes 4"), "Nothing changes until asked")
        erase.tap()
        XCTAssertTrue(victim.label.contains("empty"), "got: \(victim.label)")
    }

    func testEraseClearsCell() {
        let app = launchApp()
        let cell = startEasyGame(app)
        cell.tap()
        app.buttons["digit_8"].tap()
        XCTAssertTrue(cell.label.contains("contains 8"))
        app.buttons["erase"].tap()
        XCTAssertTrue(cell.label.contains("empty"))
    }

    func testCompletePuzzleViaHintsAndStatsRecorded() {
        let app = launchApp()
        startEasyGame(app)
        // The fixture has 39 empty cells; each hint fills one correctly.
        let done = app.buttons["victory_done"]
        for _ in 0..<41 {
            if done.exists { break }
            app.buttons["hint"].tap()
        }
        XCTAssertTrue(done.waitForExistence(timeout: 5), "Victory sheet should appear")
        done.tap()
        // Back on Home; the finished game must appear in Stats.
        XCTAssertTrue(app.staticTexts["New Game"].waitForExistence(timeout: 5))
        app.buttons["Statistics"].tap()
        XCTAssertTrue(app.staticTexts["Puzzles solved"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Easy"].exists, "Easy section should exist in stats")
    }

    func testPauseResumeAndRestart() {
        let app = launchApp()
        let cell = startEasyGame(app)
        cell.tap()
        app.buttons["digit_8"].tap()
        XCTAssertTrue(cell.label.contains("contains 8"))

        app.buttons["pause"].tap()
        let resume = app.buttons["resume"]
        XCTAssertTrue(resume.waitForExistence(timeout: 3), "Pause overlay should appear")
        XCTAssertFalse(cell.label.contains("contains 8"), "Board must be hidden while paused, got: \(cell.label)")

        resume.tap()
        XCTAssertTrue(cell.label.contains("contains 8"), "Board should be restored on resume")

        app.buttons["pause"].tap()
        XCTAssertTrue(app.buttons["restart"].waitForExistence(timeout: 3))
        app.buttons["restart"].tap()
        XCTAssertTrue(cell.label.contains("empty"), "Restart should clear the board, got: \(cell.label)")
    }

    func testAutoCompleteAppearsAndFinishesPuzzle() {
        let app = launchApp()
        startEasyGame(app)
        // Hint-fill until the endgame is forced; the button must appear before
        // the last cell (a lone empty cell is always a naked single).
        let autocomplete = app.buttons["autocomplete"]
        let done = app.buttons["victory_done"]
        for _ in 0..<38 {
            if autocomplete.exists { break }
            XCTAssertFalse(done.exists, "Puzzle finished before auto-complete ever appeared")
            app.buttons["hint"].tap()
        }
        XCTAssertTrue(autocomplete.waitForExistence(timeout: 3), "Auto-complete should appear once the endgame is forced")
        autocomplete.tap()
        XCTAssertTrue(done.waitForExistence(timeout: 5), "Auto-complete should finish the puzzle")
    }

    func testOnDemandMistakeMode() {
        let app = launchApp()
        // Switch mistake feedback to on-demand in Settings.
        app.buttons["Settings"].tap()
        // Inline picker rows surface as buttons or generic elements, not static texts.
        let onDemand = app.descendants(matching: .any)["On demand"].firstMatch
        XCTAssertTrue(onDemand.waitForExistence(timeout: 5))
        onDemand.tap()
        app.navigationBars.buttons.firstMatch.tap() // back to Home
        let cell = startEasyGame(app)
        cell.tap()
        app.buttons["digit_5"].tap() // wrong, but must NOT be flagged live
        XCTAssertFalse(cell.label.contains("incorrect"), "On-demand mode must not flag live, got: \(cell.label)")
        let check = app.buttons["check"]
        XCTAssertTrue(check.exists, "Check button should be visible in on-demand mode")
        check.tap()
        XCTAssertTrue(cell.label.contains("incorrect"), "Check should reveal the error, got: \(cell.label)")
    }

    func testSaveAndResumeAfterRelaunch() {
        var app = launchApp()
        let cell = startEasyGame(app)
        cell.tap()
        app.buttons["digit_8"].tap()
        // Give autosave a beat, then kill the app.
        Thread.sleep(forTimeInterval: 1)
        app.terminate()

        // Relaunch WITHOUT reset: the saved game must survive.
        app = XCUIApplication()
        app.launchArguments = []
        app.launch()
        let resume = app.staticTexts["Continue"]
        XCTAssertTrue(resume.waitForExistence(timeout: 10), "Resume card should appear")
        resume.tap()
        let restored = app.buttons["cell_0_0"]
        XCTAssertTrue(restored.waitForExistence(timeout: 10))
        XCTAssertTrue(restored.label.contains("contains 8"), "Placed digit must survive relaunch, got: \(restored.label)")
    }

    // MARK: - Training

    private func openTraining(_ app: XCUIApplication) {
        app.buttons["training"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Full House"].waitForExistence(timeout: 10), "Training list should appear")
    }

    func testTrainingLessonWalkthrough() {
        let app = launchApp()
        openTraining(app)
        // Open the Full House lesson (its lead technique's raw value is 0).
        app.buttons["lesson_0"].tap()

        // Learn phase: the guide topic and its steps.
        XCTAssertTrue(app.staticTexts["How to use it"].waitForExistence(timeout: 5), "Learn phase should show the topic")
        app.buttons["lesson_to_example"].tap()

        // Worked example: step through all four reveal tiers.
        let exampleNext = app.buttons["example_next"]
        XCTAssertTrue(exampleNext.waitForExistence(timeout: 5), "Example phase should appear")
        for _ in 0..<DrillReveals.exampleSteps { exampleNext.tap() }

        // Practice: a drill with a prompt and the plain 1–9 pad.
        XCTAssertTrue(app.staticTexts["Drill 1 of 3"].waitForExistence(timeout: 10), "Practice should start after the example")
        XCTAssertTrue(app.buttons["drill_digit_1"].exists, "Drill pad should be present")
    }

    func testTrainingRevealAdvancesAndRecordsMastery() {
        let app = launchApp()
        openTraining(app)
        app.buttons["lesson_0"].tap()
        // Jump straight to practice via the phase picker.
        XCTAssertTrue(app.buttons["lesson_to_example"].waitForExistence(timeout: 5))
        app.buttons["Practice"].tap()

        XCTAssertTrue(app.staticTexts["Drill 1 of 3"].waitForExistence(timeout: 10), "First drill should load")

        // Reveal the answer on each of the three drills — no clean finds, so
        // mastery stays at zero but the session completes.
        for _ in 0..<3 {
            let reveal = app.buttons["drill_reveal"]
            XCTAssertTrue(reveal.waitForExistence(timeout: 10))
            reveal.tap()
            app.buttons["drill_next"].tap()
        }

        // Summary shows and mastery is unchanged (revealed drills don't count).
        let mastery = app.staticTexts["summary_mastery"]
        XCTAssertTrue(mastery.waitForExistence(timeout: 5), "Summary should appear after three drills")
        XCTAssertTrue(mastery.label.contains("0 of"), "Revealed drills must not earn mastery, got: \(mastery.label)")
    }

    func testMixedPracticeWithholdsTechniqueName() {
        let app = launchApp()
        openTraining(app)
        app.buttons["training_mixed"].tap()
        // Mixed practice goes straight to a drill whose prompt never names a
        // specific technique until a hint is asked for.
        let prompt = app.staticTexts["drill_prompt"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 10), "Mixed practice should start a drill")
        XCTAssertTrue(prompt.label.contains("next move"), "Mixed prompt should not name the technique, got: \(prompt.label)")
    }
}

/// Mirror of `DrillSession.exampleSteps` for the UI test target, which can't
/// import the app module.
private enum DrillReveals {
    static let exampleSteps = 4
}
