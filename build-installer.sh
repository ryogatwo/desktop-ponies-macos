#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
installer_stage=$(mktemp -d "${TMPDIR:-/tmp}/desktop-ponies-installer.XXXXXX")
trap 'rm -rf "$installer_stage"' EXIT
mkdir -p "$installer_stage/payload"
ditto 'Desktop Ponies 1.7.saver' "$installer_stage/payload/Desktop Ponies 1.7.saver"
pkgbuild --root "$installer_stage/payload" --component-plist Installer/Components.plist \
  --identifier org.desktopponies.mac.installer.v17 --version 1.7 \
  --install-location '/Library/Screen Savers' "$installer_stage/DesktopPoniesPayload.pkg"
installer_signing_args=()
if [[ -n "${INSTALLER_SIGNING_IDENTITY:-}" ]]; then
  installer_signing_args=(--sign "$INSTALLER_SIGNING_IDENTITY" --timestamp)
fi
productbuild "${installer_signing_args[@]}" --distribution Installer/Distribution.xml --resources Installer/Resources \
  --package-path "$installer_stage" '../Desktop Ponies 1.7 Installer.pkg'
