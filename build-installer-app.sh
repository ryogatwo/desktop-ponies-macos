#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
installer_app='Install Desktop Ponies 1.6.app'
mkdir -p "$installer_app/Contents/MacOS" "$installer_app/Contents/Resources"
cp BuildTemplates/Installer-Info.plist "$installer_app/Contents/Info.plist"
ditto 'Desktop Ponies 1.6.saver' "$installer_app/Contents/Resources/Desktop Ponies 1.6.saver"
xcrun clang -fobjc-arc -O2 -Wall -Wextra -Wno-unused-parameter -arch arm64 -arch x86_64 \
  -mmacosx-version-min=11.0 -framework Cocoa Source/Installer.m -o "$installer_app/Contents/MacOS/Installer"
if [[ -n "${APPLICATION_SIGNING_IDENTITY:-}" ]]; then
  codesign --force --options runtime --timestamp --sign "$APPLICATION_SIGNING_IDENTITY" "$installer_app"
else
  codesign --force --sign - "$installer_app"
fi
