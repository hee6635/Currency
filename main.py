import os
import datetime
import requests
import json
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

# 리소스 설정 (보내주신 이미지와 폰트 파일명 적용)
K_FONT = 'NanumGothic.ttf'
FLAG_VN = "Vietnam.png"
FLAG_KR = "korea.png"
ICON_BACKSPACE = "https://img.icons8.com/material-outlined/100/333333/left.png"

# 테마 컬러
MAIN_BG, CARD_BG = (0.93, 0.94, 0.96, 1), (1, 1, 1, 1)
ACCENT_MINT, SOFT_BLUE = (0.35, 0.78, 0.7, 1), (0.4, 0.6, 0.85, 1)
OP_DARK_BLUE, NUM_LIGHT_GRAY = (0.2, 0.3, 0.4, 1), (0.92, 0.93, 0.95, 1)
TEXT_BLACK, BTN_ORANGE, MEMO_YELLOW = (0.15, 0.15, 0.18, 1), (1, 0.6, 0.3, 1), (1, 1, 0.88, 1)

Window.clearcolor = MAIN_BG

# [데이터 저장 및 로드 로직]
DATA_FILE = "app_data.json"

def save_data(rate, memo):
    with open(DATA_FILE, "w", encoding="utf-8") as f:
        json.dump({"rate": rate, "memo": memo}, f, ensure_ascii=False)

def load_data():
    if os.path.exists(DATA_FILE):
        with open(DATA_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    return {"rate": "", "memo": "여기에 메모를 작성하세요."}

# (기존 StyledButton, ClearXButton, CardInput 등 클래스는 유지...)
# 공간 관계상 핵심 수정 부분인 App 클래스와 커스텀 입력을 중점적으로 보여드릴게요.

class StyledButton(Button):
    def __init__(self, bg_color=(1, 1, 1, 1), radius=20, f_size=45, t_color=TEXT_BLACK, **kwargs):
        super().__init__(**kwargs)
        self.background_normal = self.background_down = ''
        self.background_color = (0,0,0,0)
        self.original_color = bg_color
        self.pressed_color = [max(0, c - 0.1) for c in bg_color[:3]] + [1]
        self.font_size, self.color = f_size, t_color
        self.font_name, self.radius = K_FONT, [radius,]
        with self.canvas.before:
            self.shadow_color_obj = Color(0, 0, 0, 0.1)
            self.rect_shad = RoundedRectangle(pos=(self.pos[0], self.pos[1]-5), size=self.size, radius=self.radius)
            self.btn_color_obj = Color(*self.original_color)
            self.rect = RoundedRectangle(pos=self.pos, size=self.size, radius=self.radius)
        self.bind(pos=self.update_rect, size=self.update_rect)
    def on_press(self):
        self.rect.pos = (self.pos[0], self.pos[1]-5)
        self.shadow_color_obj.a = 0
        self.btn_color_obj.rgb = self.pressed_color[:3]
    def on_release(self):
        self.rect.pos = self.pos
        self.shadow_color_obj.a = 0.1
        self.btn_color_obj.rgb = self.original_color[:3]
    def update_rect(self, *args):
        self.rect_shad.pos = (self.pos[0], self.pos[1]-5); self.rect_shad.size = self.size
        self.rect.pos = self.pos; self.rect.size = self.size

class RateTextInput(TextInput):
    def insert_text(self, substring, from_undo=False):
        if substring not in "0123456789.": return
        super().insert_text(substring, from_undo=from_undo)
        App.get_running_app().update_label.text = "수동 입력됨"
    def on_text_validate(self): # 엔터 치면 저장
        App.get_running_app().save_all_to_file()

class CommaTextInput(TextInput):
    def format_and_calc(self):
        app = App.get_running_app()
        if not self.text or app.is_updating: return
        raw = self.text.replace(",", "")
        try:
            formatted = "{:,}".format(int(float(raw)))
            if self.text != formatted:
                app.is_updating = True; self.text = formatted; app.is_updating = False
            app.execute_calc(formatted, self)
        except: pass

class CardInput(BoxLayout):
    def __init__(self, label_text, flag_url, **kwargs):
        super().__init__(**kwargs)
        self.orientation, self.size_hint_y, self.height = 'horizontal', None, 175 
        self.padding, self.spacing = [20, 10], 10
        with self.canvas.before:
            Color(*CARD_BG); self.rect = RoundedRectangle(pos=self.pos, size=self.size, radius=[25,])
            Color(0.85, 0.88, 0.9, 0.5); self.line = Line(rounded_rectangle=(0,0,0,0, 25), width=1.1)
        self.bind(pos=self.update_rect, size=self.update_rect)
        label_box = BoxLayout(orientation='vertical', size_hint_x=0.22)
        self.flag_img = AsyncImage(source=flag_url, size_hint_y=0.6)
        self.name_label = Label(text=label_text, size_hint_y=0.4, font_size=26, bold=True, color=(0.4, 0.45, 0.5, 1), font_name=K_FONT)
        label_box.add_widget(self.flag_img); label_box.add_widget(self.name_label); self.add_widget(label_box)
        input_container = RelativeLayout(size_hint_x=0.78)
        self.input = CommaTextInput(multiline=False, background_color=(0,0,0,0), foreground_color=TEXT_BLACK, font_size=58, halign='right', padding=[10, 45, 85, 0], font_name=K_FONT, input_type='number', cursor_color=ACCENT_MINT)
        input_container.add_widget(self.input); self.add_widget(input_container)
    def update_rect(self, *args):
        self.rect.pos, self.rect.size = self.pos, self.size
        self.line.rounded_rectangle = (self.x, self.y, self.width, self.height, 25)

class ExchangeRateApp(App):
    def build(self):
        self.is_swapped, self.is_updating = False, False
        data = load_data() # 파일에서 데이터 불러오기
        
        root = BoxLayout(orientation='vertical', padding=[25, 25], spacing=18)
        root.add_widget(Label(text="동환율 계산기", font_size=52, bold=True, size_hint_y=None, height=100, color=OP_DARK_BLUE, font_name=K_FONT))
        
        self.row1 = CardInput(label_text="VND", flag_url=FLAG_VN)
        self.row2 = CardInput(label_text="KRW", flag_url=FLAG_KR)
        root.add_widget(self.row1); root.add_widget(self.row2)

        # 환율 컨트롤 영역
        ctrl_box = BoxLayout(size_hint_y=None, height=100, spacing=15)
        self.rate_in = RateTextInput(text=data['rate'], multiline=False, font_size=45, size_hint_x=0.35, halign='center', background_color=(0.9, 0.92, 0.95, 1), font_name=K_FONT)
        live_btn = StyledButton(text="실시간", bg_color=ACCENT_MINT, size_hint_x=0.25, f_size=32, t_color=(1,1,1,1))
        live_btn.bind(on_release=lambda x: self.get_rate())
        
        ctrl_box.add_widget(Label(text="환율", font_size=38, bold=True, size_hint_x=0.15, font_name=K_FONT, color=TEXT_BLACK))
        ctrl_box.add_widget(self.rate_in); ctrl_box.add_widget(live_btn)
        root.add_widget(ctrl_box)

        self.update_label = Label(text="데이터 로드됨", font_size=28, color=(0.5, 0.5, 0.5, 1), font_name=K_FONT, size_hint_y=None, height=40)
        root.add_widget(self.update_label)

        # 메모 영역
        memo_container = BoxLayout(orientation='vertical', size_hint_y=1)
        with memo_container.canvas.before:
            Color(*MEMO_YELLOW); self.memo_rect = RoundedRectangle(radius=[25,])
        memo_container.bind(pos=self._update_memo_bg, size=self._update_memo_bg)
        
        save_btn = StyledButton(text="메모 저장", bg_color=ACCENT_MINT, size_hint_y=None, height=70, f_size=30, t_color=(1,1,1,1))
        save_btn.bind(on_release=lambda x: self.save_all_to_file())
        
        self.memo_input = TextInput(text=data['memo'], font_size=35, background_color=(0,0,0,0), font_name=K_FONT, multiline=True)
        memo_container.add_widget(self.memo_input); memo_container.add_widget(save_btn)
        root.add_widget(memo_container)

        return root

    def _update_memo_bg(self, instance, value):
        self.memo_rect.pos = instance.pos; self.memo_rect.size = instance.size

    def save_all_to_file(self):
        save_data(self.rate_in.text, self.memo_input.text)
        self.update_label.text = f"저장 완료: {datetime.datetime.now().strftime('%H:%M:%S')}"

    def get_rate(self):
        try:
            # KRW 대비 VND 환율 가져오기
            res = requests.get("https://open.er-api.com/v6/latest/KRW", timeout=5).json()
            if res['result'] == 'success':
                new_rate = f"{res['rates']['VND']:.2f}"
                self.rate_in.text = new_rate
                self.update_label.text = "실시간 환율 업데이트됨"
                self.save_all_to_file() # 업데이트 시 자동 저장
        except:
            self.update_label.text = "환율 불러오기 실패"

    def execute_calc(self, value, source_input):
        if not self.rate_in.text or self.is_updating: return
        try:
            r = float(self.rate_in.text)
            v = float(value.replace(',', ''))
            is_row1 = (source_input == self.row1.input)
            res = v / r if is_row1 else v * r
            target = self.row2.input if is_row1 else self.row1.input
            self.is_updating = True
            target.text = f"{int(res):,}"
            self.is_updating = False
        except: pass

if __name__ == "__main__":
    ExchangeRateApp().run()
