# Dah Vinci iOS Launch Screen Design

**Date:** 2026-07-16
**Status:** Approved visual direction

## Goal

Give the iOS app a branded native launch screen derived from the existing app icon. The screen should identify the app as “Dah Vinci,” reinforce the Morse-learning theme, adapt to light and dark appearance, and disappear as soon as the app is ready. It must not add an artificial post-launch delay.

## Approved Visual Design

The launch screen uses a centered, vertically stacked lockup:

1. `Dah` in large, heavy, rounded type.
2. The Morse for `Dah` directly underneath.
3. `Vinci` in the same title treatment.
4. The Morse for `Vinci` directly underneath.

The title and Morse marks share the app icon's diagonal blue-violet-to-cyan gradient:

- Start: `#756EE8`
- Middle: `#377FF1`
- End: `#16B8D8`

The background uses the iOS adaptive system background, producing a light background in light appearance and a dark background in dark appearance.

### Morse Construction

Morse is drawn as vector geometry rather than font glyphs:

- A dit is a solid circle.
- A dah is a rounded bar three times the width of a dit.
- Dit diameter and dah thickness are equal.
- Marks within one letter remain closely grouped.
- Gaps between letters are 1.7 times the mark thickness.
- The final mark thickness is 25% lighter than the first vector mockup while remaining heavier and clearer than the font-based mockups.

The encoded text is:

- `Dah`: `-.. .- ....`
- `Vinci`: `...- .. -. -.-. ..`

The display uses geometric marks, but the ASCII sequences above are the verification source of truth.

## Implementation Approach

Use one deterministic vector image asset for the complete foreground lockup. Text and Morse geometry are part of the same asset so their proportions, spacing, and gradient remain exact across devices. The image is centered with aspect-fit constraints in a native iOS launch storyboard over `systemBackgroundColor`.

The vector asset is preferred over:

- Font-rendered Morse, because dot and dash glyphs do not become thick enough consistently.
- Full-screen raster images, because they require multiple device crops and appearance variants.
- A SwiftUI startup overlay, because it would appear after native launch and could delay access to the app.

The iOS target will name the storyboard through generated Info.plist settings. The existing generated `UILaunchScreen` entry remains enabled so the built app continues to declare a launch screen and runs at native device resolution. The macOS target remains unchanged.

## Layout and Scaling

- Center the complete lockup horizontally and vertically within the safe area.
- Preserve the asset's aspect ratio.
- Cap the lockup width so it remains comfortably inset on compact iPhones.
- Allow it to scale up moderately on iPad without dominating the screen.
- Keep the `Dah` and `Vinci` title sizes equal.
- Keep the vertical gap between each title and its Morse smaller than the gap between the two word groups.
- Do not add logos, shadows, animation, loading indicators, or extra copy.

## Validation

Implementation is complete when:

1. The launch screen appears on iOS in both light and dark appearance.
2. The lockup is centered, crisp, and unclipped on a compact iPhone and an iPad-sized layout.
3. The Morse geometry matches `-.. .- ....` and `...- .. -. -.-. ..` exactly.
4. Dits are circles, dahs are rounded bars, and inter-letter gaps are wider than intra-letter gaps.
5. The app transitions directly from the native launch screen to `RootView` without an added hold.
6. The built app's `Info.plist` contains a `UILaunchScreen` key and the configured launch storyboard name.
7. The existing macOS app still builds without adopting the iOS launch storyboard.
