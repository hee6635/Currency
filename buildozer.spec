[app]
title = 환율 계산기
package.name = vn_krw_calc
package.domain = org.test
source.dir = .
source.include_exts = py,png,ttf,json
version = 0.1

# 준비하신 파일 이름과 정확히 일치해야 합니다.
icon.filename = icon.png
source.include_patterns = assets/*,*.png,*.ttf

requirements = python3,kivy,requests,urllib3,certifi,chardet,idna

orientation = portrait
fullscreen = 0
android.archs = arm64-v8a, armeabi-v7a
android.allow_backup = True
