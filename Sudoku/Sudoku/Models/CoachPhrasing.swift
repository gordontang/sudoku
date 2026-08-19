import SudokuKit

/// Shared wording for tiered advice, so the in-game coach and the training
/// drills speak with one voice.
enum CoachPhrasing {
    /// "Where to look" for a deduction: its home unit when it has one,
    /// otherwise the digit(s) it reasons about.
    static func locationHint(for d: Deduction) -> String {
        if let unit = d.unit {
            return "Look at \(Grid.unitName(unit))."
        }
        if let digit = d.keyDigits.first, d.keyDigits.count == 1 {
            return "It involves the digit \(digit) — select a \(digit) on the board to light up its coverage."
        }
        return "It involves digits \(digitPhrase(d.keyDigits))."
    }

    static func digitPhrase(_ set: CandidateSet) -> String {
        let digits = set.digits.map(String.init)
        guard digits.count > 1 else { return digits.first ?? "" }
        return digits.dropLast().joined(separator: ", ") + " and " + digits.last!
    }

    static func cellName(_ i: Int) -> String {
        "R\(i / 9 + 1)C\(i % 9 + 1)"
    }
}
