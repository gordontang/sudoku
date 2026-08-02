public enum Difficulty: Int, CaseIterable, Sendable, Codable, Comparable, Identifiable, Hashable {
    case easy = 0
    case medium
    case hard
    case expert
    case master

    public var id: Int { rawValue }

    public var displayName: String {
        switch self {
        case .easy: "Easy"
        case .medium: "Medium"
        case .hard: "Hard"
        case .expert: "Expert"
        case .master: "Master"
        }
    }

    public static func < (lhs: Difficulty, rhs: Difficulty) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Human solving techniques, in ascending order of sophistication.
public enum Technique: Int, CaseIterable, Sendable, Codable, Comparable, Hashable {
    case nakedSingle = 0
    case hiddenSingle
    case lockedCandidates
    case nakedPair
    case hiddenPair
    case nakedTriple
    case xWing

    public var displayName: String {
        switch self {
        case .nakedSingle: "Naked Single"
        case .hiddenSingle: "Hidden Single"
        case .lockedCandidates: "Locked Candidates"
        case .nakedPair: "Naked Pair"
        case .hiddenPair: "Hidden Pair"
        case .nakedTriple: "Naked Triple"
        case .xWing: "X-Wing"
        }
    }

    public static func < (lhs: Technique, rhs: Technique) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
