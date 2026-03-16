[app]
title = 베트남 환율
package.name = vn_krw_calc
package.domain = org.myapp
source.dir = .

# ttc(폰트) 확장자를 추가했습니다.
source.include_exts = py,png,ttf,json,ttc
version = 0.1
icon.filename = icon.png

# UrlRequest 사용 시 requests는 필수가 아니지만, 호환성을 위해 certifi와 openssl은 유지합니다.
requirements = python3,kivy==2.3.0,certifi,openssl

orientation = portrait
fullscreen = 0

android.permissions = INTERNET
android.accept_sdk_license = True
android.api = 33
android.minapi = 21
android.ndk_api = 21

# 빌드 속도와 호환성을 잡는 최고의 선택입니다.
android.archs = arm64-v8a
android.allow_backup = True

[buildozer]
log_level = 2
warn_on_root = 1
