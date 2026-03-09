[app]

title = 환율 계산기
package.name = vnc_calc
package.domain = org.test
source.dir = .
source.include_exts = py,png,jpg,kv,ttf
version = 0.1
requirements = python3,kivy,requests
icon.filename = %(source.dir)s/icon.png
orientation = portrait
android.permissions = INTERNET

android.api = 33
android.minapi = 21
android.archs = arm64-v8a
android.build_tools_version = 33.0.1
android.accept_sdk_license = True

# --- [수정됨] 이 부분의 맨 앞 '#'이 정말 중요합니다! ---
# 값을 비워두는 것이 아니라, 아예 줄 전체를 주석 처리해야 기본값을 찾아갑니다.
# p4a.branch = master
# p4a.source_dir = 
# android.sdk_path = 
# android.ndk_path = 
