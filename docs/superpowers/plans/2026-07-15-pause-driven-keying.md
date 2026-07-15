# Pause-Driven Keying Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Grade each keyed Morse attempt only after the settle pause and render successfully completed letters in green.

**Architecture:** Keep `SenderEngine` as the owner of the symbol/timing buffer, but make `flushLetter()` its only grading boundary. Keep visual progress in the shared `LetterRow`, with a small internal color-selection helper that can be covered by a focused `MorseUI` unit test.

**Tech Stack:** Swift 6, Swift Package Manager, XCTest, SwiftUI

## Global Constraints

- Every symbol entered before the existing settle pause belongs to the same attempt, regardless of whether the sequence is correct, incorrect, incomplete, or overlong.
- A pause with no buffered symbols remains a no-op.
- Completed letters are green; the current letter uses the configured accent; remaining letters stay gray.
- Preserve `INFOPLIST_KEY_UILaunchScreen_Generation: YES` in `project.yml` so the iOS app continues to generate a native-resolution launch screen.
- Do not add dependencies or alter the settle duration.

---

### Task 1: Make SenderEngine grading exclusively pause-driven

**Files:**
- Modify: `Tests/MorseKitTests/SenderEngineTests.swift`
- Modify: `Tests/MorseKitTests/SenderFlowTests.swift`
- Modify: `Sources/MorseKit/SenderEngine.swift`

**Interfaces:**
- Consumes: `SenderEngine.consume(_:)`, `SenderEngine.consumeTimed(_:pressMs:)`, and `SenderEngine.flushLetter()`.
- Produces: `consumeTimed(_:pressMs:)` only buffers `.element` events; `flushLetter()` is the sole caller that grades a non-empty buffer.

- [ ] **Step 1: Replace immediate-completion expectations with pause-driven tests**

In `SenderEngineTests.swift`, update the existing success, timing, exact-match, and overshoot cases to use these assertions:

```swift
func testCorrectLetterTurnsGreenAfterFlush() {
    let e = makeEngine("TE")
    e.consume(.element(.dash))
    XCTAssertEqual(e.completedCount, 0)
    e.flushLetter()
    XCTAssertEqual(e.completedCount, 1)
    XCTAssertEqual(e.currentIndex, 1)

    e.consume(.element(.dot))
    XCTAssertEqual(e.completedCount, 1)
    e.flushLetter()
    XCTAssertTrue(e.isComplete)
}

func testGateMatchWPMRejectsBadTimingAfterFlush() {
    let e = SenderEngine(target: "T", unitMs: 60, gate: .matchWPM, gracePercent: 20)
    e.consumeTimed(.element(.dash), pressMs: 400)
    XCTAssertFalse(e.lastLetterWasError)
    e.flushLetter()
    XCTAssertEqual(e.completedCount, 0)
    XCTAssertTrue(e.lastLetterWasError)
}

func testMultiElementLetterCompletesAfterFlush() {
    let e = makeEngine("A")
    e.consume(.element(.dot))
    e.consume(.element(.dash))
    XCTAssertEqual(e.completedCount, 0)
    XCTAssertFalse(e.lastLetterWasError)
    e.flushLetter()
    XCTAssertTrue(e.isComplete)
}

func testPrematureLetterBreakDoesNotCompletePartialLetter() {
    let e = makeEngine("A")
    e.consume(.element(.dot))
    e.consume(.letterBreak)
    XCTAssertFalse(e.lastLetterWasError)
    XCTAssertEqual(e.completedCount, 0)
    e.consume(.element(.dash))
    XCTAssertEqual(e.completedCount, 0)
    e.flushLetter()
    XCTAssertTrue(e.isComplete)
}

func testOvershootWaitsForFlushThenRejects() {
    let e = makeEngine("E")
    e.consume(.element(.dot))
    e.consume(.element(.dot))
    e.consume(.element(.dot))
    e.consume(.element(.dot))
    XCTAssertEqual(e.completedCount, 0)
    XCTAssertFalse(e.lastLetterWasError)
    e.flushLetter()
    XCTAssertEqual(e.completedCount, 0)
    XCTAssertTrue(e.lastLetterWasError)
}

func testExactMatchWaitsForFlush() {
    let e = makeEngine("E")
    e.consume(.element(.dot))
    XCTAssertEqual(e.completedCount, 0)
    XCTAssertFalse(e.lastLetterWasError)
    e.flushLetter()
    XCTAssertTrue(e.isComplete)
}
```

Retain the existing tests that prove wrong and empty buffers behave correctly. In `SenderFlowTests.swift`, call `flushLetter()` after entering each letter and before asserting progression:

```swift
e.consume(.element(.dash)); e.flushLetter()
XCTAssertEqual(e.completedCount, 1)

e.consume(.element(.dot)); e.flushLetter()
XCTAssertEqual(e.completedCount, 2)

e.consume(.element(.dot)); e.consume(.element(.dash)); e.flushLetter()
XCTAssertEqual(e.completedCount, 3)
```

- [ ] **Step 2: Run the focused tests and verify the new expectations fail**

Run:

```bash
swift test --filter SenderEngineTests
```

Expected: FAIL because exact patterns still advance immediately and the overlong `E` attempt is accepted after its first dot.

- [ ] **Step 3: Remove all element-driven grading from SenderEngine**

Replace the `.element` branch in `SenderEngine.consumeTimed(_:pressMs:)` with buffering only:

```swift
case .element(let sym):
    guard currentIndex < expected.count else { return }
    buffer.append(sym)
    if let p = pressMs { pressTimings.append(p) }
```

Leave `.letterBreak` and `.wordBreak` as no-ops. Update their comments and the `flushLetter()` documentation so they state that every non-empty attempt is judged only when the caller's settle pause invokes `flushLetter()`.

- [ ] **Step 4: Run sender and full-word flow tests**

Run:

```bash
swift test --filter SenderEngineTests
swift test --filter SenderFlowTests
```

Expected: both commands PASS; success advances only after `flushLetter()`, while the four-symbol attempt fails only after `flushLetter()`.

- [ ] **Step 5: Commit the pause-driven engine behavior**

```bash
git add Sources/MorseKit/SenderEngine.swift Tests/MorseKitTests/SenderEngineTests.swift Tests/MorseKitTests/SenderFlowTests.swift
git commit -m "fix: grade keyed letters after pause"
```

---

### Task 2: Render completed keyed letters in green

**Files:**
- Modify: `Package.swift`
- Create: `Tests/MorseUITests/LetterRowTests.swift`
- Modify: `Sources/MorseUI/Components/LetterRow.swift`

**Interfaces:**
- Consumes: `LetterRow` progress values (`completedCount`, `currentIndex`) and its accent color.
- Produces: internal `LetterRow.color(for:completedCount:currentIndex:accent:) -> Color`, used by both the SwiftUI body and the focused unit test.

- [ ] **Step 1: Add a MorseUI test target and a failing completed-color test**

Add the test target to `Package.swift`:

```swift
.testTarget(name: "MorseUITests", dependencies: ["MorseUI"]),
```

Create `Tests/MorseUITests/LetterRowTests.swift`:

```swift
import SwiftUI
import XCTest
@testable import MorseUI

final class LetterRowTests: XCTestCase {
    func testCompletedLetterUsesGreen() {
        XCTAssertEqual(
            LetterRow.color(
                for: 0,
                completedCount: 1,
                currentIndex: 1,
                accent: .blue
            ),
            Color.green
        )
    }
}
```

- [ ] **Step 2: Run the UI test and verify it fails**

Run:

```bash
swift test --filter LetterRowTests.testCompletedLetterUsesGreen
```

Expected: FAIL to compile with `type 'LetterRow' has no member 'color'`.

- [ ] **Step 3: Add the shared color-selection helper and use it in LetterRow**

Change the letter foreground call in `body` to:

```swift
.foregroundStyle(Self.color(
    for: index,
    completedCount: completedCount,
    currentIndex: currentIndex,
    accent: accent
))
```

Replace the private instance method with this internal static helper:

```swift
static func color(
    for index: Int,
    completedCount: Int,
    currentIndex: Int,
    accent: Color
) -> Color {
    if index < completedCount { return .green }
    if index == currentIndex { return accent }
    return Color(white: 0.75)
}
```

- [ ] **Step 4: Run the UI test and complete package suite**

Run:

```bash
swift test --filter LetterRowTests.testCompletedLetterUsesGreen
swift test
```

Expected: both commands PASS with no warnings or failures.

- [ ] **Step 5: Verify the iOS launch-screen setting remains present**

Run:

```bash
rg -n "INFOPLIST_KEY_UILaunchScreen_Generation: YES" project.yml
```

Expected: one match in the application target's base settings.

- [ ] **Step 6: Commit the green completion styling and test**

```bash
git add Package.swift Sources/MorseUI/Components/LetterRow.swift Tests/MorseUITests/LetterRowTests.swift
git commit -m "fix: keep completed keyed letters green"
```
