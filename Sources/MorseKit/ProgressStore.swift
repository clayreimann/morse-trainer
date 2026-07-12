import Foundation
import SwiftData

@Model final class LetterRecord {
    @Attribute(.unique) var letter: String
    var attempts: Int; var correct: Int; var hesitancyEMA: Double; var confidence: Double
    init(letter: String) { self.letter = letter; attempts = 0; correct = 0; hesitancyEMA = 0; confidence = 0 }
}
@Model final class StageRecord {
    @Attribute(.unique) var index: Int
    var completed: Bool
    init(index: Int, completed: Bool) { self.index = index; self.completed = completed }
}

public final class ProgressStore: @unchecked Sendable {
    private let container: ModelContainer
    private let ctx: ModelContext
    public init(inMemory: Bool = false) throws {
        let cfg = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        container = try ModelContainer(for: LetterRecord.self, StageRecord.self, configurations: cfg)
        ctx = ModelContext(container)
    }
    private func letterRecord(_ l: String) -> LetterRecord {
        let key = l.uppercased()
        if let r = try? ctx.fetch(FetchDescriptor<LetterRecord>(
            predicate: #Predicate { $0.letter == key })).first { return r }
        let r = LetterRecord(letter: key); ctx.insert(r); return r
    }
    public func record(letter: String, correct: Bool, hesitancyMs: Double) {
        var stat = LetterStat(letter: letter.uppercased())
        // rehydrate then apply one record
        let r = letterRecord(letter)
        stat = stat.rehydrated(attempts: r.attempts, correct: r.correct, hesitancyEMA: r.hesitancyEMA)
        stat.record(correct: correct, hesitancyMs: hesitancyMs)
        r.attempts = stat.attempts; r.correct = stat.correct
        r.hesitancyEMA = stat.hesitancyEMA; r.confidence = stat.confidence
        try? ctx.save()
    }
    public func confidence(for letter: String) -> Double { letterRecord(letter).confidence }
    public func isHintSuppressed(for letter: String) -> Bool {
        confidence(for: letter) >= MasteryPolicy.hintSuppressThreshold
    }
    public var highestUnlockedStage: Int {
        let completed = (try? ctx.fetch(FetchDescriptor<StageRecord>())) ?? []
        return (completed.filter { $0.completed }.map { $0.index }.max() ?? -1) + 1
    }
    public func completeStage(_ i: Int) {
        if let r = try? ctx.fetch(FetchDescriptor<StageRecord>(
            predicate: #Predicate { $0.index == i })).first { r.completed = true }
        else { ctx.insert(StageRecord(index: i, completed: true)) }
        try? ctx.save()
    }
}
