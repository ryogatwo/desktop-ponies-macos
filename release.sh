#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
: "${APPLICATION_SIGNING_IDENTITY:?Set your Developer ID Application identity}"
: "${NOTARY_KEYCHAIN_PROFILE:?Set your existing notarytool Keychain profile}"
[[ "$APPLICATION_SIGNING_IDENTITY" == 'Developer ID Application:'* ]] || { echo 'A Developer ID Application identity is required.' >&2; exit 1; }
bash build.sh
bash build-installer-app.sh
installer_app='Install Desktop Ponies 1.7.app'
ditto -c -k --sequesterRsrc --keepParent "$installer_app" notarization-upload.zip
xcrun notarytool submit notarization-upload.zip --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" --wait --output-format json > notarization-app.json
[[ "$(/usr/bin/plutil -extract status raw -o - notarization-app.json)" == Accepted ]]
xcrun stapler staple "$installer_app"
xcrun stapler validate "$installer_app"
codesign --verify --deep --strict "$installer_app"
spctl --assess --type execute --verbose=2 "$installer_app"
image_stage=$(mktemp -d "${TMPDIR:-/tmp}/desktop-ponies-dmg.XXXXXX")
trap 'rm -rf "$image_stage"' EXIT
ditto "$installer_app" "$image_stage/$installer_app"
printf '%s\n' 'Open Install Desktop Ponies 1.7.app, then click Install Screensaver.' > "$image_stage/READ ME.txt"
release_dmg='../Desktop.Ponies.1.7.Installer.dmg'
hdiutil create -volname 'Desktop Ponies 1.7' -srcfolder "$image_stage" -format UDZO -ov "$release_dmg"
codesign --force --timestamp --sign "$APPLICATION_SIGNING_IDENTITY" "$release_dmg"
xcrun notarytool submit "$release_dmg" --keychain-profile "$NOTARY_KEYCHAIN_PROFILE" --wait --output-format json > notarization-dmg.json
[[ "$(/usr/bin/plutil -extract status raw -o - notarization-dmg.json)" == Accepted ]]
xcrun stapler staple "$release_dmg"
xcrun stapler validate "$release_dmg"
spctl --assess --type open --context context:primary-signature --verbose=2 "$release_dmg"
(cd "$(dirname "$release_dmg")" && shasum -a 256 "$(basename "$release_dmg")") > '../Desktop.Ponies.1.7.Installer.sha256' 
echo 'Accepted by Apple; tickets stapled and validated. The disk image is ready to publish.'
