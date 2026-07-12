import SwiftUI
import Foundation
import MorseKit

/// Practice #1 — "Learn/Send". Drives a `KeyerEngine`/`SenderEngine` pair against
/// the current curriculum stage's words, recording mastery progress and
/// revealing/suppressing per-letter hints as the learner's confidence grows.
///
/// Intentionally decoupled from `SettingsStore`: the caller (a future
/// `RootView`) owns settings persistence and passes a plain `AppSettings`
/// snapshot down, along with the shared `ProgressStore`, `MorsePlayer`, and
/// `ToneGenerator`. The learner can move between unlocked stages in place.
public struct LearnSendView: View {
    @StateObject private var coordinator: SendCoordinator
    private let settings: AppSettings

    public init(
        settings: AppSettings,
        progress: ProgressStore,
        player: MorsePlayer,
        tone: ToneGenerator,
        stageIndex: Int
    ) {
        self.settings = settings
        _coordinator = StateObject(wrappedValue: SendCoordinator(
            settings: settings, progress: progress, player: player, tone: tone, stageIndex: stageIndex
        ))
    }

    public var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Stage navigation — move between unlocked stages without leaving the tab.
            HStack(spacing: Theme.Spacing.lg) {
                Button { coordinator.previousStage() } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(!coordinator.canGoPrevious)

                Text("Stage \(coordinator.currentStageIndex + 1) of \(coordinator.totalStages)")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()

                Button { coordinator.nextStage() } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(!coordinator.canGoNext)
            }
            .buttonStyle(.bordered)

            LetterRow(
                letters: coordinator.word,
                completedCount: coordinator.completedCount,
                currentIndex: coordinator.currentIndex,
                hintForCurrent: coordinator.hintForCurrent
            )
            .padding(.vertical, Theme.Spacing.md)
            .padding(.horizontal, Theme.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .fill(coordinator.errorFlash ? Color.red.opacity(0.18) : Color.clear)
            )
            .animation(.easeInOut(duration: 0.2), value: coordinator.errorFlash)

            // Live feedback: what you've keyed for the current letter, or — after
            // a miss — what you sent versus the target. The miss feedback persists
            // until you begin your next attempt (see `SendCoordinator.keyDown`).
            Group {
                if let rej = coordinator.rejected {
                    HStack(spacing: Theme.Spacing.md) {
                        Text("You sent \(rej.isEmpty ? "—" : Theme.codeString(for: rej))")
                            .foregroundStyle(.red)
                        Text("Target \(Theme.codeString(for: coordinator.expectedCode))")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(coordinator.keyedSoFar.isEmpty
                         ? "Tap out the current letter"
                         : Theme.codeString(for: coordinator.keyedSoFar))
                        .foregroundStyle(coordinator.keyedSoFar.isEmpty ? .secondary : .primary)
                }
            }
            .font(Theme.codeFont)
            .frame(minHeight: 24)

            // Speed gauge (straight-key only): shows your smoothed sending speed
            // relative to the target — left = slower, right = faster.
            if settings.inputMode == .straightKey {
                VStack(spacing: Theme.Spacing.xs) {
                    HStack {
                        Text("slower").font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        Text(coordinator.estimatedWPMLabel)
                            .font(.caption).monospacedDigit()
                        Spacer()
                        Text("faster").font(.caption2).foregroundStyle(.secondary)
                    }
                    TimingMeter(position: coordinator.timingPosition)
                        .frame(height: 24)
                }
                .padding(.horizontal)
            }

            Button("Hear it") {
                coordinator.hearWord()
            }
            .buttonStyle(.bordered)

            Spacer()

            if coordinator.stageComplete {
                VStack(spacing: Theme.Spacing.sm) {
                    Text("Stage complete!")
                        .font(Theme.titleFont)
                        .foregroundStyle(Theme.mastered)
                    Text("All words in this stage are mastered.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if coordinator.canGoNext {
                        Button("Next stage") { coordinator.nextStage() }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                    }
                }
            } else if coordinator.isWordComplete {
                VStack(spacing: Theme.Spacing.sm) {
                    Text("Nice — next word in \(coordinator.countdown)…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Button("Next word now") {
                        coordinator.nextWord()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            } else {
                KeyButton(
                    mode: settings.inputMode,
                    keySound: settings.keySound,
                    tone: coordinator.tone,
                    onDown: { coordinator.keyDown() },
                    onUp: { coordinator.keyUp() },
                    onSymbol: { coordinator.symbolPressed($0) }
                )
            }
        }
        .padding()
    }
}

/// Owns the mutable keying/matching state for `LearnSendView`: wires a
/// `KeyerEngine` (straight key) / direct symbol feed (paddle) into a
/// `SenderEngine`, tracks per-letter hesitancy, estimates sending speed,
/// auto-advances words, and lets the learner move between unlocked stages.
@MainActor
private final class SendCoordinator: ObservableObject, @unchecked Sendable {
    let progress: ProgressStore
    let player: MorsePlayer
    let tone: ToneGenerator
    let settings: AppSettings

    /// Seconds a completed word waits before auto-advancing (counts down visibly).
    private let autoAdvanceSeconds = 3
    /// Safety timeout after which stale miss feedback clears on its own.
    private let rejectionTimeoutSeconds: Double = 6

    @Published private(set) var currentStageIndex: Int
    @Published private(set) var wordIndex = 0
    @Published private(set) var currentIndex = 0
    @Published private(set) var completedCount = 0
    @Published private(set) var isWordComplete = false
    @Published private(set) var stageComplete = false
    @Published private(set) var countdown = 0
    @Published var errorFlash = false
    @Published var timingPosition: Double = 0
    /// Smoothed estimate of the learner's actual sending speed (nil until they key).
    @Published var estimatedWPM: Double?
    /// Elements keyed so far for the letter currently in progress (live feedback).
    @Published var keyedSoFar: [MorseSymbol] = []
    /// What was keyed when the last letter was rejected; persists until the next attempt.
    @Published var rejected: [MorseSymbol]?

    private var keyer: KeyerEngine!
    private var sender: SenderEngine!

    private var downAt: Date?
    private var letterStartAt = Date()
    private var firstKeyDownForLetter: Date?
    private var lastPressMs: Double?
    /// Exponential moving average of the implied unit length (ms), across the session.
    private var unitEMA: Double?
    private var settleGeneration = 0
    private var errorFlashGeneration = 0
    private var rejectGeneration = 0
    private var autoAdvanceGeneration = 0

    private var stage: CurriculumStage { Curriculum.default.stages[currentStageIndex] }
    var word: [Character] { Array(stage.words[wordIndex]) }

    var totalStages: Int { Curriculum.default.stages.count }
    /// Highest stage the learner may select: capped by what they've unlocked.
    private var maxSelectableStage: Int { min(totalStages - 1, progress.highestUnlockedStage) }
    var canGoPrevious: Bool { currentStageIndex > 0 }
    var canGoNext: Bool { currentStageIndex < maxSelectableStage }

    var estimatedWPMLabel: String {
        guard let wpm = estimatedWPM else { return "≈ — WPM" }
        return "≈ \(Int(wpm.rounded())) WPM"
    }

    var hintForCurrent: [MorseSymbol]? {
        guard currentIndex < word.count else { return nil }
        let letter = word[currentIndex]
        if rejected != nil { return MorseCode.code(for: letter) } // force-reveal after a miss
        if settings.difficulty == .hard { return nil }
        if progress.isHintSuppressed(for: String(letter)) { return nil }
        return MorseCode.code(for: letter)
    }

    /// The correct code for the current letter (used by the sent-vs-target readout).
    var expectedCode: [MorseSymbol] {
        guard currentIndex < word.count else { return [] }
        return MorseCode.code(for: word[currentIndex]) ?? []
    }

    init(settings: AppSettings, progress: ProgressStore, player: MorsePlayer, tone: ToneGenerator, stageIndex: Int) {
        self.settings = settings
        self.progress = progress
        self.player = player
        self.tone = tone
        // Clamp defensively in case every stage is already unlocked/completed.
        self.currentStageIndex = min(max(0, stageIndex), Curriculum.default.stages.count - 1)
        setupWord()
    }

    private var unitMs: Double { Timing.unitMs(charWPM: settings.charWPM) }

    private func setupWord() {
        currentIndex = 0
        completedCount = 0
        isWordComplete = false
        stageComplete = false
        errorFlash = false
        keyedSoFar = []
        rejected = nil
        letterStartAt = Date()
        firstKeyDownForLetter = nil
        // Cancel any pending timers from the previous word/stage.
        settleGeneration += 1
        errorFlashGeneration += 1
        rejectGeneration += 1
        autoAdvanceGeneration += 1

        let k = KeyerEngine(unitMs: unitMs)
        let s = SenderEngine(
            target: stage.words[wordIndex],
            unitMs: unitMs,
            gate: settings.timingGate,
            gracePercent: settings.gateGracePercent
        )
        k.onEvent = { [weak self] event in self?.handle(event) }
        s.onLetterComplete = { [weak self] idx in self?.handleLetterComplete(idx) }
        s.onError = { [weak self] idx in self?.handleError(idx) }
        keyer = k
        sender = s
    }

    private func handle(_ event: KeyerEvent) {
        switch event {
        case .element(let sym):
            keyedSoFar.append(sym)
            sender.consumeTimed(.element(sym), pressMs: lastPressMs)
            recordSpeed(sym: sym, pressMs: lastPressMs)
        case .letterBreak, .wordBreak:
            sender.consumeTimed(event, pressMs: nil)
        }
    }

    private func handleLetterComplete(_ idx: Int) {
        let hesitancy = (firstKeyDownForLetter ?? Date()).timeIntervalSince(letterStartAt) * 1000
        progress.record(letter: String(word[idx]), correct: true, hesitancyMs: hesitancy)
        completedCount = sender.completedCount
        currentIndex = sender.currentIndex
        errorFlash = false
        rejected = nil
        keyedSoFar = []
        letterStartAt = Date()
        firstKeyDownForLetter = nil
        if sender.isComplete { wordCompleted() }
    }

    private func handleError(_ idx: Int) {
        if idx < word.count {
            let hesitancy = (firstKeyDownForLetter ?? Date()).timeIntervalSince(letterStartAt) * 1000
            progress.record(letter: String(word[idx]), correct: false, hesitancyMs: hesitancy)
        }
        rejected = keyedSoFar
        keyedSoFar = []

        // Brief red pulse on the word.
        errorFlash = true
        errorFlashGeneration += 1
        let fgen = errorFlashGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, self.errorFlashGeneration == fgen else { return }
            self.errorFlash = false
        }

        // Keep the "you sent / target" feedback up until the next attempt, with
        // a safety timeout so it doesn't linger forever if the learner walks away.
        rejectGeneration += 1
        let rgen = rejectGeneration
        DispatchQueue.main.asyncAfter(deadline: .now() + rejectionTimeoutSeconds) { [weak self] in
            guard let self, self.rejectGeneration == rgen else { return }
            self.rejected = nil
        }
    }

    private func wordCompleted() {
        isWordComplete = true
        if wordIndex >= stage.words.count - 1 {
            stageComplete = true
            progress.completeStage(currentStageIndex)
        } else {
            startAutoAdvance()
        }
    }

    /// Counts down `autoAdvanceSeconds` (visible in the label), then advances.
    private func startAutoAdvance() {
        autoAdvanceGeneration += 1
        let gen = autoAdvanceGeneration
        countdown = autoAdvanceSeconds
        tickAutoAdvance(gen: gen)
    }

    private func tickAutoAdvance(gen: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self, self.autoAdvanceGeneration == gen else { return }
            self.countdown -= 1
            if self.countdown <= 0 {
                self.nextWord()
            } else {
                self.tickAutoAdvance(gen: gen)
            }
        }
    }

    func nextWord() {
        guard !stageComplete, wordIndex < stage.words.count - 1 else { return }
        wordIndex += 1
        setupWord()
    }

    func nextStage() {
        guard canGoNext else { return }
        currentStageIndex += 1
        wordIndex = 0
        setupWord()
    }

    func previousStage() {
        guard canGoPrevious else { return }
        currentStageIndex -= 1
        wordIndex = 0
        setupWord()
    }

    func hearWord() {
        player.play(String(word), settings: settings.timing, frequency: settings.frequencyHz)
    }

    // MARK: - Key input

    /// Clears stale miss feedback when the learner begins a fresh attempt.
    private func clearRejectionForNewAttempt() {
        guard rejected != nil else { return }
        rejected = nil
        errorFlash = false
        rejectGeneration += 1
    }

    func keyDown() {
        clearRejectionForNewAttempt()
        let now = Date()
        if firstKeyDownForLetter == nil { firstKeyDownForLetter = now }
        downAt = now
        keyer.keyDown(at: now.timeIntervalSince1970 * 1000)
        resetSettleDebounce()
    }

    func keyUp() {
        let now = Date()
        if let d = downAt { lastPressMs = now.timeIntervalSince(d) * 1000 }
        keyer.keyUp(at: now.timeIntervalSince1970 * 1000)
        downAt = nil
        resetSettleDebounce()
    }

    func symbolPressed(_ sym: MorseSymbol) {
        // Paddle mode: KeyButton already classifies the element, so feed the
        // sender directly (no raw press duration to measure) and rely on the
        // settle debounce below to close the letter after a pause. No speed
        // estimate here — there's no real press duration.
        clearRejectionForNewAttempt()
        if firstKeyDownForLetter == nil { firstKeyDownForLetter = Date() }
        let ideal = (sym == .dot ? 1.0 : 3.0) * unitMs
        keyedSoFar.append(sym)
        sender.consumeTimed(.element(sym), pressMs: ideal)
        resetSettleDebounce()
    }

    /// After a pause with no new key activity, close out the current letter
    /// so a trailing element isn't left stranded in the buffer.
    private func resetSettleDebounce() {
        settleGeneration += 1
        let gen = settleGeneration
        let delaySeconds = (unitMs * 2.5) / 1000
        DispatchQueue.main.asyncAfter(deadline: .now() + delaySeconds) { [weak self] in
            guard let self, self.settleGeneration == gen else { return }
            switch self.settings.inputMode {
            case .straightKey:
                self.keyer.flush(at: Date().timeIntervalSince1970 * 1000)
            case .paddle:
                self.sender.consumeTimed(.letterBreak, pressMs: nil)
            }
        }
    }

    /// Updates the smoothed sending-speed estimate and the gauge position from a
    /// real straight-key press. Each element implies a unit length: a dot is one
    /// unit, a dash is three. We EMA the implied unit and derive WPM = 1200/unit.
    private func recordSpeed(sym: MorseSymbol, pressMs: Double?) {
        guard let pressMs, pressMs > 0 else { return }
        let impliedUnit = sym == .dot ? pressMs : pressMs / 3
        let alpha = 0.4
        unitEMA = unitEMA.map { alpha * impliedUnit + (1 - alpha) * $0 } ?? impliedUnit
        guard let u = unitEMA, u > 0 else { return }
        let wpm = 1200 / u
        estimatedWPM = wpm
        let target = settings.charWPM
        guard target > 0 else { return }
        timingPosition = max(-1, min(1, (wpm - target) / target))
    }
}

#Preview("LearnSend") {
    LearnSendView(
        settings: AppSettings(),
        progress: try! ProgressStore(inMemory: true),
        player: MorsePlayer(tone: ToneGenerator()),
        tone: ToneGenerator(),
        stageIndex: 0
    )
}
