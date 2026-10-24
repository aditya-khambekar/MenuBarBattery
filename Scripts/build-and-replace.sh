#!/bin/sh
# Build MenuBarBattery, package it, and replace every installed copy so Spotlight
# opens the build you just made.
#
# Usage: ./Scripts/build-and-replace.sh

set -eu

root=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
bundle_id="com.menubarattery.MenuBarBattery"
fresh="$root/MenuBarBattery.app"
lsregister="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

is_menubar_battery_app() {
  app=$1
  plist="$app/Contents/Info.plist"
  if [ ! -f "$plist" ]; then
    return 1
  fi
  id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$plist" 2>/dev/null || true)
  [ "$id" = "$bundle_id" ]
}

collect_app_paths() {
  if command -v mdfind >/dev/null 2>&1; then
    mdfind "kMDItemCFBundleIdentifier == '$bundle_id'" 2>/dev/null || true
  fi

  for dir in \
    "$HOME/Applications" \
    "/Applications" \
    "$HOME/Desktop" \
    "$HOME/Desktop/allprojects" \
    "$root"; do
    [ -d "$dir" ] || continue
    find "$dir" -name 'MenuBarBattery.app' -type d -maxdepth 6 2>/dev/null || true
  done

  printf '%s\n' "$HOME/Applications/MenuBarBattery.app"
}

register_app() {
  app=$1
  if [ -x "$lsregister" ]; then
    "$lsregister" -f "$app" >/dev/null 2>&1 || true
  fi
}

replace_app_at() {
  dest=$1
  if [ "$dest" = "$fresh" ]; then
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  rm -rf "$dest"
  ditto "$fresh" "$dest"
  register_app "$dest"
  echo "Updated: $dest"
}

echo "Building release…"
(cd "$root" && swift build -c release)

echo "Packaging…"
"$root/Scripts/package-app.sh" "$root/.build/release/MenuBarBattery"
register_app "$fresh"

if pgrep -xq MenuBarBattery; then
  echo "Quitting running MenuBarBattery…"
  pkill -x MenuBarBattery || true
  sleep 0.5
fi

seen=""
for candidate in $(collect_app_paths | sort -u); do
  if [ -d "$candidate" ] && ! is_menubar_battery_app "$candidate"; then
    continue
  fi
  case " $seen " in
    *" $candidate "*) continue ;;
  esac
  seen="$seen $candidate"
  replace_app_at "$candidate"
done

echo "Done. Fresh app: $fresh"
echo "Spotlight: open MenuBarBattery (or “Menu Bar Battery”)."
