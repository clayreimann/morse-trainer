# Morse Trainer — UX refresh: code changes to operationalize

Design source: `Morse Learn Refinement.dc.html` (option **2a/2b** for Learn, **3a–3c** for the
other tabs). This maps each design decision onto the existing SwiftUI codebase.

---

## 1. `Theme.swift` — make the accent configurable + add tokens

Today `current` is hardwired to `.systemBlue` and everything keys off system colors.
The refresh is **monochrome-first with a user-chosen accent**.

- Add an `AppColor` type and expose the *resolved* accent through `Theme`:

```swift
public enum AppColor: String, CaseIterable, Identifiable {
    case charcoal, indigo, teal, rust
    public var id: String { rawValue }
    public var color: Color {
        switch self {
        case .charcoal: return Color(white: 0.11)                  // #1C1C1E
        case .indigo:   return Color(red: 0.31, green: 0.31, blue: 0.85)
        case .teal:     return Color(red: 0.02, green: 0.62, blue: 0.55)
        case .rust:     return Color(red: 0.75, green: 0.38, blue: 0.23)
        }
    }
}
```

- Replace `Theme.current` with an accent that is *injected* (the selected `AppColor`),
  not a global constant. Simplest: add `Theme.accent(_ appColor:) -> Color` and pass the
  resolved color into the views that need it (`LetterRow`, `KeyButton`, `TabView.tint`).
  Keep `mastered`/`learning`/`locked` for status, but note the mock uses **neutral grays**
  for completed/upcoming letters (`locked` = `#C4C4C9`) and the accent only for the current letter.
- New tokens: `Theme.Radius.key = 36`, `Theme.cardFill` (`systemGray6` / off-white
  `#F6F6F7`), `Theme.cardStroke` (hairline `#ECECEF`).

## 2. `SettingsStore` + `AppSettings` — persist the accent

- `SettingsStore`: add `@AppStorage("morse.appColor") private var storedAppColorRaw = AppColor.charcoal.rawValue`
  and a public `appColor: AppColor` getter/setter (mirror the existing `inputMode` pattern,
  including `objectWillChange.send()`).
- `AppSettings`: add `var appColor: AppColor = .charcoal`; set it in the `settings` snapshot.

## 3. `SettingsView.swift` — new Appearance section (screen **3c**)

- Add a first section:

```swift
Section("App color") {
    HStack(spacing: 20) {
        ForEach(AppColor.allCases) { c in
            Circle().fill(c.color).frame(width: 34, height: 34)
                .overlay(Circle().strokeBorder(.white, lineWidth: store.appColor == c ? 2.5 : 0))
                .overlay(Circle().strokeBorder(c.color, lineWidth: store.appColor == c ? 5 : 0).padding(-2.5))
                .onTapGesture { store.appColor = c }
        }
    }.frame(maxWidth: .infinity, alignment: .leading)
}
```

- Everything else (Timing / Sound / Input / Timing gate / Difficulty) is unchanged in
  behavior; the visual refresh comes for free once the accent drives `.tint`. Optional:
  regroup `Timing gate` + `Difficulty` under one "Practice" header to match the mock.

## 4. `RootView.swift` — tint the shell

- Apply the accent to the tab bar / nav so selected tab + controls follow the app color:

```swift
TabView { … }
    .tint(store.settings.appColor.color)
```

  (Inactive tabs keep the default gray — the mock uses `#8E8E93`, which is the system default,
  so no per-item styling is needed once you stop forcing blue.)

## 5. `LearnSendView.swift` — the biggest changes (screen **2a**)

**a. Stage nav → progress bar.** Replace the `chevron / "Stage n of m" / chevron` `HStack`
with a `"STAGE 4 OF 6"` caption + trailing chevrons, and a thin `ProgressView`
(`value: Double(currentStageIndex+1), total: Double(totalStages)`) tinted to the accent.

**b. Remove idle instructional text.** Delete the `"Tap out the current letter"` branch.
Keep the miss feedback ("You sent … / Target …") but only render it when `rejected != nil`.

**c. Group into a card.** Wrap `LetterRow` + hint + the hear button + the speed meter in a
`RoundedRectangle(cornerRadius: 24).fill(Theme.cardFill).strokeBorder(Theme.cardStroke)`.
"Hear it" becomes a small circular icon button (speaker) pinned top-trailing of the card.

**d. Speed meter → 3 regions, only while sending.** See §7. Bind its opacity to a new
`isSending` flag:

```swift
@Published var isSending = false   // set true in keyDown(); reset in resetSettleDebounce()
…
SpeedMeter(region: coordinator.speedRegion)
    .opacity(coordinator.isSending ? 1 : 0)
    .animation(.easeInOut(duration: 0.35), value: coordinator.isSending)
```

Add `var speedRegion: SpeedRegion` derived from `estimatedWPM` vs `settings.charWPM`
using the gate grace as the "on target" band:

```swift
enum SpeedRegion { case slow, onTarget, fast }
var speedRegion: SpeedRegion {
    guard let wpm = estimatedWPM else { return .onTarget }
    let g = settings.charWPM * 0.15
    if wpm < settings.charWPM - g { return .slow }
    if wpm > settings.charWPM + g { return .fast }
    return .onTarget
}
```

**e. Anchor the key.** Keep the `Spacer()` above the `KeyButton`; the rounded-rect key sits
against the bottom safe-area inset so it lands in the thumb zone (fills the dead gap that
was above the old circle).

## 6. `KeyButton.swift` — rounded rectangle + hairline split (screens **2a / 2b**)

- Change `pad(...)` from `Circle()` to `RoundedRectangle(cornerRadius: Theme.Radius.key)`,
  sized to full width × ~150pt, charcoal (`appColor`) fill, white label, with the
  pressed-depth shadow (outer drop + inner top-highlight / bottom-shade).
- `.straightKey`: one rounded rect labelled "KEY".
- `.paddle`: **one** rounded rect containing two equal tap regions separated by a 1pt
  `Color.white.opacity(0.16)` divider — left "DIT" (·), right "DAH" (–) — instead of two
  separate circles. Each half keeps its own `DragGesture` → `onSymbol(.dot/.dash)`.
  This is the same shape as straight-key, so switching modes just adds/removes the divider.

## 7. New `SpeedMeter.swift` (replaces `TimingMeter` in Learn)

Three flat pills across the middle ~½ width (they visually rhyme with the letter
underlines), no rainbow gradient:

```swift
struct SpeedMeter: View {
    let region: SpeedRegion
    var body: some View {
        HStack(spacing: 8) {
            pill(.slow); pill(.onTarget); pill(.fast)
        }
        .frame(maxWidth: 180)
    }
    func pill(_ r: SpeedRegion) -> some View {
        Capsule().fill(r == region ? Color.primary : Color(white: 0.9))
            .frame(height: 6)
    }
}
```

Keep the existing `TimingMeter` if it's still used elsewhere; otherwise retire it.
The precise `timingPosition` math in `SendCoordinator.recordSpeed` still feeds the region
classifier — you're just rendering it coarsely.

## 8. `LetterRow.swift` — stop the letters jumping

Root cause: the per-letter `VStack` width tracks its widest child, so a wide code hint
(e.g. `– – – – –`) under the current letter re-spaces the whole word.

Fix: give every letter slot a **fixed width** (sized to the widest possible code — 5
elements) and let the hint overflow that slot centered without affecting layout:

```swift
private let slotWidth: CGFloat = 64
…
VStack(spacing: Theme.Spacing.xs) {
    Text(String(letter)) …
    Text(hintString) …
        .lineLimit(1).fixedSize()          // don't wrap
        .frame(width: 0).frame(minWidth: 0)// hint doesn't drive column width
}
.frame(width: slotWidth)                    // column width is constant
```

(Simplest robust version: keep the reserved-height placeholder you already have, and just
add `.frame(width: slotWidth)` on the outer `VStack` so the column never resizes horizontally.)

## 9. `ListenView.swift` / `PlaygroundView.swift` (screens 3a / 3b)

Mostly visual, no logic changes:

- **Listen**: segmented `Picker` stays; the `Play` button becomes the charcoal rounded-rect
  key style (primary action). Live result chips → circles filled with the accent (correct)
  or a red stroke (miss). Reuse `Theme.cardFill` for the input container. "New word" is a
  quiet `.bordered` ghost button.
- **Playground**: wrap `encodedDisplay` chips in the same card; each chip is a white
  rounded rect (letter bold, code in `.secondary` monospace). `Play` uses the charcoal key style.

---

### Suggested order
1. Theme accent + SettingsStore/AppSettings persistence (foundation).
2. `.tint` in RootView + SettingsView picker (visible win, low risk).
3. LetterRow fixed-width fix (pure bug fix, independent).
4. KeyButton rounded-rect + split.
5. SpeedMeter + LearnSendView card/progress/fade restructure.
6. Listen / Playground visual pass.
