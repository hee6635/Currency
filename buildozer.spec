[app]

# 앱 이름
title = 환율 계산기

# 패키지 이름
package.name = vnc_calc

# 패키지 도메인
package.domain = org.test

# 소스 코드 위치 (현재 디렉토리)
source.dir = .

# 빌드에 포함할 확장자 목록
source.include_exts = py,png,jpg,kv,ttf

# 앱 버전
version = 0.1

# 패키지 요구사항
requirements = python3,kivy,requests

# 방금 올려주신 멋진 아이콘 파일 적용
icon.filename = %(source.dir)s/icon.png

# 화면 방향 설정 (세로 고정)
orientation = portrait

# 안드로이드 권한 설정 (인터넷 사용)
android.permissions = INTERNET

# 안드로이드 타겟 API 버전 (안정적인 33으로 고정)
android.api = 33

# 안드로이드 최소 API 지원 버전
android.minapi = 21

# 안드로이드 아키텍처 (64비트)
android.archs = arm64-v8a

# 빌드 툴 버전 고정 (라이선스 에러 방지)
android.build_tools_version = 33.0.1

# 안드로이드 SDK 라이선스 자동 동의
android.accept_sdk_license = True
