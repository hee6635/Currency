[app]
# 앱의 이름과 패키지 설정
title = 환율 계산기
package.name = currencycalc
package.domain = org.myapp

# 소스 코드 위치 및 포함할 파일 확장자 (이미지 파일들도 포함)
source.dir = .
source.include_exts = py,png,jpg,jpeg,kv,atlas

# 앱 버전
version = 1.0

# ★ 중요: 환율 데이터를 가져오기 위해 requests와 urllib3가 반드시 필요합니다!
requirements = python3,kivy,requests,urllib3

# 앱 방향 (세로 모드 고정)
orientation = portrait
fullscreen = 0

# (선택) 아까 만드신 고급스러운 앱 아이콘 이미지를 폴더에 넣고 이름을 icon.png로 바꾼 뒤 아래 주석(#)을 해제하세요.
# icon.filename = %(source.dir)s/icon.png


# ==========================================
# 🛠️ 안드로이드 빌드 에러 해결 및 필수 설정
# ==========================================

# 실시간 환율을 인터넷에서 가져와야 하므로 권한 추가
android.permissions = INTERNET

# API 버전 고정 (가장 안정적인 33 사용)
android.api = 33
android.minapi = 21

# ★ Aidl not found 에러 원인 해결: 말썽부리는 37.0.0-rc2 대신 안정판 강제 지정
android.build_tools_version = 33.0.1

# 라이선스 자동 동의 (GitHub Actions에서 멈추는 것 방지)
android.accept_sdk_license = True

# 최신 스마트폰을 위한 아키텍처 설정
android.archs = arm64-v8a, armeabi-v7a
android.allow_backup = True


[buildozer]
# 빌드 로그 출력 수준 (2로 설정하면 에러 찾기 쉬움)
log_level = 2
warn_on_root = 1
