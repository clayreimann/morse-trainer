# App Store metadata — Morse Trainer 1.0

Paste these into App Store Connect. Character limits noted; counts are approximate — trim if the field complains.

## Basics
- **App name** (≤30): `Morse Trainer`
- **Subtitle** (≤30): `Learn Morse code by keying`
- **Primary category:** Education
- **Secondary category:** Utilities
- **Age rating:** 4+ (no objectionable content)
- **Copyright:** `© 2026 Clay Jensen-Reimann`
- **Bundle ID:** `cloud.madtown.morse.app`
- **SKU (your choice):** `morse-trainer-ios`
- **Price:** Free (suggested)

## Promotional text (≤170) — editable anytime without review
```
Learn Morse code by sending and copying real words — adaptive hints, a live speed gauge, and listen-and-copy practice. Fully private and offline.
```

## Description (≤4000)
```
Morse Trainer teaches you Morse code the way you actually use it — by sending and copying real words, not just memorizing dots and dashes.

LEARN BY DOING
Work through a guided progression that introduces a few letters at a time and drills them inside common words, so every letter sticks in context. As you get faster and more confident, hints fade automatically — the app tracks your accuracy and hesitation on each letter and stops holding your hand once you've got it. The path covers the full alphabet, one small step at a time.

SEND
Key out each word with a straight key or paddle. On Mac you can send with the space bar, plus a configurable dot/dash key pair. Letters turn green as you send them correctly, with a live readout of what you've keyed and a speed gauge that shows your actual words-per-minute so you can hear and see your fist improve.

LISTEN & COPY
Train your ear: hear Morse and type what you copy — letter by letter as it plays, or the whole word at once.

PLAYGROUND
Type anything and hear it in Morse, or read its dots and dashes.

MAKE IT YOURS
- Speed in words per minute (PARIS standard)
- Farnsworth and word spacing for learning by ear without counting
- Adjustable tone frequency (default 550 Hz)
- Straight key or paddle input
- Optional key sidetone

PRIVATE BY DESIGN
Everything runs on-device. No account, no ads, no tracking — nothing you do leaves your device.

Whether you're studying for a ham radio license, prepping for CW, or you just love the rhythm of the code, Morse Trainer helps you build a real fist and reliable copy, one word at a time.
```

## Keywords (≤100, comma-separated, no spaces after commas)
```
morse,code,cw,telegraph,ham,radio,practice,koch,paris,wpm,farnsworth,dit,dah,keyer,amateur
```

## URLs
- **Support URL** (required): `https://github.com/clayreimann/morse-trainer` — or a dedicated page with a contact method.
- **Marketing URL** (optional): same, or leave blank.
- **Privacy Policy URL** (required): host `docs/app-store/privacy-policy.md` somewhere public (GitHub Pages, a Gist, or the repo's raw file) and use that URL.

## What's New (version 1.0 release notes)
```
First release. Learn Morse by sending real words with adaptive hints, copy by ear, hear any text in the Playground, and dial in your speed, Farnsworth spacing, and tone.
```

## App Privacy (App Store Connect questionnaire)
- **Data collection:** No — select **"Data Not Collected."**
- **Tracking:** No.
- This matches the bundled `PrivacyInfo.xcprivacy` (no tracking, no collected data types, UserDefaults declared under required-reason `CA92.1`).

## Screenshots (you must capture these)
Required sizes (portrait):
- iPhone 6.9" (e.g. iPhone 16 Pro Max) — 1320×2868
- iPhone 6.5" (e.g. iPhone 11 Pro Max / 15 Plus) — 1242×2688
- iPad 13" (if you enable iPad) — 2064×2752
Suggested shots: Learn/Send mid-word (green letters + speed gauge), Listen copy mode, Playground, Settings, Reference chart. 3–5 per size is plenty.
Tip: capture in the Simulator with `xcrun simctl io booted screenshot shot.png` at the right device.
