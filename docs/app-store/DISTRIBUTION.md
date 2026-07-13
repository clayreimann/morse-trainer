# Distribution guide — TestFlight / App Store

The app builds and **archives cleanly** (verified). What remains needs your Apple account and credentials, so it can't be automated from a headless tool. Two paths — the Xcode GUI is by far the easiest.

## Prerequisites (one-time)
1. **Paid Apple Developer Program** membership on the team you'll ship with. Confirm the **Team ID** at developer.apple.com → Membership, and make sure `Signing.xcconfig` (`DEVELOPMENT_TEAM`) matches it. (Currently `PQMW4AT355`.)
2. **Distribution certificate** — you currently have only "Apple Development" certs. Xcode creates the "Apple Distribution" cert automatically the first time you distribute (GUI path), or via `-allowProvisioningUpdates` (CLI). This writes to your account.
3. **App Store Connect app record** — at appstoreconnect.apple.com → Apps → +, choose the bundle ID `com.morsetrainer.app`, platform iOS. (You can't upload a build until this exists.)

## Path A — Xcode Organizer (recommended)
1. `xcodegen generate` (if needed), open `MorseTrainerApp.xcodeproj`.
2. Select the **MorseTrainerApp-iOS** scheme, destination **Any iOS Device**.
3. Ensure **Signing & Capabilities** shows your paid team with "Automatically manage signing."
4. **Product → Archive.**
5. In the Organizer: **Distribute App → App Store Connect → Upload.** Xcode creates the distribution cert/profile, signs, and uploads.
6. The build appears in App Store Connect → TestFlight after processing (a few minutes). Add it to a TestFlight group to test, or attach it to the 1.0 App Store version and submit for review.

## Path B — Command line
```bash
# 1) Archive (signed, creates cert/profile if missing — this MODIFIES your account)
xcodebuild archive \
  -project MorseTrainerApp.xcodeproj \
  -scheme MorseTrainerApp-iOS \
  -destination 'generic/platform=iOS' \
  -archivePath build/MorseTrainer.xcarchive \
  -allowProvisioningUpdates

# 2) Export a signed .ipa for the App Store
xcodebuild -exportArchive \
  -archivePath build/MorseTrainer.xcarchive \
  -exportOptionsPlist docs/app-store/ExportOptions.plist \
  -exportPath build/export \
  -allowProvisioningUpdates

# 3) Upload to App Store Connect (needs an App Store Connect API key: Issuer ID + Key ID + .p8)
xcrun altool --upload-app -f build/export/MorseTrainerApp.ipa -t ios \
  --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>
# (or: xcrun notarytool / Transporter app / Xcode Organizer)
```

## What I (the assistant) can't do for you
- **Create the App Store Connect app record** — that's a web action in your account.
- **Create the distribution certificate / provisioning profile** — modifies your Apple Developer account; needs your credentials and should stay under your control.
- **Upload to TestFlight / App Store** — requires App Store Connect credentials (an API `.p8` key or app-specific password). Handling those secrets isn't something I do; run the upload yourself (Organizer is easiest) or set up an API key and run step 3.

Once the build is in TestFlight, paste the metadata from `metadata.md` and submit.
