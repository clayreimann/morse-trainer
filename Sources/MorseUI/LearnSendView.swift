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
/// `ToneGenerator`. The learner can move between unlocked stages in place, or
/// switch into an endless "Quiz" mode that draws random words from everything
/// they've unlocked so far.
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

    // The body is intentionally decomposed into small computed subviews. A single
    // large `body` expression here trips the SwiftUI type-checker's complexity
    // budget ("unable to type-check in reasonable time"); splitting it keeps each
    // expression cheap to check and the build fast/robust across toolchains.
    public var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            modePicker
            if coordinator.mode == .guided { stageHeader }
            practiceCard
            Spacer()
            bottomAction
        }
        .padding()
        .background { keyboardCapture }
        .onAppear { coordinator.tone.frequency = settings.frequencyHz }
        .onChange(of: settings.frequencyHz) { _, newValue in
            coordinator.tone.frequency = newValue
        }
    }

    /// The chosen accent color and a contrasting on-color, resolved once.
    private var accent: Color { settings.appColor.color }
    private var accentOn: Color { settings.appColor.onColor }

    private var modePicker: some View {
        Picker("Mode", selection: Binding(
            get: { coordinator.mode },
            set: { coordinator.setMode($0) }
        )) {
            Text("Guided").tag(SendCoordinator.LearnMode.guided)
            Text("Quiz").tag(SendCoordinator.LearnMode.quiz)
        }
        .pickerStyle(.segmented)
    }

    /// Guided-only: "STAGE n OF m" caption, stage chevrons, and a progress bar.
    private var stageHeader: some View {
        VStack(spacing: Theme.Spacing.xs) {
            HStack {
                Text("STAGE \(coordinator.currentStageIndex + 1) OF \(coordinator.totalStages)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button { coordinator.previousStage() } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!coordinator.canGoPrevious)

                Button { coordinator.nextStage() } label: {
                    Image(systemName: "chevron.right")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!coordinator.canGoNext)
            }
            ProgressView(
                value: Double(coordinator.currentStageIndex + 1),
                total: Double(coordinator.totalStages)
            )
            .tint(accent)
        }
        .padding(.top, Theme.Spacing.md)
    }

    /// The word card: the letters, live/miss feedback, the speed meter, and the
    /// top-trailing "Hear it" speaker button.
    private var practiceCard: some View {
        // Content stays centered in the card; the card keeps a fixed min height
        // and does NOT stretch to fill freed vertical space (e.g. when the stage
        // header is hidden in quiz mode) — the outer `Spacer()` absorbs that,
        // moving the card up and leaving whitespace above the key instead.
        VStack(spacing: Theme.Spacing.md) {
            LetterRow(
                letters: coordinator.word,
                completedCount: coordinator.completedCount,
                currentIndex: coordinator.currentIndex,
                hintForCurrent: coordinator.hintForCurrent,
                accent: accent
            )
            .padding(.vertical, Theme.Spacing.md)
            .padding(.horizontal, Theme.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.md)
                    .fill(coordinator.errorFlash ? Color.red.opacity(0.18) : Color.clear)
            )
            .animation(.easeInOut(duration: 0.2), value: coordinator.errorFlash)

            feedbackLine

            // Speed gauge (straight-key only): smoothed sending speed vs the
            // target, shown only while actively sending.
            if settings.inputMode == .straightKey {
                speedSection
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, minHeight: 200)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Theme.cardFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(Theme.cardStroke)
                )
        )
        // "Hear it" pinned to the card's bottom-right corner, clear of the word.
        .overlay(alignment: .bottomTrailing) { hearButton }
    }

    /// Live feedback: what you've keyed for the current letter, or — after a
    /// miss — what you sent versus the target (persists until the next attempt).
    @ViewBuilder
    private var feedbackLine: some View {
        Group {
            if let rej = coordinator.rejected {
                HStack(spacing: Theme.Spacing.md) {
                    Text("You sent \(rej.isEmpty ? "—" : Theme.codeString(for: rej))")
                        .foregroundStyle(.red)
                    Text("Target \(Theme.codeString(for: coordinator.expectedCode))")
                        .foregroundStyle(.secondary)
                }
            } else if !coordinator.keyedSoFar.isEmpty {
                Text(Theme.codeString(for: coordinator.keyedSoFar))
            } else {
                Text(" ")
                    .font(Theme.codeFont)
                    .hidden()
            }
        }
        .font(Theme.codeFont)
        .frame(minHeight: 24)
    }

    private var speedSection: some View {
        VStack(spacing: Theme.Spacing.xs) {
            SpeedMeter(region: coordinator.speedRegion)
            Text(coordinator.estimatedWPMLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .opacity(coordinator.isSending ? 1 : 0)
        .animation(.easeInOut(duration: 0.35), value: coordinator.isSending)
    }

    private var hearButton: some View {
        Button {
            coordinator.hearWord()
        } label: {
            Image(systemName: "speaker.wave.2.fill")
                .foregroundStyle(accentOn)
                .frame(width: 40, height: 40)
                .background(Circle().fill(accent))
        }
        .buttonStyle(.plain)
        .padding(Theme.Spacing.md)
        .accessibilityLabel("Hear it")
    }

    /// The bottom action zone: a fixed-height status line above a key-sized
    /// control (either the real `KeyButton`, or a same-sized "continue key"
    /// for word/stage-complete) — so nothing resizes or jumps as state changes.
    private var bottomAction: some View {
        VStack(spacing: Theme.Spacing.sm) {
            bottomStatusLine
            bottomControl
        }
    }

    @ViewBuilder
    private var bottomStatusLine: some View {
        if coordinator.stageComplete {
            Text("Stage complete!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(minHeight: 22)
        } else if coordinator.isWordComplete {
            Text("Nice!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(minHeight: 22)
        } else {
            Text(" ")
                .font(.subheadline)
                .hidden()
                .frame(minHeight: 22)
        }
    }

    @ViewBuilder
    private var bottomControl: some View {
        if coordinator.stageComplete {
            continueKey(coordinator.canGoNext ? "NEXT STAGE" : "STAGE COMPLETE") {
                coordinator.nextStage()
            }
        } else if coordinator.isWordComplete {
            continueKey("TAP TO CONTINUE · \(coordinator.countdown)") {
                coordinator.nextWord()
            }
        } else {
            KeyButton(
                mode: settings.inputMode,
                keySound: settings.keySound,
                tone: coordinator.tone,
                accent: accent,
                accentOn: accentOn,
                onDown: { coordinator.keyDown() },
                onUp: { coordinator.keyUp() },
                onSymbol: { coordinator.symbolPressed($0) }
            )
        }
    }

    /// A key-sized tappable control matching `KeyButton`'s straight-key look,
    /// used to advance past a completed word/stage without resizing the
    /// bottom action zone.
    private func continueKey(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: Theme.Radius.key)
                .fill(accent)
                .frame(maxWidth: .infinity)
                .frame(height: 150)
                .overlay(
                    Text(label)
                        .font(.headline.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(accentOn)
                )
        }
        .buttonStyle(.plain)
    }

    /// macOS keyboard sending: space = straight key, configured pair = paddle.
    /// (No-op on platforms without a hardware keyboard.)
    @ViewBuilder
    private var keyboardCapture: some View {
        if settings.keyboardSendingEnabled {
            KeyCaptureView(
                inputMode: settings.inputMode,
                dotKey: settings.paddleDotKey.first ?? "z",
                dashKey: settings.paddleDashKey.first ?? "x",
                onDown: { coordinator.keyboardDown() },
                onUp: { coordinator.keyboardUp() },
                onDot: { coordinator.keyboardSymbol(.dot) },
                onDash: { coordinator.keyboardSymbol(.dash) }
            )
        }
    }
}

/// Owns the mutable keying/matching state for `LearnSendView`: wires a
/// `KeyerEngine` (straight key) / direct symbol feed (paddle) into a
/// `SenderEngine`, tracks per-letter hesitancy, estimates sending speed,
/// auto-advances words, and lets the learner move between unlocked stages
/// (guided mode) or drill endlessly across everything unlocked so far (quiz
/// mode).
@MainActor
private final class SendCoordinator: ObservableObject, @unchecked Sendable {
    /// Guided walks the curriculum stage-by-stage; quiz draws endless random
    /// words from everything unlocked so far.
    enum LearnMode: Hashable {
        case guided
        case quiz
    }

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
    @Published private(set) var mode: LearnMode = .guided
    @Published var errorFlash = false
    @Published var timingPosition: Double = 0
    /// Whether the learner is actively mid-letter (drives the speed meter's visibility).
    @Published var isSending = false
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
    /// The current quiz word (quiz mode only).
    private var quizWord: String = ""

    private var stage: CurriculumStage { Curriculum.default.stages[currentStageIndex] }
    var word: [Character] {
        switch mode {
        case .guided: return Array(stage.words[wordIndex])
        case .quiz:   return Array(quizWord)
        }
    }

    var totalStages: Int { Curriculum.default.stages.count }
    /// Highest stage the learner may select: capped by what they've unlocked.
    private var maxSelectableStage: Int { min(totalStages - 1, progress.highestUnlockedStage) }
    var canGoPrevious: Bool { currentStageIndex > 0 }
    var canGoNext: Bool { currentStageIndex < maxSelectableStage }

    var estimatedWPMLabel: String {
        guard let wpm = estimatedWPM else { return "≈ — WPM" }
        return "≈ \(Int(wpm.rounded())) WPM"
    }

    /// Region of the smoothed sending speed relative to the target charWPM, used
    /// to light up the appropriate `SpeedMeter` pill. Uses the same 15% band as
    /// "on target" so it roughly agrees with the timing gate's grace tolerance.
    var speedRegion: SpeedRegion {
        guard let wpm = estimatedWPM else { return .onTarget }
        let g = settings.charWPM * 0.15
        if wpm < settings.charWPM - g { return .slow }
        if wpm > settings.charWPM + g { return .fast }
        return .onTarget
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

    /// Switches between guided and quiz mode, restarting from a fresh word.
    func setMode(_ newMode: LearnMode) {
        guard newMode != mode else { return }
        mode = newMode
        wordIndex = 0
        if newMode == .quiz {
            quizWord = pickQuizWord()
        }
        setupWord()
    }

    /// Picks a random word from everything unlocked so far, avoiding an
    /// immediate repeat of the current quiz word when the pool allows it.
    private func pickQuizWord() -> String {
        let pool = Curriculum.default.quizWords(throughStage: maxSelectableStage)
        guard !pool.isEmpty else { return "E" }
        guard pool.count > 1 else { return pool[0] }
        var candidate = pool.randomElement() ?? pool[0]
        var attempts = 0
        while candidate == quizWord && attempts < 5 {
            candidate = pool.randomElement() ?? pool[0]
            attempts += 1
        }
        return candidate
    }

    private func setupWord() {
        currentIndex = 0
        completedCount = 0
        isWordComplete = false
        stageComplete = false
        errorFlash = false
        isSending = false
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
            target: String(word),
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
        switch mode {
        case .guided:
            if wordIndex >= stage.words.count - 1 {
                stageComplete = true
                progress.completeStage(currentStageIndex)
            } else {
                startAutoAdvance()
            }
        case .quiz:
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
        switch mode {
        case .guided:
            guard !stageComplete, wordIndex < stage.words.count - 1 else { return }
            wordIndex += 1
            setupWord()
        case .quiz:
            quizWord = pickQuizWord()
            setupWord()
        }
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
        isSending = true
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
        // settle debounce below to judge the letter after a pause. No speed
        // estimate here — there's no real press duration.
        clearRejectionForNewAttempt()
        isSending = true
        if firstKeyDownForLetter == nil { firstKeyDownForLetter = Date() }
        let ideal = (sym == .dot ? 1.0 : 3.0) * unitMs
        keyedSoFar.append(sym)
        sender.consumeTimed(.element(sym), pressMs: ideal)
        resetSettleDebounce()
    }

    // MARK: - Keyboard input (macOS)
    //
    // The on-screen `KeyButton` owns its own sidetone gating; the keyboard has
    // no button, so these mirror the touch handlers AND drive the sidetone.

    func keyboardDown() {
        startSidetone()
        keyDown()
    }

    func keyboardUp() {
        keyUp()
        stopSidetone()
    }

    func keyboardSymbol(_ sym: MorseSymbol) {
        symbolPressed(sym)
        beepElement(sym)
    }

    private func startSidetone() {
        guard settings.keySound else { return }
        tone.frequency = settings.frequencyHz
        tone.gate(true)
    }

    private func stopSidetone() {
        guard settings.keySound else { return }
        tone.gate(false)
    }

    /// A momentary keyboard paddle press has no held duration, so sound the
    /// element for its ideal length (dot = 1 unit, dash = 3).
    private var beepGeneration = 0
    private func beepElement(_ sym: MorseSymbol) {
        guard settings.keySound else { return }
        tone.frequency = settings.frequencyHz
        tone.gate(true)
        beepGeneration += 1
        let gen = beepGeneration
        let ms = (sym == .dot ? 1.0 : 3.0) * unitMs
        DispatchQueue.main.asyncAfter(deadline: .now() + ms / 1000) { [weak self] in
            guard let self, self.beepGeneration == gen else { return }
            self.tone.gate(false)
        }
    }

    /// After a deliberate pause with no new key activity, judge the current
    /// letter — right or wrong — so the learner gets closure without having to
    /// key a trailing element they don't intend. Reset on every keyDown/keyUp/
    /// symbolPressed, so continued tapping within the window never fires this.
    private func resetSettleDebounce() {
        settleGeneration += 1
        let gen = settleGeneration
        let delayMs = max(unitMs * 7, 900)
        let delaySeconds = delayMs / 1000
        DispatchQueue.main.asyncAfter(deadline: .now() + delaySeconds) { [weak self] in
            guard let self, self.settleGeneration == gen else { return }
            self.sender.flushLetter()
            self.isSending = false
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
