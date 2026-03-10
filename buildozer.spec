[app]
title = 환율 계산기
package.name = vn_krw_calc
package.domain = org.test
source.dir = .
source.include_exts = py,png,ttf,json
version = 0.1

icon.filename = icon.png
source.include_patterns = *.png,*.ttf,*.json

# [핵심] pyjnius, openssl, hostpython3를 모두 포함하여 런타임/빌드 에러 방지
requirements = python3,kivy==2.3.0,pyjnius,requests,urllib3,certifi,chardet,idna,openssl,hostpython3

orientation = portrait
fullscreen = 0
android.permissions = INTERNET
android.accept_sdk_license = True
android.api = 33
android.minapi = 21
android.sdk = 33
android.ndk = 25b
android.archs = arm64-v8a, armeabi-v7a
android.allow_backup = True
log_level = 2
