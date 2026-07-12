public struct LetterStat: Equatable, Sendable {
    public let letter: String
    public internal(set) var attempts = 0
    public internal(set) var correct = 0
    public internal(set) var hesitancyEMA = 0.0   // ms
    public private(set) var confidence = 0.0     // 0...1
    public init(letter: String) { self.letter = letter }

    public mutating func record(correct isCorrect: Bool, hesitancyMs: Double) {
        attempts += 1; if isCorrect { correct += 1 }
        let alpha = 0.3
        hesitancyEMA = attempts == 1 ? hesitancyMs : (alpha * hesitancyMs + (1 - alpha) * hesitancyEMA)
        // accuracy component (recent-weighted via EMA on correctness)
        let acc = Double(correct) / Double(attempts)
        // hesitancy penalty: 1.0 at <=250ms, decays to 0 by ~2000ms
        let hesScore = max(0, min(1, (2000 - hesitancyEMA) / 1750))
        confidence = max(0, min(1, 0.6 * acc + 0.4 * hesScore)) * min(1, Double(attempts) / 5)
    }
}

public enum MasteryPolicy {
    public static let hintSuppressThreshold = 0.7
    public static func shouldSuppressHint(for s: LetterStat) -> Bool {
        s.confidence >= hintSuppressThreshold
    }
}

extension LetterStat {
    public func rehydrated(attempts: Int, correct: Int, hesitancyEMA: Double) -> LetterStat {
        var s = self; s.attempts = attempts; s.correct = correct; s.hesitancyEMA = hesitancyEMA; return s
    }
}
