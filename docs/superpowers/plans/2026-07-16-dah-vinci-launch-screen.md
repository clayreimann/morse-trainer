# Dah Vinci iOS Launch Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add the approved adaptive, vector-based Dah Vinci branding to the app's native iOS launch screen without delaying app startup or changing macOS behavior.

**Architecture:** Generate a reproducible single-page vector PDF containing the complete gradient wordmark and exact geometric Morse sequences, then package it as one asset-catalog image. Center that image in an iOS-only launch storyboard over `systemBackgroundColor`; use XcodeGen destination filters and platform-specific setting groups so only the iOS target adopts the storyboard.

**Tech Stack:** Swift 6 script, AppKit, CoreGraphics, CoreText, vector PDF, Xcode asset catalogs, UIKit launch storyboard, XcodeGen 2.45.3, Xcode 26.3

## Global Constraints

- Display `Dah` above `-.. .- ....` and `Vinci` above `...- .. -. -.-. ..`.
- Draw dits as circles and dahs as rounded bars three times the dit width.
- Use mark thickness `8 pt`, intra-letter spacing `4 pt`, and inter-letter spacing `13.6 pt` (1.7 times mark thickness).
- Apply the diagonal gradient `#756EE8` → `#377FF1` → `#16B8D8` to both words and all Morse marks.
- Use the adaptive iOS `systemBackgroundColor`; do not add separate light and dark raster images.
- Show branding only during the native iOS launch interval; do not add a SwiftUI overlay, timer, animation, or startup delay.
- Preserve `INFOPLIST_KEY_UILaunchScreen_Generation: YES` and verify the built iOS app's `Info.plist` contains `UILaunchScreen`.
- Keep the launch storyboard and `UILaunchStoryboardName` setting out of the macOS target.
- Do not add third-party dependencies.

---

### Task 1: Create the reproducible vector wordmark asset

**Files:**
- Create: `Scripts/GenerateLaunchWordmark.swift`
- Create: `App/Assets.xcassets/LaunchWordmark.imageset/Contents.json`
- Generate: `App/Assets.xcassets/LaunchWordmark.imageset/LaunchWordmark.pdf`

**Interfaces:**
- Consumes: the approved title strings, Morse strings, gradient colors, and spacing constants in this plan.
- Produces: asset-catalog image named `LaunchWordmark`, with intrinsic size `320 × 300 pt` and a transparent background.

- [ ] **Step 1: Confirm the new asset does not exist yet**

Run:

```bash
test -e App/Assets.xcassets/LaunchWordmark.imageset/LaunchWordmark.pdf
```

Expected: exit status `1`; the launch wordmark has not been generated.

- [ ] **Step 2: Add the deterministic PDF generator**

Create `Scripts/GenerateLaunchWordmark.swift` with:

```swift
import AppKit
import CoreGraphics
import CoreText
import Foundation

private enum Mark: Equatable {
    case dit
    case dah
}

private let canvasSize = CGSize(width: 320, height: 300)
private let markThickness: CGFloat = 8
private let dahWidth = markThickness * 3
private let intraLetterSpacing = markThickness * 0.5
private let interLetterSpacing = markThickness * 1.7

private let dahCode = "-.. .- ...."
private let vinciCode = "...- .. -. -.-. .."

private func parse(_ code: String) -> [[Mark]] {
    code.split(separator: " ").map { letter in
        letter.map { symbol in
            switch symbol {
            case ".": return .dit
            case "-": return .dah
            default: fatalError("Unsupported Morse symbol: \(symbol)")
            }
        }
    }
}

private func rgb(_ hex: UInt32) -> CGColor {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let red = CGFloat((hex >> 16) & 0xFF) / 255
    let green = CGFloat((hex >> 8) & 0xFF) / 255
    let blue = CGFloat(hex & 0xFF) / 255
    return CGColor(
        colorSpace: colorSpace,
        components: [red, green, blue, 1]
    )!
}

private func drawGradient(in context: CGContext) {
    let colors = [rgb(0x756EE8), rgb(0x377FF1), rgb(0x16B8D8)] as CFArray
    let locations: [CGFloat] = [0, 0.45, 1]
    let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: colors,
        locations: locations
    )!
    context.drawLinearGradient(
        gradient,
        start: CGPoint(x: 0, y: canvasSize.height),
        end: CGPoint(x: canvasSize.width, y: 0),
        options: []
    )
}

private func roundedHeavyFont(size: CGFloat) -> NSFont {
    let system = NSFont.systemFont(ofSize: size, weight: .heavy)
    let descriptor = system.fontDescriptor.withDesign(.rounded) ?? system.fontDescriptor
    return NSFont(descriptor: descriptor, size: size)!
}

private func drawWord(
    _ word: String,
    centeredIn rect: CGRect,
    context: CGContext
) {
    let attributed = NSAttributedString(
        string: word,
        attributes: [.font: roundedHeavyFont(size: 68)]
    )
    let line = CTLineCreateWithAttributedString(attributed)
    let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)

    context.saveGState()
    context.textPosition = CGPoint(
        x: rect.midX - bounds.midX,
        y: rect.midY - bounds.midY
    )
    context.setTextDrawingMode(.clip)
    CTLineDraw(line, context)
    drawGradient(in: context)
    context.restoreGState()
}

private func width(of letter: [Mark]) -> CGFloat {
    let markWidths = letter.reduce(CGFloat.zero) { partial, mark in
        partial + (mark == .dit ? markThickness : dahWidth)
    }
    return markWidths + CGFloat(max(0, letter.count - 1)) * intraLetterSpacing
}

private func drawMorse(
    _ code: String,
    centerY: CGFloat,
    context: CGContext
) {
    let letters = parse(code)
    let totalWidth = letters.reduce(CGFloat.zero) { $0 + width(of: $1) }
        + CGFloat(max(0, letters.count - 1)) * interLetterSpacing
    var x = (canvasSize.width - totalWidth) / 2
    let y = centerY - markThickness / 2

    context.saveGState()
    context.beginPath()

    for (letterIndex, letter) in letters.enumerated() {
        for (markIndex, mark) in letter.enumerated() {
            let markWidth = mark == .dit ? markThickness : dahWidth
            let rect = CGRect(x: x, y: y, width: markWidth, height: markThickness)

            if mark == .dit {
                context.addEllipse(in: rect)
            } else {
                context.addPath(
                    CGPath(
                        roundedRect: rect,
                        cornerWidth: markThickness / 2,
                        cornerHeight: markThickness / 2,
                        transform: nil
                    )
                )
            }

            x += markWidth
            if markIndex < letter.count - 1 {
                x += intraLetterSpacing
            }
        }

        if letterIndex < letters.count - 1 {
            x += interLetterSpacing
        }
    }

    context.clip()
    drawGradient(in: context)
    context.restoreGState()
}

precondition(dahCode == "-.. .- ....")
precondition(vinciCode == "...- .. -. -.-. ..")

let outputPath = CommandLine.arguments.dropFirst().first
    ?? "App/Assets.xcassets/LaunchWordmark.imageset/LaunchWordmark.pdf"
let outputURL = URL(fileURLWithPath: outputPath)
try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)

var mediaBox = CGRect(origin: .zero, size: canvasSize)
guard let consumer = CGDataConsumer(url: outputURL as CFURL),
      let context = CGContext(
        consumer: consumer,
        mediaBox: &mediaBox,
        [kCGPDFContextTitle as String: "Dah Vinci Launch Wordmark"] as CFDictionary
      ) else {
    fatalError("Could not create PDF context at \(outputPath)")
}

context.beginPDFPage(nil)
drawWord("Dah", centeredIn: CGRect(x: 20, y: 220, width: 280, height: 72), context: context)
drawMorse(dahCode, centerY: 190, context: context)
drawWord("Vinci", centeredIn: CGRect(x: 8, y: 85, width: 304, height: 72), context: context)
drawMorse(vinciCode, centerY: 55, context: context)
context.endPDFPage()
context.closePDF()

print("Generated \(outputPath)")
```

- [ ] **Step 3: Add the vector image-set manifest**

Create `App/Assets.xcassets/LaunchWordmark.imageset/Contents.json` with:

```json
{
  "images" : [
    {
      "filename" : "LaunchWordmark.pdf",
      "idiom" : "universal"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  },
  "properties" : {
    "preserves-vector-representation" : true
  }
}
```

- [ ] **Step 4: Generate and mechanically validate the PDF**

Run:

```bash
swift Scripts/GenerateLaunchWordmark.swift
pdfinfo App/Assets.xcassets/LaunchWordmark.imageset/LaunchWordmark.pdf | rg 'Pages:|Page size:'
```

Expected:

```text
Pages:           1
Page size:       320 x 300 pts
```

Render a review PNG:

```bash
pdftoppm -png -singlefile -r 144 \
  App/Assets.xcassets/LaunchWordmark.imageset/LaunchWordmark.pdf \
  /tmp/dah-vinci-launch-wordmark
```

Inspect `/tmp/dah-vinci-launch-wordmark.png` and confirm:

- both titles use the approved gradient and rounded heavy type;
- every dit is circular and every dah is a rounded `3:1` bar;
- `Dah` is `-.. .- ....`;
- `Vinci` is `...- .. -. -.-. ..`;
- the PDF background is transparent.

- [ ] **Step 5: Commit the vector asset and generator**

```bash
git add Scripts/GenerateLaunchWordmark.swift \
  App/Assets.xcassets/LaunchWordmark.imageset/Contents.json \
  App/Assets.xcassets/LaunchWordmark.imageset/LaunchWordmark.pdf
git commit -m "feat: add vector Dah Vinci launch wordmark"
```

---

### Task 2: Install the iOS-only native launch screen

**Files:**
- Create: `App/LaunchScreen.storyboard`
- Modify: `project.yml`
- Regenerate, do not commit: `MorseTrainerApp.xcodeproj/`

**Interfaces:**
- Consumes: asset-catalog image `LaunchWordmark` from Task 1 and the existing XcodeGen multi-platform target.
- Produces: iOS resource `LaunchScreen.storyboardc`, generated `UILaunchStoryboardName = LaunchScreen`, retained generated `UILaunchScreen`, and no launch-storyboard resource or setting in macOS.

- [ ] **Step 1: Record the current failing launch-screen checks**

Run:

```bash
test -e App/LaunchScreen.storyboard
xcodebuild -project MorseTrainerApp.xcodeproj \
  -target MorseTrainerApp_iOS \
  -showBuildSettings | rg 'INFOPLIST_KEY_UILaunchStoryboardName = LaunchScreen'
```

Expected: both checks exit with status `1`; the app currently generates only an empty launch-screen declaration.

- [ ] **Step 2: Add the adaptive launch storyboard**

Create `App/LaunchScreen.storyboard` with:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<document type="com.apple.InterfaceBuilder3.CocoaTouch.Storyboard.XIB" version="3.0" toolsVersion="23094" targetRuntime="iOS.CocoaTouch" propertyAccessControl="none" useAutolayout="YES" launchScreen="YES" useTraitCollections="YES" useSafeAreas="YES" colorMatched="YES" initialViewController="launch-controller">
    <device id="retina6_12" orientation="portrait" appearance="light"/>
    <dependencies>
        <deployment identifier="iOS"/>
        <plugIn identifier="com.apple.InterfaceBuilder.IBCocoaTouchPlugin" version="23084"/>
        <capability name="Safe area layout guides" minToolsVersion="9.0"/>
        <capability name="System colors in document resources" minToolsVersion="11.0"/>
        <capability name="documents saved in the Xcode 8 format" minToolsVersion="8.0"/>
    </dependencies>
    <scenes>
        <scene sceneID="launch-scene">
            <objects>
                <viewController id="launch-controller" sceneMemberID="viewController">
                    <view key="view" contentMode="scaleToFill" id="launch-view">
                        <rect key="frame" x="0.0" y="0.0" width="393" height="852"/>
                        <autoresizingMask key="autoresizingMask" widthSizable="YES" heightSizable="YES"/>
                        <subviews>
                            <imageView userInteractionEnabled="NO" contentMode="scaleAspectFit" horizontalHuggingPriority="251" verticalHuggingPriority="251" image="LaunchWordmark" translatesAutoresizingMaskIntoConstraints="NO" id="launch-wordmark">
                                <rect key="frame" x="36" y="275" width="321" height="301"/>
                                <constraints>
                                    <constraint firstAttribute="width" secondItem="launch-wordmark" secondAttribute="height" multiplier="16:15" id="wordmark-aspect"/>
                                </constraints>
                            </imageView>
                        </subviews>
                        <viewLayoutGuide key="safeArea" id="launch-safe-area"/>
                        <color key="backgroundColor" systemColor="systemBackgroundColor"/>
                        <constraints>
                            <constraint firstItem="launch-wordmark" firstAttribute="centerX" secondItem="launch-view" secondAttribute="centerX" id="wordmark-center-x"/>
                            <constraint firstItem="launch-wordmark" firstAttribute="centerY" secondItem="launch-view" secondAttribute="centerY" id="wordmark-center-y"/>
                            <constraint firstItem="launch-wordmark" firstAttribute="width" secondItem="launch-safe-area" secondAttribute="width" multiplier="0.82" priority="750" id="wordmark-fluid-width"/>
                            <constraint firstItem="launch-wordmark" firstAttribute="width" relation="lessThanOrEqual" constant="360" id="wordmark-max-width"/>
                        </constraints>
                    </view>
                </viewController>
                <placeholder placeholderIdentifier="IBFirstResponder" id="first-responder" userLabel="First Responder" sceneMemberID="firstResponder"/>
            </objects>
            <point key="canvasLocation" x="53" y="375"/>
        </scene>
    </scenes>
    <resources>
        <image name="LaunchWordmark" width="320" height="300"/>
        <systemColor name="systemBackgroundColor">
            <color white="1" alpha="1" colorSpace="custom" customColorSpace="genericGamma22GrayColorSpace"/>
        </systemColor>
    </resources>
</document>
```

- [ ] **Step 3: Make storyboard membership and Info.plist naming iOS-only**

In `project.yml`, add platform-specific setting groups before `targets`:

```yaml
settingGroups:
  iOS:
    INFOPLIST_KEY_UILaunchStoryboardName: LaunchScreen
  macOS: {}
```

Replace `sources: [App]` in `MorseTrainerApp` with:

```yaml
    sources:
      - path: App
        excludes:
          - LaunchScreen.storyboard
      - path: App/LaunchScreen.storyboard
        destinationFilters: [iOS]
```

Add the interpolated platform group at the start of the target's existing `settings` block while retaining every existing base setting, especially `INFOPLIST_KEY_UILaunchScreen_Generation: YES`:

```yaml
    settings:
      groups:
        - ${platform}
      base:
        GENERATE_INFOPLIST_FILE: YES
        INFOPLIST_KEY_CFBundleDisplayName: "Dah Vinci"
        INFOPLIST_KEY_UILaunchScreen_Generation: YES
```

The rest of the existing `base` map remains unchanged.

- [ ] **Step 4: Regenerate the project and verify platform isolation**

Run:

```bash
xcodegen generate
xcodebuild -project MorseTrainerApp.xcodeproj \
  -target MorseTrainerApp_iOS \
  -showBuildSettings | rg 'INFOPLIST_KEY_UILaunchStoryboardName = LaunchScreen'
```

Expected: the iOS build settings contain exactly:

```text
INFOPLIST_KEY_UILaunchStoryboardName = LaunchScreen
```

Then run:

```bash
if xcodebuild -project MorseTrainerApp.xcodeproj \
  -target MorseTrainerApp_macOS \
  -showBuildSettings | rg -q 'INFOPLIST_KEY_UILaunchStoryboardName'; then
  exit 1
fi
```

Expected: exit status `0`; macOS does not receive the launch-storyboard setting.

- [ ] **Step 5: Build iOS and inspect the compiled app**

Run:

```bash
rm -rf /tmp/morse-trainer-launch-derived
xcodebuild -project MorseTrainerApp.xcodeproj \
  -scheme MorseTrainerApp-iOS \
  -sdk iphonesimulator \
  -configuration Debug \
  -derivedDataPath /tmp/morse-trainer-launch-derived \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Expected: `** BUILD SUCCEEDED **`.

Inspect the built app:

```bash
APP=/tmp/morse-trainer-launch-derived/Build/Products/Debug-iphonesimulator/MorseTrainerApp.app
find "$APP" -name 'LaunchScreen.storyboardc' -print -quit | rg 'LaunchScreen.storyboardc'
plutil -p "$APP/Info.plist" | rg '"UILaunchScreen" =>'
plutil -p "$APP/Info.plist" | rg '"UILaunchStoryboardName" => "LaunchScreen"'
xcrun --find assetutil
xcrun assetutil --info "$APP/Assets.car" | rg 'LaunchWordmark'
```

Expected: the compiled storyboard exists, `Info.plist` contains both launch keys, `assetutil` is available, and `LaunchWordmark` is present in `Assets.car`.

- [ ] **Step 6: Build macOS and confirm it remains unaffected**

Run:

```bash
xcodebuild -project MorseTrainerApp.xcodeproj \
  -scheme MorseTrainerApp \
  -sdk macosx \
  -configuration Debug \
  -derivedDataPath /tmp/morse-trainer-launch-derived-macos \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Expected: `** BUILD SUCCEEDED **`.

Then run:

```bash
MAC_APP=/tmp/morse-trainer-launch-derived-macos/Build/Products/Debug/MorseTrainerApp.app
test -z "$(find "$MAC_APP" -name 'LaunchScreen.storyboardc' -print -quit)"
if plutil -p "$MAC_APP/Contents/Info.plist" | rg -q 'UILaunchStoryboardName'; then
  exit 1
fi
```

Expected: both checks exit `0`; macOS contains neither the storyboard nor its Info.plist key.

- [ ] **Step 7: Run the package test suite**

Run:

```bash
swift test
```

Expected: all existing MorseKit and MorseUI tests pass.

- [ ] **Step 8: Commit the native launch-screen integration**

```bash
git add App/LaunchScreen.storyboard project.yml
git commit -m "feat: add branded iOS launch screen"
```
