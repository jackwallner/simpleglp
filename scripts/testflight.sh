#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_YML="$ROOT/project.yml"
ARCHIVE="$ROOT/build/SimpleGLP.xcarchive"
STAGING="$ROOT/build/upload-staging"
PLIST="$ROOT/AppStoreUploadOptions.plist"

if [[ ! -f "$PLIST" ]]; then
  echo "error: missing $PLIST" >&2
  exit 1
fi

OLD=$(grep 'CURRENT_PROJECT_VERSION:' "$PROJECT_YML" | head -1 | awk '{print $2}' | tr -d '"')
NEW=$((OLD + 1))
echo "Bumping build: $OLD → $NEW"
sed -i '' "s/CURRENT_PROJECT_VERSION: \"$OLD\"/CURRENT_PROJECT_VERSION: \"$NEW\"/" "$PROJECT_YML"

echo "Generating xcodeproj..."
(cd "$ROOT" && xcodegen generate)

echo "Resolving package dependencies..."
xcodebuild -resolvePackageDependencies -project "$ROOT/SimpleGLP.xcodeproj" -scheme SimpleGLP

echo "Archiving..."
rm -rf "$ARCHIVE"
xcodebuild -project "$ROOT/SimpleGLP.xcodeproj" \
  -scheme SimpleGLP \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates \
  archive

echo "Uploading to TestFlight..."
mkdir -p "$STAGING"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE" \
  -exportPath "$STAGING" \
  -exportOptionsPlist "$PLIST" \
  -allowProvisioningUpdates

git -C "$ROOT" add "$PROJECT_YML"
git -C "$ROOT" commit -m "chore: bump build for TestFlight upload"
git -C "$ROOT" push origin HEAD

echo "Done. Build $NEW uploaded and pushed. Check App Store Connect → TestFlight for processing."
