/// A 9x9 sudoku grid stored as 81 cells in row-major order. `0` means empty.
public struct Grid: Equatable, Hashable, Sendable, Codable {
    public var cells: [UInt8]

    public init() {
        cells = Array(repeating: 0, count: 81)
    }

    public init(cells: [UInt8]) {
        precondition(cells.count == 81, "A grid needs exactly 81 cells")
        self.cells = cells
    }

    /// Parse from an 81-character string, `0` or `.` meaning empty.
    public init?(string: String) {
        let chars = string.filter { $0.isNumber || $0 == "." }
        guard chars.count == 81 else { return nil }
        cells = chars.map { $0 == "." ? 0 : UInt8($0.wholeNumberValue!) }
    }

    public subscript(index: Int) -> UInt8 {
        get { cells[index] }
        set { cells[index] = newValue }
    }

    public subscript(row: Int, col: Int) -> UInt8 {
        get { cells[row * 9 + col] }
        set { cells[row * 9 + col] = newValue }
    }

    public var isFull: Bool {
        !cells.contains(0)
    }

    public var clueCount: Int {
        cells.count { $0 != 0 }
    }

    // MARK: - Geometry

    public static func row(of index: Int) -> Int { index / 9 }
    public static func col(of index: Int) -> Int { index % 9 }
    public static func box(of index: Int) -> Int { (index / 27) * 3 + (index % 9) / 3 }

    /// 27 units: rows 0-8, columns 9-17, boxes 18-26.
    public static let units: [[Int]] = {
        var u: [[Int]] = []
        for r in 0..<9 { u.append((0..<9).map { r * 9 + $0 }) }
        for c in 0..<9 { u.append((0..<9).map { $0 * 9 + c }) }
        for b in 0..<9 {
            let br = (b / 3) * 3, bc = (b % 3) * 3
            u.append((0..<9).map { (br + $0 / 3) * 9 + bc + $0 % 3 })
        }
        return u
    }()

    /// For each cell, the 20 cells sharing a row, column, or box with it.
    public static let peers: [[Int]] = {
        var sets = Array(repeating: Set<Int>(), count: 81)
        for unit in units {
            for a in unit {
                for b in unit where b != a { sets[a].insert(b) }
            }
        }
        return sets.map { $0.sorted() }
    }()

    /// Human-readable name for unit index 0..26.
    public static func unitName(_ unit: Int) -> String {
        switch unit {
        case 0..<9: "Row \(unit + 1)"
        case 9..<18: "Column \(unit - 8)"
        default: "Box \(unit - 17)"
        }
    }

    // MARK: - Validity

    /// True when no unit contains a duplicate non-zero digit.
    public var isValid: Bool {
        for unit in Self.units {
            var seen = CandidateSet()
            for i in unit {
                let d = cells[i]
                guard d != 0 else { continue }
                if seen.contains(digit: d) { return false }
                seen.insert(digit: d)
            }
        }
        return true
    }

    /// True when the grid is full, valid, and therefore solved.
    public var isSolved: Bool {
        isFull && isValid
    }

    /// Whether placing `digit` at `index` breaks no row/column/box constraint.
    public func isLegal(digit: UInt8, at index: Int) -> Bool {
        for p in Self.peers[index] where cells[p] == digit { return false }
        return true
    }

    /// Candidate sets for every cell (empty set for filled cells).
    public func candidates() -> [CandidateSet] {
        var result = Array(repeating: CandidateSet(), count: 81)
        for i in 0..<81 where cells[i] == 0 {
            var set = CandidateSet.all
            for p in Self.peers[i] {
                let d = cells[p]
                if d != 0 { set.remove(digit: d) }
            }
            result[i] = set
        }
        return result
    }

    /// Candidate set for a single cell computed from current values.
    public func candidateSet(at index: Int) -> CandidateSet {
        guard cells[index] == 0 else { return CandidateSet() }
        var set = CandidateSet.all
        for p in Self.peers[index] {
            let d = cells[p]
            if d != 0 { set.remove(digit: d) }
        }
        return set
    }
}
