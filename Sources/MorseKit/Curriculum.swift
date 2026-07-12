public struct CurriculumStage: Equatable, Sendable {
    public let index: Int
    public let newLetters: [String]
    public let words: [String]
}

public struct Curriculum: Sendable {
    public let stages: [CurriculumStage]
    public static let `default` = Curriculum(stages: [
        .init(index: 0, newLetters: ["E","T","A"], words: ["AT","ATE","EAT","TEA","TAT","EATE"]),
        .init(index: 1, newLetters: ["O","N"], words: ["NOT","TON","TAN","ANT","NOTE","TONE","NEAT","OAT"]),
        .init(index: 2, newLetters: ["S","R"], words: ["STAR","RATS","EARS","SANE","NEAR","ROSE","TEARS","REST"]),
        .init(index: 3, newLetters: ["I","H"], words: ["THIS","HITS","HAIR","SHINE","HEART","TRAIN","HINT"]),
        .init(index: 4, newLetters: ["D","L"], words: ["LAND","DEAL","LATE","IDLE","TRAIL","DETAIL","LEAD"]),
        .init(index: 5, newLetters: ["U","C"], words: ["CUT","CLUE","ACID","CLEAN","NUCLEAR","CANE","CURT"]),
    ])
    public func lettersUnlocked(throughStage i: Int) -> Set<Character> {
        Set(stages.prefix(i + 1).flatMap { $0.newLetters }.flatMap { $0 }.map { Character(String($0)) })
    }
}
