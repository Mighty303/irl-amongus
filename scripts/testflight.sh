#!/bin/zsh
# Archive a Release build and upload it to TestFlight, signed with Kai's team and App Store Connect bundle ID.
# The shared project keeps its own team and bundle ID (so everyone's local builds keep working); these are
# applied only to this archive. Needs the app record in App Store Connect and your Apple ID in Xcode
# (Settings > Accounts). The build number is the date and time, so every upload is newer than the last.
#
#   scripts/testflight.sh            archive and upload
#   scripts/testflight.sh --archive  archive only (check signing without uploading)
set -euo pipefail
cd "$(dirname "$0")/.."

TEAM=${TEAM:-2893AZGG46}
BUNDLE_ID=${BUNDLE_ID:-com.kaisamson.IRLAmongUs}
BUILD=${BUILD:-$(date +%y%m%d%H%M)}
OUT=build/testflight
ARCHIVE=$OUT/IRLAmongUs.xcarchive

rm -rf $OUT && mkdir -p $OUT
echo "Archiving $BUNDLE_ID build $BUILD (team $TEAM)…"
xcodebuild archive -project IRLAmongUs.xcodeproj -scheme IRLAmongUs -configuration Release \
  -destination 'generic/platform=iOS' -archivePath $ARCHIVE -allowProvisioningUpdates \
  DEVELOPMENT_TEAM=$TEAM PRODUCT_BUNDLE_IDENTIFIER=$BUNDLE_ID CURRENT_PROJECT_VERSION=$BUILD \
  | grep -E "error:|warning: .*signing|ARCHIVE (SUCCEEDED|FAILED)" || true
[[ -d $ARCHIVE ]] || { echo "Archive failed"; exit 1; }
[[ ${1:-} == --archive ]] && { echo "Archived: $ARCHIVE"; exit 0; }

cat > $OUT/ExportOptions.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key><string>app-store-connect</string>
	<key>destination</key><string>upload</string>
	<key>teamID</key><string>$TEAM</string>
	<key>signingStyle</key><string>automatic</string>
	<key>uploadSymbols</key><true/>
</dict>
</plist>
PLIST
echo "Uploading to App Store Connect…"
xcodebuild -exportArchive -archivePath $ARCHIVE -exportOptionsPlist $OUT/ExportOptions.plist \
  -exportPath $OUT/export -allowProvisioningUpdates
echo "Uploaded build $BUILD. It shows in App Store Connect > TestFlight once Apple finishes processing."
