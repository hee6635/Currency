[app]
title = 환율 계산기
package.name = vn_krw_calc
package.domain = org.test
source.dir = .
source.include_exts = py,png,ttf,json
version = 0.1

icon.filename = icon.png
source.include_patterns = *.png,*.ttf,*.json

# [중요] hostpython3와 openssl은 파이썬 컴파일과 실시간 환율 통신에 필수입니다.
requirements = python3,kivy==2.3.0,pyjnius,requests,urllib3,certifi,chardet,idna,openssl,hostpython3

orientation = portrait
fullscreen = 0

# 실시간 환율용 인터넷 권한
android.permissions = INTERNET

# AIDL 라이선스 자동 동의
android.accept_sdk_license = True

android.api = 33
android.minapi = 21
android.sdk = 33
android.ndk = 25b
android.archs = arm64-v8a, armeabi-v7a
android.allow_backup = True

# 상세 로그 활성화
log_level = 2
