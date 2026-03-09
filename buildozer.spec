[app]
title = 환율 계산기
package.name = vnc_calc
package.domain = org.test
source.dir = .
source.include_exts = py,png,jpg,kv,ttf
version = 0.1

# [중요] pyjnius와 hostpython3를 명시적으로 추가했습니다.
requirements = python3,kivy,requests,pyjnius,hostpython3

icon.filename = %(source.dir)s/icon.png
orientation = portrait
android.permissions = INTERNET

android.api = 33
android.minapi = 21
android.archs = arm64-v8a
android.build_tools_version = 33.0.1
android.accept_sdk_license = True
log_level = 2
