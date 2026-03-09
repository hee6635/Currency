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

# SSL 인증서 관련 경고 끄기 (쿼리 실패 방지)
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

def get_safe_font():
    # 안드로이드 시스템 폰트 경로
    paths = ['/system/fonts/NotoSansCJK-Regular.ttc', '/system/fonts/DroidSansFallback.ttf']
    for p in paths:
        if os.path.exists(p): return p
    return None

K_FONT = get_safe_font()
MAIN_BG, CARD_BG = (0.93, 0.94, 0.96, 1), (1, 1, 1, 1)
ACCENT_MINT, SOFT_BLUE = (0.35, 0.78, 0.7, 1), (0.4, 0.6, 0.85, 1)
OP_DARK_BLUE, NUM_LIGHT_GRAY = (0.2, 0.3, 0.4, 1), (0.92, 0.93, 0.95, 1)
TEXT_BLACK, BTN_ORANGE, MEMO_YELLOW = (0.15, 0.15, 0.18, 1), (1, 0.6, 0.3, 1), (1, 1, 0.88, 1)

# 💡 [중요] 저장소에 올린 구슬 국기 파일명과 대소문자까지 똑같이 맞춤
FLAG_VN, FLAG_KR = "Vietnam.png", "korea.png"
ICON_BACKSPACE = "https://img.icons8.com/material-outlined/100/333333/left.png"

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
        self.l2.points = [self.x+p, self.top-p, self.right-p, self.y+p]

class CommaTextInput(TextInput):
    def insert_text(self, substring, from_undo=False):
        if substring not in "0123456789.": return
        super().insert_text(substring, from_undo=from_undo); self.format_and_calc()
    def do_backspace(self, from_undo=False, mode='bkspc'):
        super().do_backspace(from_undo=from_undo, mode=mode); self.format_and_calc()
    def format_and_calc(self):
        app = App.get_running_app()
        if not self.text or app.is_updating: return
        raw = self.text.replace(",", "")
        try:
            formatted = "{:,}".format(int(float(raw)))
            if self.text != formatted:
                cur = self.cursor; app.is_updating = True; self.text = formatted; self.cursor = cur; app.is_updating = False
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
        self.clear_btn = ClearXButton(pos_hint={'right': 1, 'center_y': 0.5}, opacity=0)
        self.clear_btn.bind(on_release=self.on_x_click)
        self.input.bind(text=lambda i, v: setattr(self.clear_btn, 'opacity', 1 if v else 0))
        input_container.add_widget(self.input); input_container.add_widget(self.clear_btn); self.add_widget(input_container)
    def on_x_click(self, inst):
        self.input.text = ""; App.get_running_app().clear_all_inputs(None)
    def update_rect(self, *args):
        self.rect.pos, self.rect.size = self.pos, self.size
        self.line.rounded_rectangle = (self.x, self.y, self.width, self.height, 25)

class CalculatorPopup(Popup):
    def __init__(self, main_app, target_row, **kwargs):
        super().__init__(**kwargs)
        self.main_app, self.target_row, self.title, self.title_font, self.size_hint = main_app, target_row, "환율 계산 패드", K_FONT, (1, 0.98) 
        self.title_color, self.background = TEXT_BLACK, ""
        main_layout = BoxLayout(orientation='vertical', padding=[25, 25], spacing=20)
        with main_layout.canvas.before:
            Color(*MAIN_BG); self.bg_rect = RoundedRectangle(pos=main_layout.pos, size=main_layout.size)
        main_layout.bind(pos=self.update_bg, size=self.update_bg)
        display_box = BoxLayout(orientation='vertical', size_hint_y=0.25, padding=[25, 15])
        with display_box.canvas.before:
            Color(1, 1, 1, 1); self.disp_rect = RoundedRectangle(pos=display_box.pos, size=display_box.size, radius=[20,])
            Color(0.35, 0.78, 0.7, 0.2); self.disp_line = Line(rounded_rectangle=(0,0,0,0,20), width=1.5)
        display_box.bind(pos=self.update_disp_rect, size=self.update_disp_rect)
        self.formula = Label(text="", font_size=55, color=(0.4, 0.5, 0.5, 1), halign='right', font_name=K_FONT)
        self.display = Label(text="", font_size=100, bold=True, color=TEXT_BLACK, halign='right', font_name=K_FONT)
        display_box.add_widget(self.formula); display_box.add_widget(self.display); main_layout.add_widget(display_box)
        
        grid = GridLayout(cols=4, spacing=15, size_hint_y=0.62)
        btns = [
            ['7', NUM_LIGHT_GRAY], ['8', NUM_LIGHT_GRAY], ['9', NUM_LIGHT_GRAY], ['/', SOFT_BLUE],
            ['4', NUM_LIGHT_GRAY], ['5', NUM_LIGHT_GRAY], ['6', NUM_LIGHT_GRAY], ['*', SOFT_BLUE],
            ['1', NUM_LIGHT_GRAY], ['2', NUM_LIGHT_GRAY], ['3', NUM_LIGHT_GRAY], ['-', SOFT_BLUE],
            ['C', (1, 0.88, 0.88, 1)], ['0', NUM_LIGHT_GRAY], ['BACKSPACE', NUM_LIGHT_GRAY], ['+', SOFT_BLUE],
            ['00', NUM_LIGHT_GRAY], ['000', NUM_LIGHT_GRAY], ['0000', NUM_LIGHT_GRAY], ['FLAG', (0.9, 0.94, 1, 1)]
        ]
        
        for txt, clr in btns:
            f_layout = RelativeLayout()
            if txt == 'FLAG':
                btn = StyledButton(bg_color=clr, radius=15)
                self.pop_flag_img = AsyncImage(source=self.target_row.flag_img.source, size_hint=(0.7, 0.7), pos_hint={'center_x': 0.5, 'center_y': 0.5})
                btn.bind(on_release=self.toggle_currency)
                f_layout.add_widget(btn); f_layout.add_widget(self.pop_flag_img)
                grid.add_widget(f_layout); continue
            if txt == 'BACKSPACE':
                btn = StyledButton(bg_color=clr, radius=15)
                img = AsyncImage(source=ICON_BACKSPACE, size_hint=(0.6, 0.6), pos_hint={'center_x': 0.5, 'center_y': 0.5})
                btn.bind(on_release=lambda x: self.on_key_press('BACK'))
                f_layout.add_widget(btn); f_layout.add_widget(img)
                grid.add_widget(f_layout); continue
            t_color = OP_DARK_BLUE if txt in '/+*-' else TEXT_BLACK
            btn = StyledButton(text=txt, bg_color=clr, radius=15, f_size=80 if len(txt)<2 else 50, t_color=t_color)
            btn.bind(on_release=lambda x, t=txt: self.on_key_press(t))
            grid.add_widget(btn)
        main_layout.add_widget(grid)
        self.apply_btn = StyledButton(text="금액 적용하기", bg_color=ACCENT_MINT, size_hint_y=0.14, f_size=55, radius=20, t_color=(1,1,1,1))
        self.apply_btn.bind(on_release=self.apply)
        main_layout.add_widget(self.apply_btn); self.content = main_layout
        
    def update_bg(self, instance, value): self.bg_rect.pos, self.bg_rect.size = instance.pos, instance.size
    def update_disp_rect(self, instance, value): self.disp_rect.pos, self.disp_rect.size = instance.pos, instance.size; self.disp_line.rounded_rectangle = (instance.x, instance.y, instance.width, instance.height, 20)
    def toggle_currency(self, inst): self.main_app.swap(); self.target_row = self.main_app.row1; self.pop_flag_img.source = self.target_row.flag_img.source
    def on_key_press(self, key):
        # (계산기 입력 로직 생략되지 않도록 전체 포함)
        curr_disp = self.display.text.replace(',', '')
        if key == 'C': self.formula.text, self.display.text = "", ""
        elif key == 'BACK':
            if curr_disp:
                new_v = curr_disp[:-1]
                self.display.text = "{:,}".format(int(new_v)) if new_v else ""
        elif key in '+-*/':
            if curr_disp:
                self.formula.text += "{:,}".format(int(curr_disp)) + " " + key + " "
                self.display.text = ""
        else:
            new_v = curr_disp + key
            if new_v.isdigit(): self.display.text = "{:,}".format(int(new_v))
    def apply(self, inst):
        val = self.display.text.replace(',', '')
        if val: self.target_row.input.text = "{:,}".format(int(float(val))); self.main_app.execute_calc(self.target_row.input.text, self.target_row.input)
        self.dismiss()

class ExchangeRateApp(App):
    def build(self):
        self.is_swapped, self.is_updating = False, False
        root = BoxLayout(orientation='vertical', padding=[25, 25], spacing=18)
        root.add_widget(Label(text="환율 계산기", font_size=52, bold=True, size_hint_y=None, height=100, color=OP_DARK_BLUE, font_name=K_FONT))
        self.row1 = CardInput(label_text="VND", flag_url=FLAG_VN); self.row2 = CardInput(label_text="KRW", flag_url=FLAG_KR)
        root.add_widget(self.row1); root.add_widget(self.row2)
        
        # 환율 설정 바
        rate_box = BoxLayout(size_hint_y=None, height=100, spacing=15)
        self.rate_in = TextInput(text="17.65", multiline=False, font_size=45, size_hint_x=0.4, halign='center', font_name=K_FONT)
        live_btn = StyledButton(text="실시간", bg_color=ACCENT_MINT, size_hint_x=0.3, f_size=32, t_color=(1,1,1,1)); live_btn.bind(on_release=lambda x: self.get_rate())
        rate_box.add_widget(Label(text="환율", font_size=38, bold=True, size_hint_x=0.2, font_name=K_FONT, color=TEXT_BLACK)); rate_box.add_widget(self.rate_in); rate_box.add_widget(live_btn)
        root.add_widget(rate_box)
        
        self.update_label = Label(text="환율 업데이트 중...", font_size=28, color=(0.5, 0.5, 0.5, 1), font_name=K_FONT, size_hint_y=None, height=40)
        root.add_widget(self.update_label)

        main_calc_btn = StyledButton(text="계산기 열기", bg_color=BTN_ORANGE, size_hint_y=None, height=180, f_size=55, bold=True, radius=40, t_color=(1,1,1,1))
        main_calc_btn.bind(on_release=lambda x: CalculatorPopup(self, self.row1).open())
        root.add_widget(main_calc_btn); return root

    def clear_all_inputs(self, inst): self.is_updating = True; self.row1.input.text = ""; self.row2.input.text = ""; self.is_updating = False
    def execute_calc(self, value, source_input):
        if self.is_updating or not value: return
        try:
            r, v = float(self.rate_in.text), float(value.replace(',', ''))
            res = v / r if source_input == self.row1.input else v * r
            self.is_updating = True; (self.row2.input if source_input == self.row1.input else self.row1.input).text = f"{int(res):,}"; self.is_updating = False
        except: self.is_updating = False
    def swap(self):
        self.is_swapped = not self.is_swapped
        if self.is_swapped: self.row1.name_label.text, self.row1.flag_img.source, self.row2.name_label.text, self.row2.flag_img.source = "KRW", FLAG_KR, "VND", FLAG_VN
        else: self.row1.name_label.text, self.row1.flag_img.source, self.row2.name_label.text, self.row2.flag_img.source = "VND", FLAG_VN, "KRW", FLAG_KR
    def get_rate(self):
        try:
            response = requests.get("https://open.er-api.com/v6/latest/KRW", timeout=5, verify=False)
            data = response.json()
            if data['result'] == 'success':
                self.rate_in.text = f"{data['rates']['VND']:.2f}"
                self.update_label.text = f"{datetime.datetime.now().strftime('%y.%m.%d %H:%M')} 기준"
        except: self.update_label.text = "오프라인/환율 확인 실패"
    def on_start(self): Clock.schedule_once(lambda dt: self.get_rate(), 0.5)

if __name__ == "__main__":
    ExchangeRateApp().run()
