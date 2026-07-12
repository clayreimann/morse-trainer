public enum GapKind: Equatable, Sendable { case intraChar, interChar, interWord }
public enum KeyerEvent: Equatable, Sendable { case element(MorseSymbol), letterBreak, wordBreak }

public struct Keyer: Sendable {
    public let unitMs: Double
    public init(unitMs: Double) { self.unitMs = unitMs }
    public func symbol(forPressMs ms: Double) -> MorseSymbol { ms >= 2 * unitMs ? .dash : .dot }
    public func gap(forMs ms: Double) -> GapKind {
        if ms >= 5 * unitMs { return .interWord }
        if ms >= 2 * unitMs { return .interChar }
        return .intraChar
    }
}

public final class KeyerEngine: @unchecked Sendable {
    private let keyer: Keyer
    private var downAt: Double?
    private var lastUpAt: Double?
    public var onEvent: (KeyerEvent) -> Void = { _ in }
    public init(unitMs: Double) { keyer = Keyer(unitMs: unitMs) }

    public func keyDown(at t: Double) {
        if let up = lastUpAt {
            switch keyer.gap(forMs: t - up) {
            case .intraChar: break
            case .interChar: onEvent(.letterBreak)
            case .interWord: onEvent(.letterBreak); onEvent(.wordBreak)
            }
        }
        downAt = t
    }
    public func keyUp(at t: Double) {
        guard let d = downAt else { return }
        onEvent(.element(keyer.symbol(forPressMs: t - d)))
        downAt = nil; lastUpAt = t
    }
    /// Call when input settles (e.g. timeout) to close the current letter.
    public func flush(at t: Double) {
        guard let up = lastUpAt else { return }
        if t - up >= 2 * keyer.unitMs { onEvent(.letterBreak) }
        lastUpAt = nil
    }
}
