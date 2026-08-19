import Foundation
import SudokuKit

/// One recorded game action. The log is the raw material for post-game
/// coaching: board states are reconstructed by replaying value-affecting
/// actions, and gaps between action timestamps expose where thinking
/// stalled.
struct LoggedAction: Equatable {
    enum Kind: UInt8 {
        case place = 0
        case erase
        case noteAdd
        case noteRemove
        case hint          // a hint filled this cell
        case autoComplete  // auto-complete / alt-save filled this cell
        case undoValue     // undo restored this cell to `digit` (0 = empty)
        case check         // on-demand check ran (no cell)
        case advice        // coach advice requested; digit carries the tier
        case layer         // an alt was added (no cell)
    }

    /// Elapsed play time when the action happened, in seconds.
    let time: Double
    let kind: Kind
    /// Cell index 0–80, or 0xFF for board-wide actions.
    let cell: UInt8
    let digit: UInt8

    static let noCell: UInt8 = 0xFF

    /// Whether replaying this action changes the board's values.
    var affectsValues: Bool {
        switch kind {
        case .place, .erase, .hint, .autoComplete, .undoValue: true
        case .noteAdd, .noteRemove, .check, .advice, .layer: false
        }
    }

}

/// Compact binary coding: 7 bytes per action — little-endian UInt32 tenths
/// of a second, kind, cell, digit.
enum MoveLogCoding {
    static func encode(_ log: [LoggedAction]) -> Data {
        var data = Data(capacity: log.count * 7)
        for a in log {
            let tenths = UInt32(max(0, min(a.time * 10, Double(UInt32.max))))
            withUnsafeBytes(of: tenths.littleEndian) { data.append(contentsOf: $0) }
            data.append(a.kind.rawValue)
            data.append(a.cell)
            data.append(a.digit)
        }
        return data
    }

    static func decode(_ data: Data) -> [LoggedAction] {
        guard data.count % 7 == 0 else { return [] }
        let bytes = [UInt8](data)
        var result: [LoggedAction] = []
        result.reserveCapacity(bytes.count / 7)
        for i in stride(from: 0, to: bytes.count, by: 7) {
            let tenths = UInt32(bytes[i])
                | (UInt32(bytes[i + 1]) << 8)
                | (UInt32(bytes[i + 2]) << 16)
                | (UInt32(bytes[i + 3]) << 24)
            guard let kind = LoggedAction.Kind(rawValue: bytes[i + 4]) else { continue }
            result.append(LoggedAction(
                time: Double(tenths) / 10,
                kind: kind,
                cell: bytes[i + 5],
                digit: bytes[i + 6]
            ))
        }
        return result
    }
}
