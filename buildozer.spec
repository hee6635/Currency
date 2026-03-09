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

android.accept_sdk_license = True

log_level = 2
