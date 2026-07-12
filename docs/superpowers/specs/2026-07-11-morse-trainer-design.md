# Morse Trainer — Design Spec

**Date:** 2026-07-11
**Status:** Approved for planning
**Platform:** Native SwiftUI, multiplatform (macOS + iPadOS + iOS). Iterate on Mac first; refine iPad/iPhone UX on device later.

---

## 1. Overview

A native SwiftUI app for learning Morse code by *sending* and *copying* real words. Learning is a
guided, word-based progression: each stage introduces a small, growing set of letters, and you
practice them inside common words rather than in isolation. The app both **plays** Morse (audio) and
lets you **listen and copy** it, and tracks per-letter mastery to adapt the amount of help it gives.

### Goals
- Teach Morse letters *in context* through common words.
- Two practice modes: **Send** (key it out) and **Listen** (copy it by ear).
- Precise, click-free audio at a configurable tone frequency and speed (WPM, PARIS standard).
- Adapt help to the learner: hints fade per-letter as confidence grows.

### Non-goals (v1)
- No accounts, cloud sync, or multi-device progress sync (local persistence only).
- No Android/web (SwiftUI multiplatform Apple only).
- No QSO/contest simulation, no decoding of external/live audio input.

---

## 2. Core concepts & timing

### PARIS timing
The base unit is derived from character words-per-minute:

```
unit_ms = 1200 / charWPM
```

Element durations (in units):
- dot = 1u
- dash = 3u
- gap between elements within a character = 1u
- gap between characters = 3u
- gap between words = 7u

Reference check: the word "PARIS " (with trailing space) is exactly 50 units. At 20 WPM,
1u = 60 ms, so "PARIS " takes 3000 ms and 20 repetitions take 60 s — i.e. 20 WPM. This identity is a
unit test.

### Farnsworth spacing
Characters are sent at `charWPM`, but the **gaps** between characters and words are stretched so the
*effective* speed is lower (`effectiveWPM ≤ charWPM`). This lets a learner hear each character at a
realistic speed while having more time to recognize it. Standard method:

- Compute the time for the characters themselves at `charWPM`.
- Compute the total time the whole string *should* take at `effectiveWPM`.
- Distribute the extra time across the inter-character (3u) and inter-word (7u) gaps in a 3:7 ratio.

### Word spacing
A separate, additional multiplier applied on top of the inter-word (7u) gap, so the learner can
lengthen pauses between words independently of Farnsworth. `wordSpacing = 1.0` means the standard
7u (as adjusted by Farnsworth); higher values add proportionally more inter-word gap.

### WPM identity used for tests
- `unit_ms = 1200 / charWPM`
- Farnsworth distribution and word-spacing multiplier are pure functions of
  `(charWPM, effectiveWPM, wordSpacing)` and are unit-tested independently of audio.

---

## 3. Architecture

Two layers: a **shared core** of pure/logic + audio services built first, then **screens** that each
depend only on the core's public interfaces. Each screen is an isolated implementation task
(suitable for a dedicated subagent with its own context).

### 3.1 Shared core (built first)

| Component | Responsibility | Depends on | Testable headlessly |
|-----------|----------------|------------|---------------------|
| `MorseCode` | Static A–Z / 0–9 / punctuation ↔ code table. Encode text → element/gap timeline (units). PARIS + Farnsworth + word-spacing math. | — | Yes (pure) |
| `ToneGenerator` | `AVAudioEngine` + `AVAudioSourceNode` sine oscillator at configurable frequency, with ~5 ms attack/release envelope to prevent clicks. Start/stop tone; used for playback and sidetone. | AVFoundation | Audio: no; envelope math: yes |
| `MorsePlayer` | Convert text + timing settings into a schedule of `(toneOn/off, durationMs, symbol)` events; drive `ToneGenerator`; publish highlight events for UI. | `MorseCode`, `ToneGenerator` | Schedule generation: yes |
| `KeyerInput` | Capture key press-down/up timestamps. Straight-key mode: classify dot vs dash by duration threshold, detect element/character/word gaps, emit elements & completed letters. Two-button mode: emit dot/dash directly. Fires Key Sound via `ToneGenerator`. | `ToneGenerator`, `SettingsStore` | Classifier: yes (synthetic timings) |
| `SettingsStore` | `ObservableObject` of user settings, persisted via `@AppStorage`. | — | Yes |
| `Curriculum` | Ordered stages: each stage = newly introduced letters + a word pool restricted to letters learned so far. Static data. | `MorseCode` | Yes |
| `ProgressStore` | SwiftData-backed per-letter mastery + stage progress. Computes confidence; decides hint suppression and stage unlock. | `Curriculum` | Yes |
| Design system | Shared SwiftUI views/theme: `KeyButton`, `LetterRow`, `TimingMeter`, `MasteryStrip`, `ReferenceSheet`, colors/typography. | SwiftUI | Preview/manual |

### 3.2 Screens (each an isolated task)

| Screen | Uses | Notes |
|--------|------|-------|
| `LearnSendView` + `SenderEngine` | `KeyerInput`, `MorseCode`, `ProgressStore`, `MorsePlayer` (Hear it) | Practice area #1. Matches keyer output to the target word; green-as-you-go; timing meter; adaptive hints. |
| `ListenView` + `ListenEngine` | `MorsePlayer`, `Curriculum`, `ProgressStore` | Practice area #2. Plays by ear; user types; live-per-char or copy-then-check. |
| `PlaygroundView` | `MorseCode`, `MorsePlayer` | Type any text → see code + play audio. |
| `SettingsView` | `SettingsStore` | Binds all settings. |
| `ReferenceSheet` | `MorseCode`, `ProgressStore` | Popup chart; tap symbol to hear; tinted by mastery. |

### 3.3 Navigation
- **iPhone:** bottom `TabView` — Learn · Listen · Playground · Settings.
- **iPad / Mac:** `NavigationSplitView` sidebar with the same destinations.
- **Reference chart:** top-bar button opening a sheet/popover, available from anywhere.

---

## 4. Feature detail

### 4.1 Learn / Send (Practice #1)
- A stage word appears (e.g. `TEA`, `NOTE`). Letters render gray; each turns **green** when keyed
  correctly. The **current letter** is indicated by highlight color only (no arrow).
- **Input:** straight key by default (single button: tap = dot, hold = dash), or two-button dot/dash
  (Settings toggle). Keying plays the **Key Sound** sidetone at the set frequency so the learner
  hears the letter as they send it.
- **Hints (dot/dash under the letter):** shown only for the **current** letter, and only if that
  letter is not yet mastered. Manual **Hard** override hides hints entirely; **Easy** = adaptive.
  On a miss, the current letter's hint is revealed regardless.
- **Scoring:** a letter counts correct on **pattern match** (correct dot/dash sequence). Timing does
  not block completion.
- **Timing feedback:** a horizontal **meter** — center tick = target WPM; a marker shows where the
  learner's last element landed (slow ↔ fast). Non-blocking.
- **Optional timing gate** (Settings): `off` (pattern-only), `matchWPM` (elements must fall within
  ± grace of the target WPM to count), or `consistent` (elements must be self-consistent within
  ± grace, regardless of absolute speed).
- **"Hear it"** button plays the target word's Morse via `MorsePlayer`.

### 4.2 Listen (Practice #2)
- Morse plays by ear (`MorsePlayer`); the learner types what they hear.
- **Two checking modes (switchable):**
  - *Live per-character:* each letter locks green when typed correctly as it plays; wrong flags
    immediately.
  - *Copy then check:* the full word/phrase plays, the learner types an answer, then submits to
    check all at once.
- Draws words from letters the learner has already learned (curriculum-aware).

### 4.3 Playground
- A text field: type any text → see its dots/dashes and play the audio. Free-form encode-and-listen.

### 4.4 Reference chart
- Popup sheet: full A–Z / 0–9 (and common punctuation) chart. Tap a symbol to hear it. Each entry is
  tinted by the learner's mastery level (confident / learning / locked).

### 4.5 Settings
- **Speed:** character WPM; effective (Farnsworth) WPM; word spacing.
- **Tone frequency:** default **550 Hz**.
- **Key Sound:** on/off (the keying sidetone).
- **Input mode:** straight key ↔ two-button dot/dash.
- **Timing gate:** off / match WPM / consistent, with a ± grace value.
- **Difficulty override:** Easy (adaptive hints) / Hard (no hints).

---

## 5. Mastery & progression model

### Per-letter stats (`ProgressStore`, SwiftData)
For each letter: attempts, correct count, and a hesitancy signal (exponential moving average of
time-to-first-press and inter-element pause). These combine into a **confidence** score.

- **Confidence** rises with correct, low-hesitancy attempts and falls with misses/high hesitancy.
- **Hint suppression:** when a letter's confidence crosses a threshold, its hint auto-disables (even
  in Easy mode). If confidence later drops, hints can return.
- **Mastery tint** (green = confident / amber = learning / gray = locked) drives both the in-screen
  mastery strip and the reference chart.

### Stage unlocking (`Curriculum`)
- Each stage introduces one or two new letters plus a word pool using only letters learned so far.
- A stage is **complete** when the learner has successfully sent each word in the stage's set at least
  once (exact threshold tunable). Completing a stage unlocks the next.

### Sample starter curriculum (tweakable)
Letters chosen to form real words early:

| Stage | New letters | Cumulative set | Example words |
|-------|-------------|----------------|---------------|
| 1 | E, T, A | E T A | AT, ATE, EAT, TEA, TAT |
| 2 | O, N | E T A O N | NOT, TON, TAN, ANT, NOTE, TONE, NEAT |
| 3 | S, R | E T A O N S R | STAR, RATS, EARS, SANE, NEAR, ROSE, TEARS |
| 4 | I, H | + I H | THIS, HITS, HAIR, SHINE, HEART, TRAIN |
| 5 | D, L | + D L | LAND, DEAL, LATE, IDLE, TRAIL, DETAIL |
| 6 | U, C | + U C | CUT, CLUE, ACID, CLEAN, NUCLEAR |

*(Exact word lists and thresholds are content to be finalized during implementation.)*

---

## 6. Persistence

- **Settings:** `@AppStorage` (UserDefaults) via `SettingsStore`.
- **Progress:** SwiftData models —
  - `LetterStat { letter, attempts, correct, hesitancyEMA, confidence }`
  - `StageProgress { stageId, unlocked, completed }`
- Local only in v1; no sync.

---

## 7. Testing strategy

**Unit-tested (TDD, headless):**
- `MorseCode` encode/decode round-trips for the full table.
- PARIS timing identity ("PARIS " = 50u; 20 WPM → 1u = 60 ms).
- Farnsworth distribution and word-spacing multiplier as pure functions.
- `KeyerInput` classifier from synthetic press timings (dot/dash boundary, gap detection).
- `MorsePlayer` schedule generation (event list) — independent of audio playback.
- `SenderEngine` letter-matching and green-progression logic.
- `ProgressStore` confidence thresholds → hint suppression and stage unlock.

**Verified on-device / manually:**
- `ToneGenerator` audio quality (no clicks, correct frequency) on Mac, then iPad/iPhone.
- SwiftUI screens via Previews and manual runs.

---

## 8. Implementation approach

1. **Shared core first:** `MorseCode` → `ToneGenerator` → `MorsePlayer` → `KeyerInput` →
   `SettingsStore` → `Curriculum` → `ProgressStore` → design-system components. Each with unit tests
   where logic is pure.
2. **Screens in parallel:** once the core interfaces are stable, `LearnSendView`, `ListenView`,
   `PlaygroundView`, `SettingsView`, and `ReferenceSheet` can each be built as an isolated task
   against those interfaces.
3. Iterate and verify audio + UX on Mac first, then refine touch UX on iPad/iPhone.
