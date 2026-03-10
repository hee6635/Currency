[app]
# (기본 정보)
title = 환율 계산기
package.name = vn_krw_calc
package.domain = org.test
source.dir = .
source.include_exts = py,png,ttf,json
version = 0.1

# (리소스 설정) 준비하신 파일명과 정확히 일치해야 함
icon.filename = icon.png
source.include_patterns = *.png,*.ttf,*.json

# [중요] hostpython3와 openssl을 추가하여 빌드 오류와 SSL 에러를 방지합니다.
requirements = python3,kivy==2.3.0,requests,urllib3,certifi,chardet,idna,openssl,hostpython3

orientation = portrait
fullscreen = 0

# [중요] 실시간 환율을 위한 인터넷 권한
android.permissions = INTERNET

# [중요] AIDL 에러 해결을 위한 라이선스 자동 동의
android.accept_sdk_license = True

# (안드로이드 설정) 2026년 기준 가장 안정적인 API 33 사용
android.api = 33
android.minapi = 21
android.sdk = 33
android.ndk = 25b
android.archs = arm64-v8a, armeabi-v7a
android.allow_backup = True

# 빌드 시 로그를 더 자세히 보기 위함
log_level = 2
