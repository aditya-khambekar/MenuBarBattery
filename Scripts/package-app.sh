#!/bin/sh
# Wraps the Swift package binary into MenuBarBattery.app next to the package.
# Build first: swift build
# Optional binary path as $1 (defaults to .build/debug/MenuBarBattery).

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
binary=${1:-"$root/.build/debug/MenuBarBattery"}

if [ ! -x "$binary" ]; then
  echo "Missing executable: $binary" >&2
  echo "Build the package, then run this script." >&2
  exit 1
fi

app="$root/MenuBarBattery.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp "$binary" "$app/Contents/MacOS/MenuBarBattery"
cp "$root/Scripts/Info.plist" "$app/Contents/Info.plist"
chmod +x "$app/Contents/MacOS/MenuBarBattery"

if command -v codesign >/dev/null 2>&1; then
  codesign --force --sign - "$app"
fi

echo "$app"
