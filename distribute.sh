#!/usr/bin/env bash
#
# Builds a signed App Store archive of Dah Vinci (iOS) and opens it in the
# Xcode Organizer so you can click Distribute App -> App Store Connect -> Upload.
# See docs/app-store/DISTRIBUTION.md for the full flow.
#
set -euo pipefail

cd "$(dirname "$0")"

PROJECT="MorseTrainerApp.xcodeproj"
SCHEME="MorseTrainerApp-iOS"
ARCHIVE="build/DahVinci.xcarchive"

echo "==> Regenerating the Xcode project (picks up project.yml changes)"
xcodegen generate

# Auto-increment the build number (CFBundleVersion) so each upload is unique
# and monotonically increasing, without editing project.yml. App Store Connect
# rejects a build whose number isn't higher than a previously uploaded one.
BUILD_NUMBER="$(date +%Y%m%d%H%M)"

echo "==> Archiving ${SCHEME} for generic iOS device (build ${BUILD_NUMBER})"
echo "    (signs with your team; -allowProvisioningUpdates may create the"
echo "     distribution cert/profile on first run — this touches your account)"
rm -rf "${ARCHIVE}"
xcodebuild archive \
  -project "${PROJECT}" \
  -scheme "${SCHEME}" \
  -destination 'generic/platform=iOS' \
  -archivePath "${ARCHIVE}" \
  -allowProvisioningUpdates \
  CURRENT_PROJECT_VERSION="${BUILD_NUMBER}"

echo "==> Opening the archive in the Xcode Organizer"
open "${ARCHIVE}"

cat <<'NEXT'

Archive built and opened in the Organizer.
Next, in the Organizer window:
  Distribute App  ->  App Store Connect  ->  Upload
Then finish the submission in App Store Connect (metadata is in
docs/app-store/metadata.md).
NEXT
