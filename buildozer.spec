[app]
# (str) Title of your application
title = 베트남 환율

# (str) Package name
package.name = vn_krw_calc

# (str) Package domain (needed for android packaging)
package.domain = org.myapp

# (str) Source code where the main.py live
source.dir = .

# (list) Source files to include (let empty to include all the files)
source.include_exts = py,png,ttf,json,ttc

# (str) Application versioning (method 1)
version = 0.1

# (str) Icon of the application
icon.filename = icon.png

# (str) Presplash of the application
presplash.filename = presplash_keyring.png

# (str) Presplash background color
android.presplash_color = #F4F4F4

# (list) Application requirements
requirements = python3,kivy==2.3.0,requests,certifi,openssl

# (str) Supported orientation (one of landscape, sensorLandscape, portrait or all)
orientation = portrait

# (list) Permissions
android.permissions = INTERNET

# (int) Target Android API, should be as high as possible.
android.api = 33

# (int) Minimum API your APK will support.
android.minapi = 21

# (int) Android SDK directory (if empty, it will be automatically downloaded.)
# android.sdk =

# (int) Android NDK directory (if empty, it will be automatically downloaded.)
# android.ndk =

# (int) Android NDK API to use. Is this the minimum API your app will support?
android.ndk_api = 21

# (bool) use posix to build (will use the host architecture)
# android.use_posix = 1

# (list) The Android archs to build for, choices: armeabi-v7a, arm64-v8a, x86, x86_64
android.archs = arm64-v8a

# (bool) Allow backup
android.allow_backup = True

# (str) Android logcat filters to use
android.logcat_filters = *:S python:D

# (str) Android additional libraries to copy to libs/armeabi
# android.add_libs_armeabi = lib/armeabi/*.so

# (str) Android manifest attributes
android.manifest.attributes = android:windowSoftInputMode="adjustResize"

# (bool) Fullscreen mode
fullscreen = 0

# (list) Android additional Java classes to add to the manifest.
# android.add_src =

# (list) Android service definitions
# services =

# (bool) Copy library instead of making a libpysdl.so
# android.copy_libs = 1

# (list) The Android SDK license to accept
android.accept_sdk_license = True


[buildozer]
# (int) Log level (0 = error only, 1 = info, 2 = debug (with command output))
log_level = 2

# (int) Display warning if buildozer is run as root (0 = no, 1 = yes)
warn_on_root = 1
