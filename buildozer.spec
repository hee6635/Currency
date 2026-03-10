[app]
title = 환율 계산기
package.name = vn_krw_calc
package.domain = org.test
source.dir = .
source.include_exts = py,png,ttf,json
version = 0.1

icon.filename = icon.png
# patterns에 ttf, png가 이미 있으므로 assets 경로는 파일이 있을 때만 유지하세요
source.include_patterns = *.png,*.ttf,*.json

# [수정됨] openssl 필수 포함
requirements = python3,kivy==2.3.0,requests,urllib3,certifi,chardet,idna,openssl

orientation = portrait
fullscreen = 0

# [추가됨] 인터넷 권한 필수
android.permissions = INTERNET

# [수정됨] API 버전 고정
android.api = 33
android.minapi = 21
android.archs = arm64-v8a, armeabi-v7a
android.allow_backup = True
