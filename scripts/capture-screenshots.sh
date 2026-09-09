#!/bin/bash
# Captures App Store screenshots for every locale from the 46mm watch simulator.
#
# Screens are reached through the DEMO_SCREEN / DEMO_STATS / DEMO_PROFILE launch
# hooks (Debug builds only). Run from anywhere:
#
#   ./scripts/capture-screenshots.sh
#
# The watch status bar shows the Mac's clock, and simctl cannot override it on
# watchOS. To get Apple's customary 9:41 in every shot, turn off automatic time
# in System Settings, then:
#
#   sudo -v                                   # cache credentials for 15 minutes
#   PIN_TIME=09:41:00 ./scripts/capture-screenshots.sh
#
# Verify afterwards with: swift scripts/read-clock.swift AppStorePrep/screenshots/*/*.png
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD="${BUILD_DIR:-$ROOT/build/DerivedData-shots}"
BUNDLE=com.hoshinosoftware.doremiteacher.watchkitapp
APP="$BUILD/Build/Products/Debug-watchsimulator/Doremi Teacher Watch App.app"

# Apple Watch Series 11 (46mm), watchOS 26.5 → 416x496. App Store Connect
# scales that down for every smaller watch.
UDID=FFF4BF67-1E1A-455C-944A-D0C24AE4FA3A
LOCALES=(en:en_US ja:ja_JP tr:tr_TR)
# name:DEMO_SCREEN:extra env
SHOTS=(
  "1-home::"
  "2-listen:listening:"
  "3-feedback:feedback-wrong:DEMO_PROFILE=saz"
  "4-instrument:instrument:DEMO_PROFILE=saz"
  "5-settings:settings:DEMO_PROFILE=saz-twelve"
  "6-stats:stats:DEMO_STATS=14,3,120,41,9,2,80,30"
)

pin_clock() {
  [[ -n "${PIN_TIME:-}" ]] || return 0
  sudo -n /usr/sbin/systemsetup -settime "$PIN_TIME" >/dev/null 2>&1 ||
    echo "    (could not set clock — run 'sudo -v' first, and turn off automatic time)"
}

if [[ "${SKIP_BUILD:-}" != "1" ]]; then
  echo "==> Building"
  xcodebuild -project "$ROOT/DoremiTeacher.xcodeproj" -scheme DoremiTeacher \
    -destination 'generic/platform=watchOS Simulator' -derivedDataPath "$BUILD" \
    build >/dev/null
fi

# The simulator adopts the Mac's clock at boot and never follows a later change,
# so it comes up cold after the clock is pinned.
if [[ -n "${PIN_TIME:-}" ]]; then
  xcrun simctl shutdown "$UDID" 2>/dev/null || true
  pin_clock
fi
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b >/dev/null
# Always install: SKIP_BUILD reuses a build, it does not mean the simulator has it.
xcrun simctl install "$UDID" "$APP"

for loc in "${LOCALES[@]}"; do
  lang="${loc%%:*}"; locale="${loc##*:}"
  out="$ROOT/AppStorePrep/screenshots/$lang"
  mkdir -p "$out"

  for shot in "${SHOTS[@]}"; do
    IFS=: read -r name screen extra <<< "$shot"
    env ${screen:+SIMCTL_CHILD_DEMO_SCREEN="$screen"} \
        ${extra:+SIMCTL_CHILD_$extra} \
        xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE" \
        -AppleLanguages "($lang)" -AppleLocale "$locale" >/dev/null
    sleep 3
    pin_clock
    xcrun simctl io "$UDID" screenshot --type png "$out/$name.png" 2>/dev/null
    echo "    $lang/$name.png"
  done
done

echo "==> Done. Sizes:"
find "$ROOT/AppStorePrep/screenshots" -name "*.png" -exec sips -g pixelWidth -g pixelHeight {} \; 2>/dev/null |
  grep -E "pixel" | sort | uniq -c
