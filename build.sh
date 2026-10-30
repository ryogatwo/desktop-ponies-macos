#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p 'Desktop Ponies 1.7.saver/Contents/MacOS' 'Desktop Ponies 1.7.saver/Contents/Resources' 'Desktop Ponies Preview.app/Contents/MacOS'
cp BuildTemplates/Saver-Info.plist 'Desktop Ponies 1.7.saver/Contents/Info.plist'
cp BuildTemplates/Preview-Info.plist 'Desktop Ponies Preview.app/Contents/Info.plist'
xcrun clang -fobjc-arc -O2 -Wall -Wextra -Wno-unused-parameter -arch arm64 -arch x86_64 -mmacosx-version-min=11.0 -framework Cocoa -framework ScreenSaver -framework ImageIO -bundle Source/PoniesView.m -o 'Desktop Ponies 1.7.saver/Contents/MacOS/DesktopPonies'
cp -R Resources/. 'Desktop Ponies 1.7.saver/Contents/Resources/'
xcrun clang -fobjc-arc -O2 -Wall -Wextra -Wno-unused-parameter -arch arm64 -arch x86_64 -mmacosx-version-min=11.0 -framework Cocoa -framework ScreenSaver Source/Preview.m -o 'Desktop Ponies Preview.app/Contents/MacOS/Preview'
/usr/libexec/PlistBuddy -c 'Print' 'Desktop Ponies 1.7.saver/Contents/Info.plist' >/dev/null
if [[ -n "${APPLICATION_SIGNING_IDENTITY:-}" ]]; then
  codesign --force --options runtime --timestamp --sign "$APPLICATION_SIGNING_IDENTITY" 'Desktop Ponies 1.7.saver'
  codesign --force --options runtime --timestamp --sign "$APPLICATION_SIGNING_IDENTITY" 'Desktop Ponies Preview.app'
else
  codesign --force --sign - 'Desktop Ponies 1.7.saver'
  codesign --force --sign - 'Desktop Ponies Preview.app'
fi
