/// A set of candidate digits (1...9) stored as a bitmask.
/// Bit `n` is set when digit `n` is a candidate.
public struct CandidateSet: OptionSet, Sendable, Hashable, Codable {
    public var rawValue: UInt16

    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }

    public init(digit: UInt8) {
        precondition((1...9).contains(digit))
        self.rawValue = 1 << digit
    }

    public init(digits: some Sequence<UInt8>) {
        self.rawValue = 0
        for d in digits { insert(digit: d) }
    }

    /// All nine digits.
    public static let all = CandidateSet(rawValue: 0b0000_0011_1111_1110)

    public var count: Int { rawValue.nonzeroBitCount }

    public func contains(digit: UInt8) -> Bool {
        rawValue & (1 << digit) != 0
    }

    public mutating func insert(digit: UInt8) {
        rawValue |= 1 << digit
    }

    public mutating func remove(digit: UInt8) {
        rawValue &= ~(1 << digit)
    }

    public mutating func toggle(digit: UInt8) {
        rawValue ^= 1 << digit
    }

    /// Digits in ascending order.
    public var digits: [UInt8] {
        var result: [UInt8] = []
        for d: UInt8 in 1...9 where contains(digit: d) { result.append(d) }
        return result
    }

    /// The lowest digit in the set, or nil when empty.
    public var first: UInt8? {
        rawValue == 0 ? nil : UInt8(rawValue.trailingZeroBitCount)
    }
}
