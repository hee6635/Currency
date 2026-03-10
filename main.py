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
from kivy.uix.image import Image
from kivy.uix.widget import Widget
from kivy.core.window import Window
from kivy.graphics import Color, RoundedRectangle, Line
from kivy.clock import Clock
from kivy.uix.scrollview import ScrollView
from kivy.core.clipboard import Clipboard

# 1. 환경 설정 및 리소스 (준비하신 로컬 파일 적용)
K_FONT = 'NanumGothic.ttf'
FLAG_VN = "vn.png"
FLAG_KR = "kr.png"
ICON_BACKSPACE = "back.png"

# 테마 컬러
MAIN_BG, CARD_BG = (0.93, 0.94, 0.96, 1), (1, 1, 1, 1)
ACCENT_MINT, SOFT_BLUE = (0.35, 0.78, 0.7, 1), (0.4, 0.6, 0.85, 1)
OP_DARK_BLUE, NUM_LIGHT_GRAY = (0.2, 0.3, 0.4, 1), (0.92, 0.93, 0.95, 1)
TEXT_BLACK, BTN_ORANGE, MEMO_YELLOW = (0.15, 0.15, 0.18, 1), (1, 0.6, 0.3, 1), (1, 1, 0.88, 1)

Window.clearcolor = MAIN_BG

# [데이터 관리] 저장 및 불러오기
DATA_FILE = "app_data.json"

def save_app_data(rate, memo):
    try:
        with open(DATA_FILE, "w", encoding="utf-8") as f:
            json.dump({"rate": rate, "memo": memo}, f, ensure_ascii=False)
    except: pass

def load_app_data():
    if os.path.exists(DATA_FILE):
        try:
            with open(DATA_FILE, "r", encoding="utf-8") as f:
                return json.load(f)
        except: pass
    return {"rate": "", "memo": "여기에 메모를 작성하세요.\n(예: 1만동 = 550원)"}

# --- UI 컴포넌트 클래스 ---

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

class ClearXButton(Button):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.size_hint, self.size = (None, None), (70, 70)
        self.background_normal = ''; self.background_color = (0,0,0,0)
        with self.canvas.after:
            Color(0.6, 0.6, 0.6, 1)
            self.l1, self.l2 = Line(width=1.8), Line(width=1.8)
        self.bind(pos=self.update_canvas, size=self.update_canvas)

    def update_canvas(self, *args):
        p = 22
        self.l1.points = [self.x+p, self.y+p, self.right-p, self.top-p]
        self.l2.points = [self.x+p, self.top-p, self.right-p, self.y+p]

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
        self.flag_img = Image(source=flag_url, size_hint_y=0.6)
        self.name_label = Label(text=label_text, size_hint_y=0.4, font_size=26, bold=True, color=(0.4, 0.45, 0.5, 1), font_name=K_FONT)
        label_box.add_widget(self.flag_img); label_box.add_widget(self.name_label); self.add_widget(label_box)
        
        input_container = RelativeLayout(size_hint_x=0.78)
        self.input = TextInput(multiline=False, background_color=(0,0,0,0), foreground_color=TEXT_BLACK, font_size=58, halign='right', padding=[10, 45, 85, 0], font_name=K_FONT, input_type='number', cursor_color=ACCENT_MINT)
        self.clear_btn = ClearXButton(pos_hint={'right': 1, 'center_y': 0.5}, opacity=0)
        self.clear_btn.bind(on_release=self.on_x_click)
        self.input.bind(text=self.on_text_change)
        input_container.add_widget(self.input); input_container.add_widget(self.clear_btn); self.add_widget(input_container)

    def on_x_click(self, inst):
        self.input.text = ""

    def on_text_change(self, instance, value):
        app = App.get_running_app()
        self.clear_btn.opacity = 1 if value else 0
        if app.is_updating or not value: return
        raw = value.replace(",", "")
        try:
            formatted = "{:,}".format(int(float(raw)))
            if value != formatted:
                app.is_updating = True; instance.text = formatted; app.is_updating = False
            app.execute_calc(formatted, instance)
        except: pass

    def update_rect(self, *args):
        self.rect.pos, self.rect.size = self.pos, self.size
        self.line.rounded_rectangle = (self.x, self.y, self.width, self.height, 25)

# --- 팝업 클래스 (퀵 환산 & 계산기) ---

class QuickRatePopup(Popup):
    def __init__(self, current_rate, **kwargs):
        super().__init__(**kwargs)
        self.title, self.size_hint = "환율 퀵 환산표", (0.9, 0.8)
        self.title_font = K_FONT
        main_layout = BoxLayout(orientation='vertical', padding=20, spacing=10)
        with main_layout.canvas.before:
            Color(*MAIN_BG); self.bg = RoundedRectangle()
        main_layout.bind(pos=lambda i,v: setattr(self.bg, 'pos', i.pos), size=lambda i,v: setattr(self.bg, 'size', i.size))
        
        scroll = ScrollView(); grid = GridLayout(cols=1, size_hint_y=None, spacing=10)
        grid.bind(minimum_height=grid.setter('height'))
        
        vnd_list = [1000, 5000, 10000, 50000, 100000, 200000, 500000]
        for vnd in vnd_list:
            krw = int(vnd / current_rate) if current_rate > 0 else 0
            lbl = Label(text=f"{vnd:,}동 ➔ {krw:,}원", font_name=K_FONT, font_size=40, color=TEXT_BLACK, size_hint_y=None, height=100)
            grid.add_widget(lbl)
        
        scroll.add_widget(grid); main_layout.add_widget(scroll)
        close_btn = StyledButton(text="닫기", bg_color=ACCENT_MINT, size_hint_y=0.2, t_color=(1,1,1,1))
        close_btn.bind(on_release=self.dismiss)
        main_layout.add_widget(close_btn); self.content = main_layout

class CalculatorPopup(Popup):
    def __init__(self, main_app, target_row, **kwargs):
        super().__init__(**kwargs)
        self.main_app, self.target_row, self.title, self.size_hint = main_app, target_row, "계산 패드", (1, 0.95)
        self.title_font = K_FONT
        main_layout = BoxLayout(orientation='vertical', padding=25, spacing=15)
        with main_layout.canvas.before:
            Color(*MAIN_BG); self.bg = RoundedRectangle()
        main_layout.bind(pos=lambda i,v: setattr(self.bg, 'pos', i.pos), size=lambda i,v: setattr(self.bg, 'size', i.size))
        
        self.display = Label(text="", font_size=100, bold=True, color=TEXT_BLACK, halign='right', text_size=(Window.width*0.8, None), font_name=K_FONT, size_hint_y=0.2)
        main_layout.add_widget(self.display)
        
        grid = GridLayout(cols=4, spacing=12, size_hint_y=0.65)
        btns = ['7','8','9','/','4','5','6','*','1','2','3','-','C','0','BACK','+']
        for b in btns:
            if b == 'BACK':
                btn = StyledButton(bg_color=NUM_LIGHT_GRAY)
                btn.add_widget(Image(source=ICON_BACKSPACE, center=btn.center, size=(80,80)))
                btn.bind(on_release=lambda x: self.press('B'))
            else:
                btn = StyledButton(text=b, bg_color=SOFT_BLUE if b in '/*-+' else NUM_LIGHT_GRAY, f_size=60)
                btn.bind(on_release=lambda x, val=b: self.press(val))
            grid.add_widget(btn)
        main_layout.add_widget(grid)
        
        apply_btn = StyledButton(text="계산 결과 입력하기", bg_color=ACCENT_MINT, size_hint_y=0.15, t_color=(1,1,1,1), f_size=40)
        apply_btn.bind(on_release=self.apply_res)
        main_layout.add_widget(apply_btn); self.content = main_layout

    def press(self, val):
        if val == 'C': self.display.text = ""
        elif val == 'B': self.display.text = self.display.text[:-1]
        else: self.display.text += val

    def apply_res(self, inst):
        try:
            res = str(eval(self.display.text))
            self.target_row.input.text = "{:,}".format(int(float(res)))
        except: pass
        self.dismiss()

# --- 메인 앱 클래스 ---

class ExchangeRateApp(App):
    def build(self):
        self.is_updating = False
        data = load_app_data()
        
        root = BoxLayout(orientation='vertical', padding=[25, 20], spacing=15)
        root.add_widget(Label(text="베트남 환율 계산기", font_size=55, bold=True, color=OP_DARK_BLUE, font_name=K_FONT, size_hint_y=None, height=100))
        
        self.row1 = CardInput("VND", FLAG_VN); self.row2 = CardInput("KRW", FLAG_KR)
        root.add_widget(self.row1); root.add_widget(self.row2)
        
        # 환율 설정
        rate_box = BoxLayout(size_hint_y=None, height=110, spacing=15)
        self.rate_in = TextInput(text=data['rate'], multiline=False, font_size=45, halign='center', font_name=K_FONT, background_color=(0.9, 0.92, 0.95, 1), padding=[0, 25])
        live_btn = StyledButton(text="실시간", bg_color=ACCENT_MINT, size_hint_x=0.3, f_size=32, t_color=(1,1,1,1))
        live_btn.bind(on_release=lambda x: self.get_rate())
        
        rate_box.add_widget(Label(text="환율", color=TEXT_BLACK, font_name=K_FONT, size_hint_x=0.15, font_size=35, bold=True))
        rate_box.add_widget(self.rate_in); rate_box.add_widget(live_btn)
        root.add_widget(rate_box)
        
        # 메모 및 퀵 환산
        memo_container = BoxLayout(orientation='vertical', size_hint_y=1)
        with memo_container.canvas.before:
            Color(*MEMO_YELLOW); self.m_rect = RoundedRectangle(radius=[25,])
        memo_container.bind(pos=lambda i,v: setattr(self.m_rect, 'pos', i.pos), size=lambda i,v: setattr(self.m_rect, 'size', i.size))
        
        header = BoxLayout(size_hint_y=None, height=70, padding=[10, 5])
        header.add_widget(Label(text="여행 메모", font_name=K_FONT, color=OP_DARK_BLUE, bold=True, size_hint_x=0.7))
        quick_btn = StyledButton(text="퀵 환산", bg_color=SOFT_BLUE, size_hint_x=0.3, f_size=28, t_color=(1,1,1,1), radius=15)
        quick_btn.bind(on_release=lambda x: QuickRatePopup(float(self.rate_in.text or 1)).open())
        header.add_widget(quick_btn); memo_container.add_widget(header)
        
        self.memo_input = TextInput(text=data['memo'], background_color=(0,0,0,0), font_name=K_FONT, font_size=35, padding=[20, 10])
        memo_container.add_widget(self.memo_input)
        
        save_btn = StyledButton(text="현재 환율 & 메모 저장하기", bg_color=SOFT_BLUE, size_hint_y=None, height=80, f_size=30, t_color=(1,1,1,1), radius=0)
        save_btn.bind(on_release=lambda x: self.save_all())
        memo_container.add_widget(save_btn); root.add_widget(memo_container)
        
        # 메인 계산기 버튼
        main_calc_btn = StyledButton(text="계산기 열기", bg_color=BTN_ORANGE, size_hint_y=None, height=150, t_color=(1,1,1,1), f_size=50, bold=True, radius=30)
        main_calc_btn.bind(on_release=lambda x: CalculatorPopup(self, self.row1).open())
        root.add_widget(main_calc_btn)
        
        return root

    def get_rate(self):
        try:
            res = requests.get("https://open.er-api.com/v6/latest/KRW", timeout=5).json()
            if res['result'] == 'success':
                self.rate_in.text = f"{res['rates']['VND']:.2f}"
                self.save_all()
        except: pass

    def execute_calc(self, value, source):
        if not self.rate_in.text or self.is_updating: return
        try:
            r, v = float(self.rate_in.text), float(value.replace(',', ''))
            is_vnd = (source == self.row1.input)
            res = v / r if is_vnd else v * r
            target = self.row2.input if is_vnd else self.row1.input
            self.is_updating = True
            target.text = "{:,}".format(int(res))
            self.is_updating = False
        except: pass

    def save_all(self):
        save_app_data(self.rate_in.text, self.memo_input.text)

if __name__ == "__main__":
    ExchangeRateApp().run()
