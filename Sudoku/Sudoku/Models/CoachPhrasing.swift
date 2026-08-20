import SudokuKit

/// Shared wording for tiered advice, so the in-game coach and the training
/// drills speak with one voice.
enum CoachPhrasing {
    /// "Where to look" for a deduction: its home unit when it has one,
    /// otherwise the digit(s) it reasons about.
    static func locationHint(for d: Deduction) -> String {
        let digits = d.keyDigits.count == 1
            ? "the digit \(d.keyDigits.first!)"
            : "the digits \(digitPhrase(d.keyDigits))"
        if let unit = d.unit {
            return "Look at \(Grid.unitName(unit)), and at \(digits) in particular. Selecting a digit lights up everywhere it can still go."
        }
        return "It's about \(digits). Select one on the board to light up its coverage and its remaining spots, and look for the shape."
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
