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
/// The order is the app's spine: difficulty rating bands and the teaching
/// curriculum follow it (deduction search order tracks it closely). Raw
/// values are never persisted, so inserting new techniques in rank order
/// is safe.
public enum Technique: Int, CaseIterable, Sendable, Codable, Comparable, Hashable {
    // Easy band
    case fullHouse = 0
    case nakedSingle
    case hiddenSingle
    // Medium band
    case lockedCandidates
    // Hard band
    case lockedPair
    case nakedPair
    case hiddenPair
    // Expert band
    case lockedTriple
    case nakedTriple
    case hiddenTriple
    case nakedQuad
    case hiddenQuad
    case xWing
    case skyscraper
    case twoStringKite
    case turbotFish
    case emptyRectangle
    case xyWing
    // Master band
    case swordfish
    case jellyfish
    case finnedXWing
    case finnedSwordfish
    case finnedJellyfish
    case xyzWing
    case wWing
    case remotePair
    case bugPlusOne
    case uniqueRectangle
    case hiddenRectangle
    case avoidableRectangle
    case simpleColors
    case multiColors
    case xChain
    case xyChain
    case sueDeCoq
    case alsXZ
    case aic

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
        case .skyscraper: "Skyscraper"
        case .twoStringKite: "2-String Kite"
        case .turbotFish: "Turbot Fish"
        case .emptyRectangle: "Empty Rectangle"
        case .xyWing: "XY-Wing"
        case .swordfish: "Swordfish"
        case .jellyfish: "Jellyfish"
        case .finnedXWing: "Finned X-Wing"
        case .finnedSwordfish: "Finned Swordfish"
        case .finnedJellyfish: "Finned Jellyfish"
        case .xyzWing: "XYZ-Wing"
        case .wWing: "W-Wing"
        case .remotePair: "Remote Pair"
        case .bugPlusOne: "BUG+1"
        case .uniqueRectangle: "Unique Rectangle"
        case .hiddenRectangle: "Hidden Rectangle"
        case .avoidableRectangle: "Avoidable Rectangle"
        case .simpleColors: "Simple Colors"
        case .multiColors: "Multi-Colors"
        case .xChain: "X-Chain"
        case .xyChain: "XY-Chain"
        case .sueDeCoq: "Sue de Coq"
        case .alsXZ: "ALS-XZ"
        case .aic: "Alternating Inference Chain"
        }
    }

    /// The difficulty band this technique rates a puzzle into when it's the
    /// hardest one required.
    public var band: Difficulty {
        if self <= .hiddenSingle { return .easy }
        if self == .lockedCandidates { return .medium }
        if self <= .hiddenPair { return .hard }
        if self <= .xyWing { return .expert }
        return .master
    }

    public static func < (lhs: Technique, rhs: Technique) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
