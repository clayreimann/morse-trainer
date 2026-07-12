# Morse Trainer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native SwiftUI multiplatform (macOS/iPadOS/iOS) app that teaches Morse code through a word-based guided progression, with Send and Listen practice modes, adaptive per-letter hints, and configurable PARIS/Farnsworth timing.

**Architecture:** All logic and SwiftUI views live in Swift Package targets so they build and unit-test headlessly from the command line (`swift test`, `swift build`). `MorseKit` holds pure logic + audio services; `MorseUI` holds views/design-system and depends on `MorseKit`. A thin Xcode app shell (`MorseTrainerApp`, generated from an XcodeGen `project.yml`) imports `MorseUI` and hosts the `@main` App with platform-adaptive navigation. Core is built first and sequentially (everything depends on its interfaces); the five screens are independent and can be farmed to parallel agents once the core interfaces are frozen.

**Tech Stack:** Swift 6.2, SwiftUI, AVFoundation (tone generation), SwiftData (progress persistence), Swift Package Manager, XCTest, XcodeGen.

---

## File Structure

```
morse-trainer/
├── Package.swift                       # SwiftPM manifest: MorseKit, MorseUI + test targets
├── Sources/
│   ├── MorseKit/                       # PURE LOGIC + AUDIO (no views) — Phase 1
│   │   ├── MorseCode.swift             # symbol table, encode/decode
│   │   ├── Timing.swift                # PARIS + Farnsworth + word-spacing → tone schedule
│   │   ├── ToneGenerator.swift         # AVAudioEngine sine + envelope (audio; not unit-tested)
│   │   ├── MorsePlayer.swift           # schedule → drives ToneGenerator + emits highlights
│   │   ├── Keyer.swift                 # straight-key classifier + paddle; stream → elements/letters
│   │   ├── Settings.swift              # AppSettings model + SettingsStore (@AppStorage)
│   │   ├── Curriculum.swift            # stages: letters + word pools
│   │   ├── Mastery.swift               # LetterStat/confidence math (pure)
│   │   ├── ProgressStore.swift         # SwiftData persistence for mastery + stage progress
│   │   ├── SenderEngine.swift          # match keyer stream to target word (Send screen logic)
│   │   └── ListenEngine.swift          # play + check typed input (Listen screen logic)
│   └── MorseUI/                        # SWIFTUI VIEWS — Phase 2 (parallelizable)
│       ├── Theme.swift                 # colors, typography, spacing tokens
│       ├── Components/
│       │   ├── KeyButton.swift         # straight-key / paddle button, fires Keyer + sidetone
│       │   ├── LetterRow.swift         # word letters gray→green + current-letter hint
│       │   ├── TimingMeter.swift       # horizontal meter, center = target WPM
│       │   ├── MasteryStrip.swift      # per-letter mastery chips
│       │   └── ReferenceSheet.swift    # A–Z/0–9 chart, tap-to-hear, mastery tint
│       ├── LearnSendView.swift         # Practice #1
│       ├── ListenView.swift            # Practice #2
│       ├── PlaygroundView.swift        # type text → code + audio
│       ├── SettingsView.swift          # bind SettingsStore
│       └── RootView.swift              # platform-adaptive nav (tabs / split view)
├── Tests/
│   └── MorseKitTests/
│       ├── MorseCodeTests.swift
│       ├── TimingTests.swift
│       ├── MorsePlayerScheduleTests.swift
│       ├── KeyerTests.swift
│       ├── SettingsTests.swift
│       ├── CurriculumTests.swift
│       ├── MasteryTests.swift
│       ├── SenderEngineTests.swift
│       └── ListenEngineTests.swift
├── App/
│   ├── project.yml                     # XcodeGen spec (macOS + iOS)
│   ├── MorseTrainerApp.swift           # @main, injects stores, shows RootView
│   └── Info.plist
└── docs/superpowers/…
```

**Dependency rule for agents:** `MorseUI` and every screen depend ONLY on the public interfaces defined in Phase 1. Do not reach into `MorseKit` internals. If a screen needs something the core doesn't expose, stop and add it to the core task, don't inline it in the view.

---

## Phase 0 — Project scaffold

### Task 0: SwiftPM package + XcodeGen shell that builds and tests

**Files:**
- Create: `Package.swift`
- Create: `Sources/MorseKit/MorseKit.swift` (placeholder), `Sources/MorseUI/MorseUI.swift` (placeholder)
- Create: `Tests/MorseKitTests/SmokeTests.swift`
- Create: `App/project.yml`, `App/MorseTrainerApp.swift`, `App/Info.plist`

- [ ] **Step 1: Write `Package.swift`**

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MorseTrainer",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "MorseKit", targets: ["MorseKit"]),
        .library(name: "MorseUI", targets: ["MorseUI"]),
    ],
    targets: [
        .target(name: "MorseKit"),
        .target(name: "MorseUI", dependencies: ["MorseKit"]),
        .testTarget(name: "MorseKitTests", dependencies: ["MorseKit"]),
    ]
)
```

- [ ] **Step 2: Add placeholder sources so the package compiles**

`Sources/MorseKit/MorseKit.swift`:
```swift
public enum MorseKit {}
```
`Sources/MorseUI/MorseUI.swift`:
```swift
import SwiftUI
public enum MorseUI {}
```

- [ ] **Step 3: Write a smoke test**

`Tests/MorseKitTests/SmokeTests.swift`:
```swift
import XCTest
@testable import MorseKit

final class SmokeTests: XCTestCase {
    func testPackageCompiles() { XCTAssertTrue(true) }
}
```

- [ ] **Step 4: Build and test from CLI**

Run: `swift test`
Expected: builds, `SmokeTests` passes.

- [ ] **Step 5: Write the XcodeGen shell** (used later for on-device runs; not needed for `swift test`)

`App/project.yml`:
```yaml
name: MorseTrainerApp
options:
  bundleIdPrefix: com.morsetrainer
  deploymentTarget:
    macOS: "14.0"
    iOS: "17.0"
packages:
  MorseTrainer:
    path: ..
targets:
  MorseTrainerApp:
    type: application
    platform: [macOS, iOS]
    sources: [.]
    dependencies:
      - package: MorseTrainer
        product: MorseUI
    settings:
      base:
        INFOPLIST_FILE: App/Info.plist
        GENERATE_INFOPLIST_FILE: YES
```

`App/MorseTrainerApp.swift`:
```swift
import SwiftUI
import MorseUI

@main
struct MorseTrainerApp: App {
    var body: some Scene {
        WindowGroup { RootView() }
    }
}
```
`App/Info.plist`: minimal (empty `<dict/>`); XcodeGen fills the rest.

- [ ] **Step 6: Commit**

```bash
git add Package.swift Sources Tests App
git commit -m "chore: scaffold SwiftPM package + XcodeGen app shell"
```

> Note: `RootView` doesn't exist yet (Task 15). The app shell won't build until Phase 2; that's expected. `swift test` is the verification gate for Phase 1.

---

## Phase 1 — Shared core (`MorseKit`), sequential, TDD

Each task: write failing test → run (fail) → implement → run (pass) → commit. Run tests with
`swift test --filter <ClassName>`.

### Task 1: `MorseCode` — symbol table + encode/decode

**Files:** Create `Sources/MorseKit/MorseCode.swift`, `Tests/MorseKitTests/MorseCodeTests.swift`

- [ ] **Step 1: Failing test**

```swift
import XCTest
@testable import MorseKit

final class MorseCodeTests: XCTestCase {
    func testKnownLetters() {
        XCTAssertEqual(MorseCode.code(for: "A"), [.dot, .dash])
        XCTAssertEqual(MorseCode.code(for: "N"), [.dash, .dot])
        XCTAssertEqual(MorseCode.code(for: "5"), [.dot,.dot,.dot,.dot,.dot])
    }
    func testCaseInsensitive() {
        XCTAssertEqual(MorseCode.code(for: "a"), MorseCode.code(for: "A"))
    }
    func testDecodeRoundTrip() {
        for c in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789" {
            let code = MorseCode.code(for: c)!
            XCTAssertEqual(MorseCode.character(for: code), c)
        }
    }
    func testEncodeString() {
        // "AN" -> [[.dot,.dash],[.dash,.dot]]
        XCTAssertEqual(MorseCode.encode("AN"), [[.dot,.dash],[.dash,.dot]])
    }
    func testUnknownCharacterIsNil() {
        XCTAssertNil(MorseCode.code(for: "~"))
    }
}
```

- [ ] **Step 2: Run — expect FAIL** (`swift test --filter MorseCodeTests`) — "MorseCode not found".

- [ ] **Step 3: Implement**

```swift
public enum MorseSymbol: Equatable, Sendable { case dot, dash }

public enum MorseCode {
    public static let table: [Character: [MorseSymbol]] = [
        "A": [.dot,.dash], "B": [.dash,.dot,.dot,.dot], "C": [.dash,.dot,.dash,.dot],
        "D": [.dash,.dot,.dot], "E": [.dot], "F": [.dot,.dot,.dash,.dot],
        "G": [.dash,.dash,.dot], "H": [.dot,.dot,.dot,.dot], "I": [.dot,.dot],
        "J": [.dot,.dash,.dash,.dash], "K": [.dash,.dot,.dash], "L": [.dot,.dash,.dot,.dot],
        "M": [.dash,.dash], "N": [.dash,.dot], "O": [.dash,.dash,.dash],
        "P": [.dot,.dash,.dash,.dot], "Q": [.dash,.dash,.dot,.dash], "R": [.dot,.dash,.dot],
        "S": [.dot,.dot,.dot], "T": [.dash], "U": [.dot,.dot,.dash],
        "V": [.dot,.dot,.dot,.dash], "W": [.dot,.dash,.dash], "X": [.dash,.dot,.dot,.dash],
        "Y": [.dash,.dot,.dash,.dash], "Z": [.dash,.dash,.dot,.dot],
        "0": [.dash,.dash,.dash,.dash,.dash], "1": [.dot,.dash,.dash,.dash,.dash],
        "2": [.dot,.dot,.dash,.dash,.dash], "3": [.dot,.dot,.dot,.dash,.dash],
        "4": [.dot,.dot,.dot,.dot,.dash], "5": [.dot,.dot,.dot,.dot,.dot],
        "6": [.dash,.dot,.dot,.dot,.dot], "7": [.dash,.dash,.dot,.dot,.dot],
        "8": [.dash,.dash,.dash,.dot,.dot], "9": [.dash,.dash,.dash,.dash,.dot],
        ".": [.dot,.dash,.dot,.dash,.dot,.dash], ",": [.dash,.dash,.dot,.dot,.dash,.dash],
        "?": [.dot,.dot,.dash,.dash,.dot,.dot], "/": [.dash,.dot,.dot,.dash,.dot],
    ]
    private static let reverse: [[MorseSymbol]: Character] = {
        var m = [[MorseSymbol]: Character]()
        for (k, v) in table { m[v] = k }
        return m
    }()
    public static func code(for c: Character) -> [MorseSymbol]? {
        table[Character(c.uppercased())]
    }
    public static func character(for code: [MorseSymbol]) -> Character? { reverse[code] }
    public static func encode(_ text: String) -> [[MorseSymbol]?] {
        text.map { code(for: $0) }
    }
}
```

- [ ] **Step 4: Run — expect PASS.**
- [ ] **Step 5: Commit** — `git commit -am "feat(core): MorseCode table + encode/decode"`

---

### Task 2: `Timing` — PARIS unit, Farnsworth, word-spacing → tone schedule

**Files:** Create `Sources/MorseKit/Timing.swift`, `Tests/MorseKitTests/TimingTests.swift`

Timing model (durations in ms):
- `unitMs = 1200 / charWPM`.
- Within a character: element `on` (dot=1u, dash=3u), separated by `off` 1u (intra-element gap).
- Between characters: `off` = inter-char gap.
- Between words: `off` = inter-word gap.
- **Farnsworth:** characters sent at `charWPM`; the *standard* inter-char (3u) and inter-word (7u)
  gaps are stretched so the whole string's duration equals what it would be at `effectiveWPM`.
  Distribute extra time in a 3:7 ratio between inter-char and inter-word gaps. If
  `effectiveWPM >= charWPM`, no stretch (gaps stay 3u/7u).
- **Word spacing:** multiply the (possibly Farnsworth-stretched) inter-word gap by `wordSpacing`.

- [ ] **Step 1: Failing test**

```swift
import XCTest
@testable import MorseKit

final class TimingTests: XCTestCase {
    func testUnitMs() {
        XCTAssertEqual(Timing.unitMs(charWPM: 20), 60, accuracy: 0.0001)
    }
    func testParisIdentity() {
        // "PARIS " at 20 WPM (no Farnsworth) = 50 units = 3000 ms
        let s = TimingSettings(charWPM: 20, effectiveWPM: 20, wordSpacing: 1)
        let total = Timing.schedule(for: "PARIS ", settings: s)
            .reduce(0.0) { $0 + $1.duration }
        XCTAssertEqual(total, 3000, accuracy: 0.001)
    }
    func testScheduleForE() {
        // "E" = single dot = one .on of 1u; no trailing gap for a single char/no next char
        let s = TimingSettings(charWPM: 20, effectiveWPM: 20, wordSpacing: 1)
        XCTAssertEqual(Timing.schedule(for: "E", settings: s), [ToneEvent(on: true, duration: 60)])
    }
    func testFarnsworthStretchesTotalToEffective() {
        // char 20 WPM, effective 10 WPM: "PARIS " should take the 10-WPM duration = 6000 ms
        let s = TimingSettings(charWPM: 20, effectiveWPM: 10, wordSpacing: 1)
        let total = Timing.schedule(for: "PARIS ", settings: s)
            .reduce(0.0) { $0 + $1.duration }
        XCTAssertEqual(total, 6000, accuracy: 0.5)
    }
    func testWordSpacingAddsGapBetweenWords() {
        let base = TimingSettings(charWPM: 20, effectiveWPM: 20, wordSpacing: 1)
        let wide = TimingSettings(charWPM: 20, effectiveWPM: 20, wordSpacing: 2)
        let b = Timing.schedule(for: "E E", settings: base).reduce(0.0){$0+$1.duration}
        let w = Timing.schedule(for: "E E", settings: wide).reduce(0.0){$0+$1.duration}
        XCTAssertGreaterThan(w, b)
    }
}
```

- [ ] **Step 2: Run — expect FAIL.**

- [ ] **Step 3: Implement**

```swift
public struct TimingSettings: Equatable, Sendable {
    public var charWPM: Double
    public var effectiveWPM: Double
    public var wordSpacing: Double
    public init(charWPM: Double, effectiveWPM: Double, wordSpacing: Double) {
        self.charWPM = charWPM; self.effectiveWPM = effectiveWPM; self.wordSpacing = wordSpacing
    }
}

public struct ToneEvent: Equatable, Sendable {
    public let on: Bool          // true = tone, false = silence
    public let duration: Double  // ms
    public init(on: Bool, duration: Double) { self.on = on; self.duration = duration }
}

public enum Timing {
    public static func unitMs(charWPM: Double) -> Double { 1200.0 / charWPM }

    public static func schedule(for text: String, settings s: TimingSettings) -> [ToneEvent] {
        let u = unitMs(charWPM: s.charWPM)
        // Farnsworth: compute stretch for standard 3u/7u gaps.
        // Total standard units in the string = element+intra units + 3u*(interChar) + 7u*(interWord).
        // We stretch only the gap portion so total time == time at effectiveWPM.
        let chars = Array(text.uppercased())
        // Precompute element on/off (intra) events per character + count gaps.
        var elementUnits = 0.0
        var interCharCount = 0
        var interWordCount = 0
        var perChar: [[ToneEvent]] = []
        for (i, c) in chars.enumerated() {
            if c == " " {
                interWordCount += 1
                perChar.append([]) // marker; gap emitted below
                continue
            }
            guard let code = MorseCode.code(for: c) else { perChar.append([]); continue }
            var evs: [ToneEvent] = []
            for (j, sym) in code.enumerated() {
                let onU = sym == .dot ? 1.0 : 3.0
                elementUnits += onU
                evs.append(ToneEvent(on: true, duration: onU * u))
                if j < code.count - 1 { evs.append(ToneEvent(on: false, duration: u)); elementUnits += 1 }
            }
            perChar.append(evs)
            // count an inter-char gap if the next non-space char is a letter (not word break/end)
            if i < chars.count - 1 && chars[i+1] != " " { interCharCount += 1 }
        }
        // Standard gap units and Farnsworth-stretched gap unit sizes.
        let stdGapUnits = Double(interCharCount) * 3 + Double(interWordCount) * 7
        let standardTotalUnits = elementUnits + stdGapUnits
        let targetTotalMs = standardTotalUnits * unitMs(charWPM: s.effectiveWPM)
        let elementMs = elementUnits * u
        let extraGapMs = max(0, targetTotalMs - elementMs)   // total ms available for gaps
        // Distribute in 3:7 ratio to inter-char vs inter-word gap *slots*.
        let charGapWeight = Double(interCharCount) * 3
        let wordGapWeight = Double(interWordCount) * 7
        let weight = charGapWeight + wordGapWeight
        let interCharGapMs: Double = interCharCount == 0 ? 0 :
            (weight == 0 ? 0 : extraGapMs * (charGapWeight / weight) / Double(interCharCount))
        var interWordGapMs: Double = interWordCount == 0 ? 0 :
            (weight == 0 ? 0 : extraGapMs * (wordGapWeight / weight) / Double(interWordCount))
        interWordGapMs *= s.wordSpacing
        // Emit with gaps between characters/words.
        var out: [ToneEvent] = []
        for (i, evs) in perChar.enumerated() {
            if chars[i] == " " {
                out.append(ToneEvent(on: false, duration: interWordGapMs)); continue
            }
            out.append(contentsOf: evs)
            if i < chars.count - 1 && chars[i+1] != " " {
                out.append(ToneEvent(on: false, duration: interCharGapMs))
            }
        }
        return out
    }
}
```

> Implementer note: the `testParisIdentity`/`testScheduleForE` cases pin exact ms; if the trailing-space handling differs, adjust so `"PARIS "` = 3000 ms at 20/20. The trailing word gap for a string ending in space counts as one inter-word gap.

- [ ] **Step 4: Run — expect PASS** (all `TimingTests`).
- [ ] **Step 5: Commit** — `git commit -am "feat(core): PARIS/Farnsworth/word-spacing tone schedule"`

---

### Task 3: `ToneGenerator` — click-free sine (audio; envelope unit-tested)

**Files:** Create `Sources/MorseKit/ToneGenerator.swift`, add `Tests/MorseKitTests/EnvelopeTests.swift`

Audio playback itself isn't unit-tested; the **envelope ramp** helper is. Use `AVAudioEngine` +
`AVAudioSourceNode` generating a sine at `frequency`, gated by an amplitude envelope with ~5 ms
attack/release to prevent clicks.

- [ ] **Step 1: Failing test (envelope only)**

```swift
import XCTest
@testable import MorseKit

final class EnvelopeTests: XCTestCase {
    func testRampReachesFullThenZero() {
        let env = Envelope(sampleRate: 48000, rampMs: 5)
        XCTAssertEqual(env.gain(atSample: 0, gateOn: true), 0, accuracy: 0.01)   // start of attack
        XCTAssertEqual(env.gain(atSample: 240, gateOn: true), 1, accuracy: 0.01) // 5ms in = full
        XCTAssertEqual(env.gain(atSample: 10_000, gateOn: true), 1, accuracy: 0.0001)
    }
}
```

- [ ] **Step 2: Run — expect FAIL.**

- [ ] **Step 3: Implement `Envelope` + `ToneGenerator`**

```swift
import AVFoundation

public struct Envelope {
    let rampSamples: Double
    public init(sampleRate: Double, rampMs: Double) { rampSamples = sampleRate * rampMs / 1000 }
    /// Linear attack from gate-on; used by ToneGenerator to scale amplitude near edges.
    public func gain(atSample n: Int, gateOn: Bool) -> Double {
        guard gateOn else { return 0 }
        return min(1, Double(n) / rampSamples)
    }
}

public final class ToneGenerator {
    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private let sampleRate: Double = 48000
    private var phase: Double = 0
    private var gateOn = false
    private var gateSample = 0
    public var frequency: Double = 550
    private lazy var envelope = Envelope(sampleRate: sampleRate, rampMs: 5)

    public init() { setup() }
    private func setup() {
        let node = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }
            let abl = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let inc = 2 * Double.pi * self.frequency / self.sampleRate
            for frame in 0..<Int(frameCount) {
                let g = self.envelope.gain(atSample: self.gateSample, gateOn: self.gateOn)
                let s = Float(sin(self.phase) * g * 0.6)
                self.phase += inc; if self.phase > 2 * .pi { self.phase -= 2 * .pi }
                if self.gateOn { self.gateSample += 1 }
                for buf in abl { (buf.mData!.assumingMemoryBound(to: Float.self))[frame] = s }
            }
            return noErr
        }
        sourceNode = node
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: nil)
    }
    public func start() { try? engine.start() }
    public func stop() { engine.stop() }
    public func gate(_ on: Bool) { if on { gateSample = 0 }; gateOn = on }
}
```

- [ ] **Step 4: Run — expect PASS** (`EnvelopeTests`). Audio verified manually later on device.
- [ ] **Step 5: Commit** — `git commit -am "feat(core): ToneGenerator sine + envelope"`

---

### Task 4: `MorsePlayer` — play a schedule, emit highlight callbacks

**Files:** Create `Sources/MorseKit/MorsePlayer.swift`, `Tests/MorseKitTests/MorsePlayerScheduleTests.swift`

`MorsePlayer` turns text+settings into the `[ToneEvent]` schedule (via `Timing`) and plays it by
gating `ToneGenerator` on a timer, invoking an `onSymbolBoundary` callback so UIs can highlight
progress. The **schedule building** is unit-tested; playback timing is manual.

- [ ] **Step 1: Failing test**

```swift
import XCTest
@testable import MorseKit

final class MorsePlayerScheduleTests: XCTestCase {
    func testBuildsScheduleFromTiming() {
        let s = TimingSettings(charWPM: 20, effectiveWPM: 20, wordSpacing: 1)
        let player = MorsePlayer(tone: ToneGenerator())
        XCTAssertEqual(player.buildSchedule(for: "E", settings: s),
                       Timing.schedule(for: "E", settings: s))
    }
}
```

- [ ] **Step 2: Run — expect FAIL.**

- [ ] **Step 3: Implement**

```swift
import Foundation

public final class MorsePlayer {
    private let tone: ToneGenerator
    public init(tone: ToneGenerator) { self.tone = tone }

    public func buildSchedule(for text: String, settings: TimingSettings) -> [ToneEvent] {
        Timing.schedule(for: text, settings: settings)
    }

    /// Plays the schedule. `onCharBoundary` fires with the index of the character just completed.
    public func play(_ text: String, settings: TimingSettings,
                     frequency: Double = 550,
                     onCharBoundary: @escaping (Int) -> Void = { _ in },
                     completion: @escaping () -> Void = {}) {
        tone.frequency = frequency
        tone.start()
        let schedule = buildSchedule(for: text, settings: settings)
        var t = 0.0
        for ev in schedule {
            let on = ev.on
            DispatchQueue.main.asyncAfter(deadline: .now() + t/1000) { self.tone.gate(on) }
            t += ev.duration
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + t/1000) {
            self.tone.gate(false); completion()
        }
    }
    public func stop() { tone.gate(false); tone.stop() }
}
```

- [ ] **Step 4: Run — expect PASS.**
- [ ] **Step 5: Commit** — `git commit -am "feat(core): MorsePlayer schedule + playback"`

---

### Task 5: `Keyer` — straight-key classifier + element/letter stream

**Files:** Create `Sources/MorseKit/Keyer.swift`, `Tests/MorseKitTests/KeyerTests.swift`

Given press durations and inter-press gaps (ms) plus the current `unitMs`, classify each press as
dot/dash and each gap as intra-char / inter-char / inter-word. Thresholds (in units):
- press ≥ 2u ⇒ dash, else dot.
- gap < 2u ⇒ intra-char; 2u ≤ gap < 5u ⇒ inter-char (letter break); ≥ 5u ⇒ word break.

`KeyerEngine` consumes `keyDown(at:)`/`keyUp(at:)` timestamps and emits `KeyerEvent`s.

- [ ] **Step 1: Failing test**

```swift
import XCTest
@testable import MorseKit

final class KeyerTests: XCTestCase {
    let unit = 60.0 // 20 WPM
    func testClassifyPress() {
        let k = Keyer(unitMs: unit)
        XCTAssertEqual(k.symbol(forPressMs: 55), .dot)   // ~1u
        XCTAssertEqual(k.symbol(forPressMs: 200), .dash) // >2u
    }
    func testClassifyGap() {
        let k = Keyer(unitMs: unit)
        XCTAssertEqual(k.gap(forMs: 60), .intraChar)   // 1u
        XCTAssertEqual(k.gap(forMs: 180), .interChar)  // 3u
        XCTAssertEqual(k.gap(forMs: 420), .interWord)  // 7u
    }
    func testStreamAssemblesLetterA() {
        // dot (dn 0 up 60), gap 60, dash (dn 120 up 300) then long gap -> letter A
        let e = KeyerEngine(unitMs: unit)
        var out: [KeyerEvent] = []
        e.onEvent = { out.append($0) }
        e.keyDown(at: 0);   e.keyUp(at: 60)
        e.keyDown(at: 120); e.keyUp(at: 300)
        e.flush(at: 900)    // long trailing gap => letter break
        XCTAssertEqual(out, [.element(.dot), .element(.dash), .letterBreak])
    }
}
```

- [ ] **Step 2: Run — expect FAIL.**

- [ ] **Step 3: Implement**

```swift
public enum GapKind: Equatable { case intraChar, interChar, interWord }
public enum KeyerEvent: Equatable { case element(MorseSymbol), letterBreak, wordBreak }

public struct Keyer {
    public let unitMs: Double
    public init(unitMs: Double) { self.unitMs = unitMs }
    public func symbol(forPressMs ms: Double) -> MorseSymbol { ms >= 2 * unitMs ? .dash : .dot }
    public func gap(forMs ms: Double) -> GapKind {
        if ms >= 5 * unitMs { return .interWord }
        if ms >= 2 * unitMs { return .interChar }
        return .intraChar
    }
}

public final class KeyerEngine {
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
```

- [ ] **Step 4: Run — expect PASS.**
- [ ] **Step 5: Commit** — `git commit -am "feat(core): Keyer classifier + streaming engine"`

---

### Task 6: `Settings` — model + persisted store

**Files:** Create `Sources/MorseKit/Settings.swift`, `Tests/MorseKitTests/SettingsTests.swift`

- [ ] **Step 1: Failing test**

```swift
import XCTest
@testable import MorseKit

final class SettingsTests: XCTestCase {
    func testDefaults() {
        let s = AppSettings()
        XCTAssertEqual(s.frequencyHz, 550)
        XCTAssertEqual(s.charWPM, 20)
        XCTAssertEqual(s.effectiveWPM, 20)
        XCTAssertEqual(s.wordSpacing, 1)
        XCTAssertTrue(s.keySound)
        XCTAssertEqual(s.inputMode, .straightKey)
        XCTAssertEqual(s.timingGate, .off)
        XCTAssertEqual(s.difficulty, .easy)
    }
    func testTimingSettingsProjection() {
        var s = AppSettings(); s.charWPM = 20; s.effectiveWPM = 10; s.wordSpacing = 1.5
        XCTAssertEqual(s.timing, TimingSettings(charWPM: 20, effectiveWPM: 10, wordSpacing: 1.5))
    }
}
```

- [ ] **Step 2: Run — expect FAIL.**

- [ ] **Step 3: Implement**

```swift
public enum InputMode: String, Codable, Sendable { case straightKey, paddle }
public enum TimingGate: String, Codable, Sendable { case off, matchWPM, consistent }
public enum Difficulty: String, Codable, Sendable { case easy, hard }

public struct AppSettings: Equatable, Sendable {
    public var charWPM: Double = 20
    public var effectiveWPM: Double = 20
    public var wordSpacing: Double = 1
    public var frequencyHz: Double = 550
    public var keySound: Bool = true
    public var inputMode: InputMode = .straightKey
    public var timingGate: TimingGate = .off
    public var gateGracePercent: Double = 25
    public var difficulty: Difficulty = .easy
    public init() {}
    public var timing: TimingSettings {
        TimingSettings(charWPM: charWPM, effectiveWPM: effectiveWPM, wordSpacing: wordSpacing)
    }
}
```

> `SettingsStore` (the `@AppStorage`-backed `ObservableObject`) is created in the UI layer (Task 14)
> because `@AppStorage` is UI-framework bound; `AppSettings` here stays pure/testable.

- [ ] **Step 4: Run — expect PASS.**
- [ ] **Step 5: Commit** — `git commit -am "feat(core): AppSettings model"`

---

### Task 7: `Curriculum` — stages of letters + word pools

**Files:** Create `Sources/MorseKit/Curriculum.swift`, `Tests/MorseKitTests/CurriculumTests.swift`

- [ ] **Step 1: Failing test**

```swift
import XCTest
@testable import MorseKit

final class CurriculumTests: XCTestCase {
    func testStagesAreOrderedAndCumulative() {
        let stages = Curriculum.default.stages
        XCTAssertEqual(stages.first?.newLetters, ["E","T","A"])
        // every word in a stage uses only letters unlocked up to and including that stage
        var unlocked = Set<Character>()
        for stage in stages {
            unlocked.formUnion(stage.newLetters.map { Character($0) })
            for word in stage.words {
                XCTAssertTrue(Set(word).isSubset(of: unlocked), "\(word) uses unlearned letters")
            }
        }
    }
    func testLettersUnlockedThroughStage() {
        XCTAssertEqual(Curriculum.default.lettersUnlocked(throughStage: 1),
                       Set("ETAON".map { $0 }))
    }
}
```

- [ ] **Step 2: Run — expect FAIL.**

- [ ] **Step 3: Implement** (word pools drawn from the spec's sample curriculum; ensure every word is a subset of unlocked letters)

```swift
public struct CurriculumStage: Equatable, Sendable {
    public let index: Int
    public let newLetters: [String]
    public let words: [String]
}

public struct Curriculum: Sendable {
    public let stages: [CurriculumStage]
    public static let `default` = Curriculum(stages: [
        .init(index: 0, newLetters: ["E","T","A"], words: ["AT","ATE","EAT","TEA","TAT","EATE"].filter{_ in true}),
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
```

> Implementer note: verify each word against `lettersUnlocked`; fix the pools if any test word slips
> in an unlearned letter (e.g. remove `"EATE"` if you drop the filler). The test enforces this.

- [ ] **Step 4: Run — expect PASS.**
- [ ] **Step 5: Commit** — `git commit -am "feat(core): guided curriculum stages"`

---

### Task 8: `Mastery` — per-letter confidence math (pure)

**Files:** Create `Sources/MorseKit/Mastery.swift`, `Tests/MorseKitTests/MasteryTests.swift`

- [ ] **Step 1: Failing test**

```swift
import XCTest
@testable import MorseKit

final class MasteryTests: XCTestCase {
    func testConfidenceRisesWithCorrectLowHesitancy() {
        var s = LetterStat(letter: "E")
        for _ in 0..<8 { s.record(correct: true, hesitancyMs: 200) }
        XCTAssertGreaterThan(s.confidence, MasteryPolicy.hintSuppressThreshold)
    }
    func testConfidenceStaysLowWithErrors() {
        var s = LetterStat(letter: "Q")
        for _ in 0..<8 { s.record(correct: false, hesitancyMs: 1500) }
        XCTAssertLessThan(s.confidence, MasteryPolicy.hintSuppressThreshold)
    }
    func testHintSuppressed() {
        var s = LetterStat(letter: "E")
        for _ in 0..<8 { s.record(correct: true, hesitancyMs: 150) }
        XCTAssertTrue(MasteryPolicy.shouldSuppressHint(for: s))
    }
}
```

- [ ] **Step 2: Run — expect FAIL.**

- [ ] **Step 3: Implement**

```swift
public struct LetterStat: Equatable, Sendable {
    public let letter: String
    public private(set) var attempts = 0
    public private(set) var correct = 0
    public private(set) var hesitancyEMA = 0.0   // ms
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
```

- [ ] **Step 4: Run — expect PASS.**
- [ ] **Step 5: Commit** — `git commit -am "feat(core): per-letter mastery/confidence"`

---

### Task 9: `ProgressStore` — SwiftData persistence

**Files:** Create `Sources/MorseKit/ProgressStore.swift`, `Tests/MorseKitTests/ProgressStoreTests.swift`

Wrap SwiftData with an in-memory container option for tests. Persist `LetterRecord` and
`StageRecord`; expose async-free synchronous methods for the engines.

- [ ] **Step 1: Failing test** (in-memory container)

```swift
import XCTest
import SwiftData
@testable import MorseKit

final class ProgressStoreTests: XCTestCase {
    func testRecordAndReadBackConfidence() throws {
        let store = try ProgressStore(inMemory: true)
        for _ in 0..<8 { store.record(letter: "E", correct: true, hesitancyMs: 150) }
        XCTAssertTrue(store.isHintSuppressed(for: "E"))
        XCTAssertFalse(store.isHintSuppressed(for: "Q"))
    }
    func testStageUnlockPersists() throws {
        let store = try ProgressStore(inMemory: true)
        XCTAssertEqual(store.highestUnlockedStage, 0)
        store.completeStage(0)
        XCTAssertEqual(store.highestUnlockedStage, 1)
    }
}
```

- [ ] **Step 2: Run — expect FAIL.**

- [ ] **Step 3: Implement**

```swift
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

public final class ProgressStore {
    private let container: ModelContainer
    private var ctx: ModelContext { container.mainContext }
    public init(inMemory: Bool = false) throws {
        let cfg = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        container = try ModelContainer(for: LetterRecord.self, StageRecord.self, configurations: cfg)
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
```

Add to `Mastery.swift` a rehydrate helper:
```swift
extension LetterStat {
    public func rehydrated(attempts: Int, correct: Int, hesitancyEMA: Double) -> LetterStat {
        var s = self; s.attempts = attempts; s.correct = correct; s.hesitancyEMA = hesitancyEMA; return s
    }
}
```
(Change `LetterStat`'s `attempts/correct/hesitancyEMA` from `private(set)` to `internal(set)` so the
extension can set them, or add a memberwise internal init.)

- [ ] **Step 4: Run — expect PASS.**
- [ ] **Step 5: Commit** — `git commit -am "feat(core): SwiftData ProgressStore"`

---

### Task 10: `SenderEngine` — match keyer stream to target word

**Files:** Create `Sources/MorseKit/SenderEngine.swift`, `Tests/MorseKitTests/SenderEngineTests.swift`

Consumes `KeyerEvent`s, compares the accumulating letter's elements to the expected letter's code,
turns letters green on a correct match, exposes current letter index, records mastery + timing
feedback. Pattern-only pass; timing gate optional.

- [ ] **Step 1: Failing test**

```swift
import XCTest
@testable import MorseKit

final class SenderEngineTests: XCTestCase {
    func makeEngine(_ word: String) -> SenderEngine {
        SenderEngine(target: word, unitMs: 60, gate: .off, gracePercent: 25)
    }
    func testCorrectLetterTurnsGreen() {
        let e = makeEngine("TE")
        e.consume(.element(.dash)); e.consume(.letterBreak)   // T
        XCTAssertEqual(e.completedCount, 1)
        XCTAssertEqual(e.currentIndex, 1)
        e.consume(.element(.dot)); e.consume(.letterBreak)    // E
        XCTAssertTrue(e.isComplete)
    }
    func testWrongPatternDoesNotAdvance() {
        let e = makeEngine("T")
        e.consume(.element(.dot)); e.consume(.letterBreak)    // wrong (E not T)
        XCTAssertEqual(e.completedCount, 0)
        XCTAssertTrue(e.lastLetterWasError)
    }
    func testGateMatchWPMRejectsBadTiming() {
        let e = SenderEngine(target: "T", unitMs: 60, gate: .matchWPM, gracePercent: 20)
        e.consumeTimed(.element(.dash), pressMs: 400)  // way over 3u=180ms +20%
        e.consume(.letterBreak)
        XCTAssertEqual(e.completedCount, 0) // pattern ok but timing gate fails
    }
}
```

- [ ] **Step 2: Run — expect FAIL.**

- [ ] **Step 3: Implement**

```swift
public final class SenderEngine {
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
            buffer.append(sym)
            if let p = pressMs { pressTimings.append(p) }
        case .letterBreak, .wordBreak:
            evaluateLetter()
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
```

> Note the `evaluateLetter` uses `buffer` for timing checks before clearing; in `.matchWPM` compare
> against `buffer.count` captured before reset (it is — evaluated inline).

- [ ] **Step 4: Run — expect PASS.**
- [ ] **Step 5: Commit** — `git commit -am "feat(core): SenderEngine matching + timing gate"`

---

### Task 11: `ListenEngine` — play + check typed input

**Files:** Create `Sources/MorseKit/ListenEngine.swift`, `Tests/MorseKitTests/ListenEngineTests.swift`

- [ ] **Step 1: Failing test**

```swift
import XCTest
@testable import MorseKit

final class ListenEngineTests: XCTestCase {
    func testLiveModeChecksPerCharacter() {
        let e = ListenEngine(target: "TEA", mode: .live)
        XCTAssertEqual(e.type("T"), .correct)
        XCTAssertEqual(e.type("X"), .incorrect)   // wrong second char
        XCTAssertEqual(e.type("E"), .correct)
        XCTAssertEqual(e.type("A"), .correct)
        XCTAssertTrue(e.isComplete)
    }
    func testCopyThenCheckComparesWhole() {
        let e = ListenEngine(target: "TEA", mode: .copyThenCheck)
        let result = e.submit("TEA")
        XCTAssertEqual(result, .correct)
        XCTAssertEqual(e.submit("TEX"), .incorrect)
    }
}
```

- [ ] **Step 2: Run — expect FAIL.**

- [ ] **Step 3: Implement**

```swift
public enum ListenMode: Equatable { case live, copyThenCheck }
public enum CheckResult: Equatable { case correct, incorrect }

public final class ListenEngine {
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
```

- [ ] **Step 4: Run — expect PASS.**
- [ ] **Step 5: Commit** — `git commit -am "feat(core): ListenEngine live + copy-then-check"`

**GATE — end of Phase 1:** Run `swift test`. All core tests pass. The public interfaces above are now
frozen; Phase 2 screens depend only on them. **Do not change core signatures during Phase 2 without
updating this plan.**

---

## Phase 2 — `MorseUI` + app shell

These five screen tasks and the design-system task are **independent** and can be dispatched to
parallel agents. Each consumes only the frozen Phase-1 interfaces. Verification for UI tasks:
`swift build` (compiles against the package) + SwiftUI `#Preview` inspection; audio/gesture behavior
is confirmed manually in the Xcode app shell (Task 16). Where a screen has extractable logic, add an
XCTest to `MorseKitTests` for it.

### Task 12: Design system — `Theme` + shared components

**Files:** Create `Sources/MorseUI/Theme.swift`, `Sources/MorseUI/Components/{KeyButton,LetterRow,TimingMeter,MasteryStrip,ReferenceSheet}.swift`

Consumed interfaces: `MorseCode`, `MorseSymbol`, `LetterStat`/`ProgressStore` (for tint), `KeyerEngine`, `ToneGenerator`.

- [ ] **Step 1:** `Theme.swift` — color tokens (`learning` amber, `mastered` green, `locked` gray, `current` blue), typography (monospace for code), spacing. Expose as `enum Theme` with static `Color`s that adapt to light/dark.
- [ ] **Step 2:** `TimingMeter` — a `View` taking `position: Double` (−1…+1, 0 = target WPM) rendering a horizontal gradient bar with a center tick and a marker dot at `position`. Add `#Preview` showing positions −0.5, 0, +0.6.
- [ ] **Step 3:** `LetterRow` — takes `letters: [Character]`, `completedCount: Int`, `currentIndex: Int`, `hintForCurrent: [MorseSymbol]?` (nil = suppressed/hard). Renders letters gray/green/blue; shows the current letter's dot/dash code beneath only when `hintForCurrent != nil`. `#Preview` for word "NOTE" with current index 2 and a hint, and again with `nil` hint.
- [ ] **Step 4:** `KeyButton` — a large button. Straight-key mode: reports press-down/up timestamps (via `DragGesture(minimumDistance:0)` capturing `Date`) to a closure; paddle mode: two buttons emitting `.dot`/`.dash`. On press, calls `ToneGenerator.gate(true/false)` when Key Sound is on. Props: `mode: InputMode`, `keySound: Bool`, `onDown/onUp` or `onSymbol`.
- [ ] **Step 5:** `MasteryStrip` — takes `[(Character, Double)]` (letter, confidence) → colored chips (green ≥0.7, amber >0, gray =0). `#Preview`.
- [ ] **Step 6:** `ReferenceSheet` — a sheet listing A–Z/0–9 with code; each row tap plays via a passed `MorsePlayer`; tinted by a passed `confidence(for:)` closure. `#Preview` with stub confidences.
- [ ] **Step 7:** `swift build` (expect success) and confirm previews render. **Commit** — `git commit -am "feat(ui): theme + shared components"`

### Task 13: `LearnSendView` (Practice #1)

**Files:** Create `Sources/MorseUI/LearnSendView.swift`

Consumed interfaces: `SenderEngine`, `KeyerEngine`, `Curriculum`, `ProgressStore`, `MorsePlayer`, `AppSettings`, components from Task 12.

- [ ] **Step 1:** View owns the current stage word, a `KeyerEngine(unitMs:)` and a `SenderEngine(target:…)`. Wire `KeyerEngine.onEvent` → `SenderEngine.consumeTimed`. On `onLetterComplete`, call `ProgressStore.record(...)` with measured hesitancy; advance `LetterRow`. On `onError`, reveal the current letter's hint and flag red briefly.
- [ ] **Step 2:** Hint logic: `hintForCurrent = (settings.difficulty == .hard) ? nil : (progress.isHintSuppressed(for: currentLetter) ? nil : MorseCode.code(for: currentLetter))`.
- [ ] **Step 3:** "Hear it" button → `MorsePlayer.play(word, settings: settings.timing, frequency: settings.frequencyHz)`.
- [ ] **Step 4:** Show `TimingMeter` fed from the last element's measured press vs ideal. On word complete, mark stage progress; when all stage words done, `progress.completeStage(index)` and advance.
- [ ] **Step 5 (test):** Add `SenderFlowTests` in `MorseKitTests` driving a `SenderEngine` through a full word to assert green progression + a mastery record is produced (logic-level; no view). Run `swift test --filter SenderFlow`.
- [ ] **Step 6:** `swift build`; inspect `#Preview`. **Commit** — `git commit -am "feat(ui): LearnSend screen"`

### Task 14: `SettingsView` + `SettingsStore`

**Files:** Create `Sources/MorseUI/SettingsView.swift` (includes `SettingsStore`)

- [ ] **Step 1:** `SettingsStore: ObservableObject` bridging `AppSettings` to `@AppStorage` keys (one per field). Expose `var settings: AppSettings` computed from the stored values, and setters.
- [ ] **Step 2:** Form controls: char WPM (stepper 5–40), effective/Farnsworth WPM (stepper, clamp ≤ char WPM), word spacing (slider 1–3), frequency (slider 300–900 Hz, default 550), Key Sound (toggle), input mode (picker straight key/paddle), timing gate (picker off/match/consistent) + grace slider, difficulty (picker easy/hard).
- [ ] **Step 3 (test):** `SettingsStoreTests` in `MorseKitTests`? `@AppStorage` needs UI; instead unit-test the `AppSettings` clamping helper you extract (e.g. `AppSettings.clampedEffective`) in `MorseKit`. Add that helper in Task 6's file if missing and test it here.
- [ ] **Step 4:** `swift build`; preview. **Commit** — `git commit -am "feat(ui): Settings screen + store"`

### Task 15: `ListenView` (Practice #2)

**Files:** Create `Sources/MorseUI/ListenView.swift`

Consumed: `ListenEngine`, `MorsePlayer`, `Curriculum`, `ProgressStore`, `AppSettings`.

- [ ] **Step 1:** Pick a target word from `Curriculum` limited to `progress.highestUnlockedStage`. Mode toggle (live / copy-then-check) bound to a `@State`.
- [ ] **Step 2:** "Play" → `MorsePlayer.play(target, …)`. Live mode: a text field; on each character use `ListenEngine.type`, lock green/flag red. Copy mode: text field + Submit → `ListenEngine.submit`, show result.
- [ ] **Step 3:** `swift build`; preview both modes. **Commit** — `git commit -am "feat(ui): Listen screen"`

### Task 16: `PlaygroundView` + `RootView` + app shell wiring

**Files:** Create `Sources/MorseUI/PlaygroundView.swift`, `Sources/MorseUI/RootView.swift`

- [ ] **Step 1:** `PlaygroundView` — `TextField` → live `MorseCode.encode` display (dots/dashes) + "Play" via `MorsePlayer`.
- [ ] **Step 2:** `RootView` — platform-adaptive: `#if os(iOS)` compact → `TabView` (Learn/Listen/Playground/Settings); else `NavigationSplitView` sidebar. Reference chart button in the toolbar presenting `ReferenceSheet`. Inject shared `SettingsStore`, `ProgressStore`, `ToneGenerator`, `MorsePlayer` via `@StateObject`/environment.
- [ ] **Step 3:** Generate and build the app shell: `cd App && xcodegen generate` then
  `xcodebuild -project App/MorseTrainerApp.xcodeproj -scheme MorseTrainerApp -destination 'platform=macOS' build`.
  Expected: build succeeds; launch on Mac and smoke-test each screen + audio.
- [ ] **Step 4:** `swift build` for the package; **Commit** — `git commit -am "feat(ui): Playground + RootView + app shell"`

---

## Self-Review

**Spec coverage:**
- Send practice, easy/hard, gray→green, adaptive hints → Tasks 10, 13, 12(LetterRow). ✔
- Straight-key default + paddle toggle, Key Sound sidetone → Tasks 5, 12(KeyButton), 6. ✔
- Timing meter + optional timing gate (off/match/consistent) → Tasks 10, 12(TimingMeter), 6. ✔
- Listen mode live + copy-then-check → Tasks 11, 15. ✔
- Word-based guided progression + stage unlock → Tasks 7, 9, 13. ✔
- Per-letter mastery + auto hint suppression → Tasks 8, 9, 13. ✔
- Reference chart popup, mastery tint → Task 12(ReferenceSheet), 16. ✔
- Settings: WPM, Farnsworth, word spacing, frequency 550 default → Tasks 2, 6, 14. ✔
- Playground (type → code + audio) → Task 16. ✔
- PARIS/Farnsworth timing math → Task 2. ✔
- SwiftData persistence → Task 9. ✔
- Multiplatform nav (tabs/split) → Task 16. ✔
- Headless testability for agents → Package structure + `swift test` throughout. ✔

**Placeholder scan:** No "TODO/TBD"; each logic step ships code + tests. UI steps give concrete
consumed interfaces, view structure, and build/preview acceptance (SwiftUI pixel layout is the
implementer's craft, but every binding and data source is named).

**Type consistency:** `MorseSymbol`, `ToneEvent(on:duration:)`, `TimingSettings(charWPM:effectiveWPM:wordSpacing:)`, `KeyerEvent`, `AppSettings`, `SenderEngine`, `ListenEngine`, `ProgressStore`, `Curriculum` names are used identically across producing and consuming tasks.

---

## Parallelization map (for farming to agents)

- **Sequential first:** Task 0 → Tasks 1–11 (core; each depends on prior types, but all are small and
  fast). A single agent can run Phase 1 straight through, committing per task.
- **Then parallel:** Task 12 (design system) must land before 13/15/16 (they use its components).
  After 12: **Tasks 13, 14, 15, 16 can run in parallel** in separate agent contexts — they touch
  different files and share only the frozen core + component interfaces.
- Integration/build of the Xcode shell (Task 16 Step 3) happens last, after the screens compile.
