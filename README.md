# Sudoku

A native iOS sudoku app: five difficulty levels, pencil marks, configurable
mistake feedback, scoring, and per-difficulty statistics. Offline, ad-free,
no accounts.

## Layout

- **`SudokuKit/`** — pure-logic Swift package: puzzle generator, human-technique
  solver (singles → locked candidates → pairs → triples → X-Wing), difficulty
  rater, and hint engine. No UIKit/SwiftUI dependencies.
- **`Sudoku/`** — SwiftUI + SwiftData app. The Xcode project uses a
  file-system-synchronized group, so adding a Swift file to `Sudoku/Sudoku/`
  is all it takes — no project-file edits.

## Features

- **Difficulty is honest**: puzzles are rated by the solving techniques actually
  required, not clue count. Master puzzles stall the logical solver.
- **Pencil marks**: toggle pencil mode; placing a digit auto-clears that digit
  from peers' notes (undo restores them). Long-press Pencil fills all
  candidates.
- **Mistake feedback** (Settings): instant vs. solution (default), conflicts
  only, or on-demand Check. Optional 3-mistake limit. Flags use color plus a
  corner marker for colorblind accessibility.
- **Stats**: per-difficulty solve counts, best/average time, streaks, perfect
  solves, and a recent-times trend, all computed from recorded games.
- **Save/resume**: autosaved on every move; survives force-quit. Wall-clock
  timer never counts backgrounded time.
- **Pause & restart**: pause hides the board (no free thinking time) and stops
  the clock; restart resets the same puzzle for a fresh attempt.
- **Scoring**: points per correct placement scaled by difficulty, animated
  "+N" feedback, completion bonus, best score in stats.
- **Number-first entry**: long-press a pad digit to lock it, then tap cells to
  place it repeatedly.
- **Auto-complete**: offered when the endgame is all forced moves — or applied
  instantly via a setting.
- **Quality of life**: row/column/box completion flash, sound effects, keep
  screen awake, in-app light/dark override, show/hide timer and score.

## Build & test

```bash
# Engine tests (fast, no simulator)
cd SudokuKit && swift test

# App + UI tests
xcodebuild test -project Sudoku/Sudoku.xcodeproj -scheme Sudoku \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Requires Xcode 16+; deployment target iOS 17.

## UI-test launch arguments

- `-uitest-reset` — wipe saved games, stats, and settings at launch
- `-uitest-fixed-puzzle` — use a fixed Easy puzzle (deterministic solution)
- `-uitest-autostart` — jump straight into a new Easy game
