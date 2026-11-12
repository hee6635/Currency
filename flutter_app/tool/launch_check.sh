#!/usr/bin/env bash
# 에뮬레이터에 APK를 깔고 실행한 뒤, 15초 후에도 살아 있는지 확인한다.
# 홈 화면 위젯·측면 버튼으로 여는 음성 창(VoicePopupActivity)도 띄워 본다.
# 꺼졌으면 오류 기록(logcat)을 남기고 실패로 끝낸다.
set -u
APK="$1"
PKG="org.myapp.vn_currency"
OUT="launch-check"
mkdir -p "$OUT"
FAIL=0

adb install -r "$APK"
adb logcat -c

# 1) 앱
adb shell am start -n "$PKG/.MainActivity"
sleep 15
adb exec-out screencap -p > "$OUT/screen.png" || true
if adb shell pidof "$PKG" > /dev/null; then
  echo "앱이 15초 뒤에도 실행 중이에요 (정상)"
else
  echo "::error::앱이 실행 직후 꺼졌어요. 아래 로그를 확인하세요."
  FAIL=1
fi

# 2) 홈 화면 위 음성 창 (위젯·"말로 입력" 바로가기로 여는 화면)
adb shell input keyevent KEYCODE_HOME
sleep 2
adb shell am start -n "$PKG/.VoicePopupActivity"
sleep 12
adb exec-out screencap -p > "$OUT/voice-popup.png" || true
if adb shell dumpsys activity activities | grep -q "VoicePopupActivity"; then
  echo "음성 창이 떠 있어요 (정상)"
else
  echo "::error::음성 창(VoicePopupActivity)이 뜨지 않거나 꺼졌어요."
  FAIL=1
fi

# 3) 위젯·바로가기 등록 확인
adb shell dumpsys package "$PKG" > "$OUT/package.txt" || true
for name in RateWidgetWide RateWidgetSquare; do
  if grep -q "$name" "$OUT/package.txt"; then
    echo "$name 등록됨"
  else
    echo "::error::$name 이(가) 앱에 등록되지 않았어요."
    FAIL=1
  fi
done

adb logcat -d > "$OUT/logcat.txt" || true
echo "----- 앱 관련 로그 -----"
grep -E "AndroidRuntime|FATAL|flutter|$PKG" "$OUT/logcat.txt" | tail -n 150 || true
if grep -A3 "FATAL EXCEPTION" "$OUT/logcat.txt" | grep -q "$PKG"; then
  echo "::error::앱에서 오류로 꺼진 기록이 있어요."
  FAIL=1
fi
exit $FAIL
