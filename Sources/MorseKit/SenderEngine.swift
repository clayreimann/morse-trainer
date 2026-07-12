public final class SenderEngine: @unchecked Sendable {
    public let target: [Character]
    private let expected: [[MorseSymbol]]
    private let unitMs: Double
    private let gate: TimingGate
    private let gracePercent: Double
    public private(set) var currentIndex = 0
    public private(set) var lastLetterWasError = false
    private var buffer: [MorseSymbol] = []
    private var pressTimings: [Double] = []
    public var onLetterComplete: (Int) -> Void = { _ in }
    public var onError: (Int) -> Void = { _ in }

    public init(target: String, unitMs: Double, gate: TimingGate, gracePercent: Double) {
        self.target = Array(target.uppercased())
        self.expected = self.target.map { MorseCode.code(for: $0) ?? [] }
        self.unitMs = unitMs; self.gate = gate; self.gracePercent = gracePercent
    }
    public var completedCount: Int { currentIndex }
    public var isComplete: Bool { currentIndex >= target.count }

    public func consume(_ e: KeyerEvent) { consumeTimed(e, pressMs: nil) }
    public func consumeTimed(_ e: KeyerEvent, pressMs: Double?) {
        switch e {
        case .element(let sym):
            guard currentIndex < expected.count else { return }
            buffer.append(sym)
            if let p = pressMs { pressTimings.append(p) }
            // Guided completion: the target word is known, so a letter is
            // finished once the learner has keyed the expected number of
            // elements. Boundaries come from element COUNT, not inter-element
            // timing — humans (especially learners) can't hit sub-unit gaps at
            // speed, so relying on timing breaks would reject multi-element
            // letters like "A" (·−) after the first element.
            let need = expected[currentIndex].count
            if need > 0 && buffer.count >= need { evaluateLetter() }
        case .letterBreak, .wordBreak:
            // A timing-driven break must not reject a letter still being keyed.
            // Count-based completion above already closes finished letters, so
            // a break arriving mid-character (from a natural inter-element
            // pause) is ignored rather than evaluating a partial buffer.
            break
        }
    }
    private func evaluateLetter() {
        guard !buffer.isEmpty, currentIndex < expected.count else { buffer = []; pressTimings = []; return }
        let patternOK = buffer == expected[currentIndex]
        let timingOK = patternOK && timingPasses()
        if patternOK && timingOK {
            lastLetterWasError = false
            currentIndex += 1
            onLetterComplete(currentIndex - 1)
        } else {
            lastLetterWasError = true
            onError(currentIndex)
        }
        buffer = []; pressTimings = []
    }
    private func timingPasses() -> Bool {
        switch gate {
        case .off: return true
        case .matchWPM:
            guard pressTimings.count == buffer.count else { return true }
            for (i, sym) in buffer.enumerated() {
                let ideal = (sym == .dot ? 1.0 : 3.0) * unitMs
                let tol = ideal * gracePercent / 100
                if abs(pressTimings[i] - ideal) > tol { return false }
            }
            return true
        case .consistent:
            // dots consistent with each other, dashes ~3x dots
            let dots = zip(buffer, pressTimings).filter { $0.0 == .dot }.map { $0.1 }
            guard let base = dots.first else { return true }
            let tol = base * gracePercent / 100
            for (sym, ms) in zip(buffer, pressTimings) {
                let ideal = sym == .dot ? base : base * 3
                if abs(ms - ideal) > tol * (sym == .dot ? 1 : 3) { return false }
            }
            return true
        }
    }
}
