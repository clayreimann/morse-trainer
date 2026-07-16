# Distribution guide — TestFlight / App Store

## Prerequisites

1. Join the paid Apple Developer Program for the team that will publish the app.
2. Create the App Store Connect app record for bundle ID `cloud.madtown.morse.app`.
3. Put `DEVELOPMENT_TEAM` and `CODE_SIGN_STYLE = Automatic` in the ignored
   `Signing.xcconfig`, using the publishing team identifier shown in the Apple
   Developer membership page.

## Xcode Organizer

1. Run `xcodegen generate` and open `MorseTrainerApp.xcodeproj`.
2. Select `MorseTrainerApp-iOS` and **Any iOS Device**.
3. Confirm automatic signing uses the publishing team.
4. Choose **Product → Archive**.
5. In Organizer, choose **Distribute App → App Store Connect → Upload**.
6. After processing, attach the build to TestFlight or the App Store version.

## Command line

```sh
xcodebuild archive \
  -project MorseTrainerApp.xcodeproj \
  -scheme MorseTrainerApp-iOS \
  -destination 'generic/platform=iOS' \
  -archivePath build/DahVinci.xcarchive \
  -allowProvisioningUpdates

xcodebuild -exportArchive \
  -archivePath build/DahVinci.xcarchive \
  -exportOptionsPlist docs/app-store/ExportOptions.plist \
  -exportPath build/export \
  -allowProvisioningUpdates
```

Upload the exported app with Xcode Organizer or Transporter. Never commit App
Store Connect API keys, `.p8` files, signing certificates, or provisioning
profiles.

The App Store copy and URLs are maintained in [metadata.md](metadata.md).
