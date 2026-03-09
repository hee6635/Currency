[app]

title = Vietnam Currency
package.name = vnc_calc
package.domain = org.test

source.dir = .
source.include_exts = py,png,jpg,kv,ttf

version = 0.1

requirements = python3,kivy,requests

orientation = portrait

android.permissions = INTERNET

[android]

android.api = 31
android.minapi = 21
android.archs = arm64-v8a

android.build_tools_version = 33.0.1
android.accept_sdk_license = True
