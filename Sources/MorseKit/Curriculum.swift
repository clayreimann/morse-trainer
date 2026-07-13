public struct CurriculumStage: Equatable, Sendable {
    public let index: Int
    public let newLetters: [String]
    public let words: [String]
}

public struct Curriculum: Sendable {
    public let stages: [CurriculumStage]
    public static let `default` = Curriculum(stages: [
        .init(index: 0, newLetters: ["E","T","A"], words: ["AT","ATE","EAT","TEA","TEAT","TAT"]),
        .init(index: 1, newLetters: ["O","N"], words: ["NOT","TON","TAN","ANT","NOTE","TONE","NEAT","OAT"]),
        .init(index: 2, newLetters: ["S","R"], words: ["STAR","RATS","EARS","SANE","NEAR","ROSE","TEARS","REST"]),
        .init(index: 3, newLetters: ["I","H"], words: ["THIS","HITS","HAIR","SHINE","HEART","TRAIN","HINT"]),
        .init(index: 4, newLetters: ["D","L"], words: ["LAND","DEAL","LATE","IDLE","TRAIL","DETAIL","LEAD"]),
        .init(index: 5, newLetters: ["U","C"], words: ["CUT","CLUE","ACID","CLEAN","NUCLEAR","CANE","CURT"]),
        .init(index: 6, newLetters: ["M"], words: ["MAN","MAT","MICE","MUSIC","MODERN","CLIMATE","MEDAL"]),
        .init(index: 7, newLetters: ["W"], words: ["WIN","WATER","WOMAN","SWORD","WINTER","WHICH"]),
        .init(index: 8, newLetters: ["G"], words: ["DOG","GOAL","LIGHT","GARDEN","MORNING","SIGNAL"]),
        .init(index: 9, newLetters: ["P"], words: ["PEN","PLANT","POWER","SIMPLE","PICTURE","PROGRAM"]),
        .init(index: 10, newLetters: ["B"], words: ["BED","TABLE","BRAIN","NUMBER","BROWN","PROBLEM"]),
        .init(index: 11, newLetters: ["F"], words: ["FOR","FAST","FLOWER","FRIEND","FOREST","COMFORT"]),
        .init(index: 12, newLetters: ["Y"], words: ["YES","DAY","STORY","FAMILY","ENERGY","MYSTERY"]),
        .init(index: 13, newLetters: ["K"], words: ["KEY","MAKE","WORK","MARKET","KITCHEN","NETWORK"]),
        .init(index: 14, newLetters: ["V"], words: ["VAN","LOVE","RIVER","SEVEN","SILVER","VICTORY"]),
        .init(index: 15, newLetters: ["J"], words: ["JOB","JUMP","ENJOY","MAJOR","JACKET","JOURNEY"]),
        .init(index: 16, newLetters: ["X"], words: ["FOX","MIX","EXTRA","EXPERT","MAXIMUM","EXAMPLE"]),
        .init(index: 17, newLetters: ["Q"], words: ["QUIT","QUICK","QUIET","SQUARE","REQUEST","QUALITY"]),
        .init(index: 18, newLetters: ["Z"], words: ["ZOO","ZERO","ZEBRA","PRIZE","FROZEN","AMAZING"]),
    ])
    public func lettersUnlocked(throughStage i: Int) -> Set<Character> {
        Set(stages.prefix(i + 1).flatMap { $0.newLetters }.flatMap { $0 }.map { Character(String($0)) })
    }
}
