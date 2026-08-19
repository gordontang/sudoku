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
/// The order is the app's spine: deduction search order, difficulty rating,
/// and the teaching curriculum all follow it. Raw values are never persisted,
/// so inserting new techniques in rank order is safe.
public enum Technique: Int, CaseIterable, Sendable, Codable, Comparable, Hashable {
    case fullHouse = 0
    case nakedSingle
    case hiddenSingle
    case lockedCandidates
    case lockedPair
    case nakedPair
    case hiddenPair
    case lockedTriple
    case nakedTriple
    case hiddenTriple
    case nakedQuad
    case hiddenQuad
    case xWing

    public var displayName: String {
        switch self {
        case .fullHouse: "Full House"
        case .nakedSingle: "Naked Single"
        case .hiddenSingle: "Hidden Single"
        case .lockedCandidates: "Locked Candidates"
        case .lockedPair: "Locked Pair"
        case .nakedPair: "Naked Pair"
        case .hiddenPair: "Hidden Pair"
        case .lockedTriple: "Locked Triple"
        case .nakedTriple: "Naked Triple"
        case .hiddenTriple: "Hidden Triple"
        case .nakedQuad: "Naked Quadruple"
        case .hiddenQuad: "Hidden Quadruple"
        case .xWing: "X-Wing"
        }
    }

    public static func < (lhs: Technique, rhs: Technique) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
