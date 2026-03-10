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

# 1. 폰트 및 리소스 설정
def get_safe_font():
    paths = ['/system/fonts/NotoSansCJK-Regular.ttc', '/system/fonts/DroidSansFallback.ttf']
    for p in paths:
        if os.path.exists(p): return p
    return 'NanumGothic.ttf'

K_FONT = get_safe_font()
MAIN_BG, CARD_BG = (0.93, 0.94, 0.96, 1), (1, 1, 1, 1)
ACCENT_MINT, SOFT_BLUE = (0.35, 0.78, 0.7, 1), (0.4, 0.6, 0.85, 1)
OP_DARK_BLUE, NUM_LIGHT_GRAY = (0.2, 0.3, 0.4, 1), (0.92, 0.93, 0.95, 1)
TEXT_BLACK, BTN_ORANGE, MEMO_YELLOW = (0.15, 0.15, 0.18, 1), (1, 0.6, 0.3, 1), (1, 1, 0.88, 1)

# 🔥 100% 오프라인 이미지 연결
FLAG_VN, FLAG_KR = "vn.png", "kr.png"
ICON_BACK = "back.png"

Window.clearcolor = MAIN_BG

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
        self.l2.points = [self.x+p, self.top-p, self.right-p, self.top-p] # 오타수정
        self.l2.points = [self.x+p, self.top-p, self.right-p, self.y+p]

class CardInput(BoxLayout):
    def __init__(self, label_text, flag_url, **kwargs):
        super().__init__(**kwargs)
        self.orientation, self.size_hint_y, self.height = 'horizontal', None, 175 
        self.padding, self.spacing = [20, 10], 10
        with self.canvas.before:
            Color(*CARD_BG); self.rect = RoundedRectangle(pos=self.pos, size=self.size, radius=[25,])
        self.bind(pos=self.update_rect, size=self.update_rect)
        label_box = BoxLayout(orientation='vertical', size_hint_x=0.22)
        self.flag_img = Image(source=flag_url, size_hint_y=0.6)
        self.name_label = Label(text=label_text, size_hint_y=0.4, font_size=26, bold=True, color=(0.4, 0.45, 0.5, 1), font_name=K_FONT)
        label_box.add_widget(self.flag_img); label_box.add_widget(self.name_label); self.add_widget(label_box)
        input_container = RelativeLayout(size_hint_x=0.78)
        self.input = TextInput(multiline=False, background_color=(0,0,0,0), font_size=58, halign='right', padding=[10, 45, 85, 0], font_name=K_FONT, input_type='number')
        self.clear_btn = ClearXButton(pos_hint={'right': 1, 'center_y': 0.5}, opacity=0)
        self.clear_btn.bind(on_release=self.on_x_click)
        self.input.bind(text=lambda i, v: setattr(self.clear_btn, 'opacity', 1 if v else 0))
        self.input.bind(text=self.fmt_calc) # 자동 계산 연결
        input_container.add_widget(self.input); input_container.add_widget(self.clear_btn); self.add_widget(input_container)
    def on_x_click(self, inst):
        App.get_running_app().clear_all_inputs(None)
    def update_rect(self, *args):
        self.rect.pos, self.rect.size = self.pos, self.size
    def fmt_calc(self, inst, val):
        app = App.get_running_app()
        if app.is_updating or not val: return
        try:
            raw = val.replace(",", "")
            formatted = "{:,}".format(int(float(raw)))
            if val != formatted:
                app.is_updating = True; inst.text = formatted; app.is_updating = False
            app.execute_calc(formatted, self)
        except: pass

class CalculatorPopup(Popup):
    def __init__(self, main_app, target_row, **kwargs):
        super().__init__(**kwargs)
        self.main_app, self.target_row, self.title, self.title_font, self.size_hint = main_app, target_row, "환율 계산 패드", K_FONT, (1, 0.98) 
        ly = BoxLayout(orientation='vertical', padding=[25, 25], spacing=20)
        with ly.canvas.before: Color(*MAIN_BG); self.bg = RoundedRectangle()
        ly.bind(pos=lambda i,v: setattr(self.bg, 'pos', i.pos), size=lambda i,v: setattr(self.bg, 'size', i.size))
        self.disp = Label(text="", font_size=100, bold=True, color=TEXT_BLACK, halign='right', text_size=(Window.width*0.8, None), font_name=K_FONT, size_hint_y=0.25)
        ly.add_widget(self.disp)
        grid = GridLayout(cols=4, spacing=15, size_hint_y=0.6)
        # 5x4 배열 (00, 000, 0000 포함)
        btns = ['7','8','9','/','4','5','6','*','1','2','3','-','C','0','BACK','+','00','000','0000','FLAG']
        for b in btns:
            f_ly = RelativeLayout()
            if b == 'BACK':
                btn = StyledButton(bg_color=NUM_LIGHT_GRAY)
                img = Image(source=ICON_BACK, size_hint=(0.6, 0.6), pos_hint={'center_x': 0.5, 'center_y': 0.5})
                btn.bind(on_release=lambda x: self.prs('BACK'))
                f_ly.add_widget(btn); f_ly.add_widget(img); grid.add_widget(f_ly); continue
            if b == 'FLAG':
                btn = StyledButton(bg_color=(0.9, 0.94, 1, 1))
                img = Image(source=self.target_row.flag_img.source, size_hint=(0.7, 0.7), pos_hint={'center_x': 0.5, 'center_y': 0.5})
                btn.bind(on_release=lambda x: self.main_app.swap()); f_ly.add_widget(btn); f_ly.add_widget(img); grid.add_widget(f_ly); continue
            btn = StyledButton(text=b, bg_color=(1, 0.88, 0.88, 1) if b=='C' else NUM_LIGHT_GRAY if b.isdigit() or '0' in b else SOFT_BLUE)
            btn.bind(on_release=lambda x, v=b: self.prs(v)); grid.add_widget(btn)
        ly.add_widget(grid)
        apply_btn = StyledButton(text="금액 적용하기", bg_color=ACCENT_MINT, size_hint_y=0.15, f_size=55, t_color=(1,1,1,1)); apply_btn.bind(on_release=self.apply); ly.add_widget(apply_btn); self.content = ly
    def prs(self, v):
        if v == 'C': self.disp.text = ""
        elif v == 'BACK': self.disp.text = self.disp.text[:-1]
        else: self.disp.text += v
    def apply(self, inst):
        try:
            val = str(eval(self.disp.text.replace(',', '')))
            self.target_row.input.text = "{:,}".format(int(float(val)))
        except: pass
        self.dismiss()

class ExchangeRateApp(App):
    def build(self):
        self.is_swapped, self.is_updating = False, False
        root = BoxLayout(orientation='vertical', padding=[25, 25], spacing=18)
        root.add_widget(Label(text="환율 계산기", font_size=52, bold=True, size_hint_y=None, height=80, color=OP_DARK_BLUE, font_name=K_FONT))
        self.row1, self.row2 = CardInput("VND", FLAG_VN), CardInput("KRW", FLAG_KR)
        root.add_widget(self.row1); root.add_widget(self.row2)
        
        # 환율 입력 & 시간 표시 영역
        ctrl_area = BoxLayout(orientation='vertical', size_hint_y=None, height=140)
        ctrl_box = BoxLayout(size_hint_y=None, height=90, spacing=15)
        ctrl_box.add_widget(Label(text="환율", font_size=32, bold=True, size_hint_x=0.15, font_name=K_FONT, color=TEXT_BLACK))
        
        # 🔥 초기값 빈칸 설정 및 수동 입력 감지
        self.rate_in = TextInput(text="", multiline=False, font_size=42, size_hint_x=0.4, halign='center', font_name=K_FONT, background_color=(0.92, 0.93, 0.95, 1))
        self.rate_in.bind(text=self.on_manual_rate_change)
        ctrl_box.add_widget(self.rate_in)
        
        lv = StyledButton(text="실시간", bg_color=ACCENT_MINT, size_hint_x=0.25, f_size=30, t_color=(1,1,1,1))
        lv.bind(on_release=lambda x: self.get_rate()); ctrl_box.add_widget(lv)
        
        sw = StyledButton(text="위치변경", bg_color=SOFT_BLUE, size_hint_x=0.25, f_size=26, t_color=(1,1,1,1))
        sw.bind(on_release=lambda x: self.swap()); ctrl_box.add_widget(sw)
        ctrl_area.add_widget(ctrl_box)
        
        # 🔥 시간 표시 라벨 추가
        self.time_lbl = Label(text="환율을 업데이트 해주세요", font_size=24, color=(0.5, 0.5, 0.5, 1), font_name=K_FONT, size_hint_y=None, height=40)
        ctrl_area.add_widget(self.time_lbl); root.add_widget(ctrl_area)
        
        # 메모장
        mc = BoxLayout(orientation='vertical', size_hint_y=1)
        with mc.canvas.before: Color(*MEMO_YELLOW); self.m_rect = RoundedRectangle(radius=[25,])
        mc.bind(pos=lambda i,v: setattr(self.m_rect, 'pos', i.pos), size=lambda i,v: setattr(self.m_rect, 'size', i.size))
        m_head = BoxLayout(size_hint_y=None, height=70, padding=[10, 5], spacing=10)
        m_head.add_widget(Label(text="MEMO", font_name=K_FONT, color=TEXT_BLACK, size_hint_x=1, font_size=32, bold=True))
        mc.add_widget(m_head)
        self.memo_input = TextInput(text="여행 메모...", background_color=(0,0,0,0), font_name=K_FONT, font_size=35, padding=[20, 10])
        mc.add_widget(self.memo_input); root.add_widget(mc)
        
        main_calc_btn = StyledButton(text="계산기 열기", bg_color=BTN_ORANGE, size_hint_y=None, height=150, f_size=50, bold=True, radius=30, t_color=(1,1,1,1))
        main_calc_btn.bind(on_release=lambda x: CalculatorPopup(self, self.row1).open()); root.add_widget(main_calc_btn)
        return root

    # 🔥 튕김 방지: 전체 지우기 함수
    def clear_all_inputs(self, inst):
        self.is_updating = True
        self.row1.input.text = ""; self.row2.input.text = ""
        self.is_updating = False

    # 🔥 수동 입력 감지 함수
    def on_manual_rate_change(self, inst, val):
        if not self.is_updating:
            now = datetime.datetime.now().strftime("%H:%M")
            self.time_lbl.text = f"{now} 수동 입력됨"
            self.execute_calc(self.row1.input.text, self.row1)

    def swap(self):
        self.is_swapped = not self.is_swapped
        if self.is_swapped: self.row1.name_label.text, self.row1.flag_img.source, self.row2.name_label.text, self.row2.flag_img.source = "KRW", FLAG_KR, "VND", FLAG_VN
        else: self.row1.name_label.text, self.row1.flag_img.source, self.row2.name_label.text, self.row2.flag_img.source = "VND", FLAG_VN, "KRW", FLAG_KR

    def execute_calc(self, value, src):
        if self.is_updating or not value or not self.rate_in.text: return
        try:
            r, v = float(self.rate_in.text), float(value.replace(',', ''))
            is_vnd = (src.name_label.text == "VND")
            res = v / r if is_vnd else v * r
            target = self.row2 if src == self.row1 else self.row1
            self.is_updating = True; target.input.text = "{:,}".format(int(res)); self.is_updating = False
        except: pass

    def get_rate(self):
        try:
            res = requests.get("https://open.er-api.com/v6/latest/KRW", timeout=3).json()
            if res['result'] == 'success':
                self.is_updating = True
                self.rate_in.text = f"{res['rates']['VND']:.2f}"
                self.is_updating = False
                now = datetime.datetime.now().strftime("%H:%M")
                self.time_lbl.text = f"{now} 실시간 업데이트됨"
        except: self.time_lbl.text = "연결 실패 (오프라인)"

if __name__ == "__main__": ExchangeRateApp().run()
