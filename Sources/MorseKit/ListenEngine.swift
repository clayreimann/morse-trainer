public enum ListenMode: Equatable, Sendable { case live, copyThenCheck }
public enum CheckResult: Equatable, Sendable { case correct, incorrect }

public final class ListenEngine: @unchecked Sendable {
    public let target: [Character]
    public let mode: ListenMode
    public private(set) var index = 0
    public init(target: String, mode: ListenMode) {
        self.target = Array(target.uppercased()); self.mode = mode
    }
    public var isComplete: Bool { index >= target.count }
    /// Live mode: check one character at a time.
    public func type(_ ch: String) -> CheckResult {
        guard mode == .live, index < target.count else { return .incorrect }
        let ok = Character(ch.uppercased()) == target[index]
        if ok { index += 1 }
        return ok ? .correct : .incorrect
    }
    /// Copy-then-check: compare the whole answer.
    public func submit(_ answer: String) -> CheckResult {
        Array(answer.uppercased()) == target ? .correct : .incorrect
    }
}
