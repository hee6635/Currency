#!/usr/bin/env bash
# 에뮬레이터에 APK를 깔고 실행한 뒤, 15초 후에도 살아 있는지 확인한다.
# 꺼졌으면 오류 기록(logcat)을 남기고 실패로 끝낸다.
set -u
APK="$1"
PKG="org.myapp.vn_currency"
OUT="launch-check"
mkdir -p "$OUT"

adb install -r "$APK"
adb logcat -c
adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1
sleep 15

adb exec-out screencap -p > "$OUT/screen.png" || true
adb logcat -d > "$OUT/logcat.txt" || true

echo "----- 앱 관련 로그 -----"
grep -E "AndroidRuntime|FATAL|flutter|$PKG" "$OUT/logcat.txt" | tail -n 150 || true

if adb shell pidof "$PKG" > /dev/null; then
  echo "앱이 15초 뒤에도 실행 중이에요 (정상)"
else
  echo "::error::앱이 실행 직후 꺼졌어요. 위 로그를 확인하세요."
  exit 1
fi
