#!/usr/bin/env bash
# Builds a release binary and assembles dist/Magic.app, a menu-bar-only (LSUIElement) app with the
# default video bundled as Contents/Resources/magic.mp4. The app is ad-hoc signed for local use.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app="${root}/dist/Magic.app"
video="${root}/assets/magic.mp4"

main() {
  [[ -f "${video}" ]] || {
    echo "error: default video not found: ${video}" >&2
    exit 1
  }

  # Compile the optimized executable.
  (cd "${root}" && swift build -c release)
  local bin
  bin="$(cd "${root}" && swift build -c release --show-bin-path)/Magic"

  # Recreate the bundle skeleton from scratch so stale files never linger.
  rm -rf "${app}"
  mkdir -p "${app}/Contents/MacOS" "${app}/Contents/Resources"
  cp "${bin}" "${app}/Contents/MacOS/Magic"
  cp "${video}" "${app}/Contents/Resources/magic.mp4"

  # LSUIElement hides the Dock icon; the status item is the only UI entry point.
  cat >"${app}/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>dev.byron.magic</string>
  <key>CFBundleName</key><string>Magic</string>
  <key>CFBundleExecutable</key><string>Magic</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

  # Ad-hoc sign so Gatekeeper treats the bundle as a coherent, unmodified app.
  codesign --force --sign - "${app}"
  echo "Built ${app}"
}

main "$@"
