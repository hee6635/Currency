[app]

# 앱 이름
title = 환율 계산기

# 패키지 이름 (영문 소문자)
package.name = vnc_calc

# 패키지 도메인
package.domain = org.test

# 소스 코드 위치
source.dir = .

# 빌드에 포함할 확장자
source.include_exts = py,png,jpg,kv,ttf

# 앱 버전
version = 0.1

# 필수 라이브러리 (requests 포함)
requirements = python3,kivy,requests

# 아이콘 파일 설정 (저장소 최상단에 icon.png가 있어야 함)
icon.filename = %(source.dir)s/icon.png

# 화면 방향 (세로 고정)
orientation = portrait

# 인터넷 권한 (환율 정보 가져오기용)
android.permissions = INTERNET

# --- 안드로이드 빌드 설정 ---

# 타겟 API 및 최소 API (안정적인 버전)
android.api = 33
android.minapi = 21

# 빌드 아키텍처
android.archs = arm64-v8a

# 빌드 툴 버전 고정
android.build_tools_version = 33.0.1

# 라이선스 자동 동의
android.accept_sdk_license = True

# 빌드 시 찌꺼기 방지를 위한 로그 레벨
log_level = 2
