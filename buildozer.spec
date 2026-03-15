[app]
title = 베트남 환율
package.name = vn_krw_calc
package.domain = org.myapp

source.dir = .
source.include_exts = py,png,ttf,json
version = 0.1

icon.filename = icon.png
source.include_patterns = *.png,*.ttf,*.json

# 인터넷 통신(requests)과 암호화(openssl) 필수 포함
requirements = python3,kivy==2.3.0,requests,urllib3,certifi,chardet,idna,openssl

orientation = portrait
fullscreen = 0

# 실시간 환율을 위한 권한
android.permissions = INTERNET
android.accept_sdk_license = True

android.api = 33
android.minapi = 21
android.ndk_api = 21

# 핵심: 최신 기종용 1개만 빌드하여 꼬임을 방지하고 속도를 2배 높입니다.
android.archs = arm64-v8a
android.allow_backup = True

[buildozer]
log_level = 2
warn_on_root = 1
