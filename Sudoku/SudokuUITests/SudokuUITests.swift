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
        return app
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

    func testChainLayers() {
        let app = launchApp()
        let cell = startEasyGame(app)
        // Note a candidate in the real game first.
        cell.tap()
        app.buttons["pencil"].tap()
        app.buttons["digit_7"].tap()
        XCTAssertTrue(cell.label.contains("notes 7"), "got: \(cell.label)")
        app.buttons["pencil"].tap() // pencil off

        // New sheet: place a trial digit; the real game must stay untouched.
        app.buttons["layer"].tap()
        XCTAssertTrue(app.buttons["layer_1"].waitForExistence(timeout: 3), "Layer bar should appear")
        cell.tap()
        app.buttons["digit_8"].tap()
        XCTAssertTrue(cell.label.contains("contains 8"), "trial digit should show in the layer, got: \(cell.label)")

        // A second sheet branches from the real game, not from L1.
        app.buttons["layer"].tap()
        XCTAssertTrue(app.buttons["layer_2"].waitForExistence(timeout: 3), "Second layer chip should appear")
        XCTAssertTrue(cell.label.contains("notes 7"), "new sheet must copy the game, got: \(cell.label)")

        app.buttons["layer_game"].tap()
        XCTAssertTrue(cell.label.contains("notes 7"), "real game must be untouched, got: \(cell.label)")

        // Playing on the real board prompts to discard the sheets first.
        app.buttons["digit_8"].tap()
        let discard = app.alerts.buttons["Discard Layers & Play"]
        XCTAssertTrue(discard.waitForExistence(timeout: 3), "Discard prompt should appear")
        discard.tap()
        XCTAssertFalse(app.buttons["layer_game"].exists, "Layer bar should disappear")
        XCTAssertTrue(cell.label.contains("contains 8"), "got: \(cell.label)")
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
}
