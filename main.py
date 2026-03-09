import os
import datetime
import requests
from kivy.app import App
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.gridlayout import GridLayout
from kivy.uix.relativelayout import RelativeLayout
from kivy.uix.label import Label
from kivy.uix.textinput import TextInput
from kivy.uix.button import Button
from kivy.uix.popup import Popup
from kivy.uix.image import AsyncImage
from kivy.uix.widget import Widget
from kivy.core.window import Window
from kivy.graphics import Color, RoundedRectangle, Line
from kivy.clock import Clock
from kivy.uix.scrollview import ScrollView
from kivy.core.clipboard import Clipboard
import urllib3

# SSL 인증서 관련 경고 끄기
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

def get_safe_font():
    paths = ['/system/fonts/NotoSansCJK-Regular.ttc', '/system/fonts/DroidSansFallback.ttf']
    for p in paths:
        if os.path.exists(p): return p
    return None

K_FONT = get_safe_font()
MAIN_BG, CARD_BG = (0.93, 0.94, 0.96, 1), (1, 1, 1, 1)
ACCENT_MINT, SOFT_BLUE = (0.35, 0.78, 0.7, 1), (0.4, 0.6, 0.85, 1)
OP_DARK_BLUE, NUM_LIGHT_GRAY = (0.2, 0.3, 0.4, 1), (0.92, 0.93, 0.95, 1)
TEXT_BLACK, BTN_ORANGE, MEMO_YELLOW = (0.15, 0.15, 0.18, 1), (1, 0.6, 0.3, 1), (1, 1, 0.88, 1)

# 💡 [중요] 깃허브에 올리신 파일명과 대소문자까지 똑같이 맞췄습니다.
FLAG_VN, FLAG_KR = "Vietnam.png", "korea.png"
ICON_BACKSPACE = "https://img.icons8.com/material-outlined/100/333333/left.png"

Window.clearcolor = MAIN_BG

# ... (기존에 완성했던 모든 클래스와 로직 코드를 아래에 쭉 붙여넣으세요)
