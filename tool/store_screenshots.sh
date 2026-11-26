#!/bin/bash
# Store screenshots: runs integration_test/store/screenshots_test.dart on one
# device and captures its screen at every `SHOT:<name>` the test prints.
#
# Usage: tool/store_screenshots.sh <ios|android> <device-id> <out-dir>
#   ios:     a booted simulator's UDID (xcrun simctl list devices booted)
#   android: an emulator's serial (adb devices), e.g. emulator-5554
#
# The status bar shows 9:41, full battery and signal. Screenshots are PNGs
# with an alpha channel; convert them to RGB before uploading if a store
# refuses them.
set -u
platform=${1:?ios|android}; device=${2:?device id}; out=${3:?output dir}
mkdir -p "$out"
cd "$(dirname "$0")/.." || exit 1

if [ "$platform" = ios ]; then
  xcrun simctl status_bar "$device" override --time "9:41" --dataNetwork wifi \
    --wifiMode active --wifiBars 3 --cellularMode active --cellularBars 4 \
    --batteryState charged --batteryLevel 100
else
  demo() { adb -s "$device" shell am broadcast -a com.android.systemui.demo "$@" >/dev/null; }
  adb -s "$device" shell settings put global sysui_demo_allowed 1
  demo -e command enter
  demo -e command clock -e hhmm 0941
  demo -e command battery -e level 100 -e plugged false
  demo -e command network -e wifi show -e level 4
  demo -e command network -e mobile show -e level 4 -e datatype none
  demo -e command notifications -e visible false
fi

flutter test integration_test/store/screenshots_test.dart -d "$device" 2>&1 |
  while IFS= read -r line; do
    echo "$line"
    case "$line" in
      *SHOT:*)
        name=${line##*SHOT:}; name=${name%%[[:space:]]*}
        [ -z "$name" ] && continue
        if [ "$platform" = ios ]; then
          xcrun simctl io "$device" screenshot --type=png "$out/$name.png" >/dev/null 2>&1
        else
          adb -s "$device" exec-out screencap -p > "$out/$name.png"
        fi
        echo ">> captured $name"
        ;;
    esac
  done
