[app]
title = 환율 계산기
package.name = vn_krw_calc
package.domain = org.test
source.dir = .
source.include_exts = py,png,ttf,json
version = 0.1

icon.filename = icon.png
source.include_patterns = *.png,*.ttf,*.json

# [중요] 빌드 안정성을 위해 순서를 조정하고 openssl과 hostpython3를 포함했습니다.
requirements = python3,kivy==2.3.0,requests,urllib3,certifi,chardet,idna,openssl,hostpython3

orientation = portrait
fullscreen = 0

# 권한 및 라이선스
android.permissions = INTERNET
android.accept_sdk_license = True

# 안드로이드 SDK/NDK 설정 (가장 검증된 조합)
android.api = 33
android.minapi = 21
android.sdk = 33
android.ndk = 25b
android.archs = arm64-v8a, armeabi-v7a
android.allow_backup = True

# 빌드 엔진 설정
p4a.branch = master
log_level = 2
