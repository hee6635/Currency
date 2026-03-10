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
from kivy.graphics import Color, RoundedRectangle, Line, PushMatrix, PopMatrix, Scale
from kivy.clock import Clock
from kivy.uix.scrollview import ScrollView
from kivy.core.clipboard import Clipboard

DATA_FILE = "app_data.json"

def load_data():
    if os.path.exists(DATA_FILE):
        with open(DATA_FILE, "r", encoding="utf-8") as f: return json.load(f)
    return {"rate": "", "memo": "여행 메모  (예시) \n1만동 = 약 550원\n5만동 = 약 2,800원\n\n오늘 할일\n야시장 가기"}

def save_data(rate, memo):
    with open(DATA_FILE, "w", encoding="utf-8") as f: 
        json.dump({"rate": rate, "memo": memo}, f, ensure_ascii=False)

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

FLAG_VN, FLAG_KR = "vn.png", "kr.png"
ICON_BACKSPACE = "back.png"

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

# 🔥 QuickRatePopup 안의 화살표 텍스트를 좌우 반전된 back.png 이미지로 교체하는 부분
class FlippedBackImage(Image):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        with self.canvas.before:
            PushMatrix()
            # 원점을 이미지 중앙으로 이동 -> x축 스케일 -1 (좌우반전) -> 다시 원위치
            self.scale = Scale(-1, 1, 1)
        with self.canvas.after:
            PopMatrix()
        self.bind(pos=self.update_transform, size=self.update_transform)

    def update_transform(self, *args):
        # Scale 기준점을 위젯의 정중앙으로 설정
        self.scale.origin = self.center

class QuickRatePopup(Popup):
    def __init__(self, current_rate, **kwargs):
        super().__init__(**kwargs)
        self.current_rate = current_rate
        self.title, self.title_font, self.size_hint = "환율 퀵 환산표", K_FONT, (0.9, 0.88)
        self.separator_color, self.background = (0,0,0,0), ""
        main_layout = BoxLayout(orientation='vertical', padding=[20, 15], spacing=10)
        with main_layout.canvas.before:
            Color(*MAIN_BG); self.bg = RoundedRectangle(pos=main_layout.pos, size=main_layout.size, radius=[30,])
        main_layout.bind(pos=lambda i,v: setattr(self.bg, 'pos', i.pos), size=lambda i,v: setattr(self.bg, 'size', i.size))
        
        top_bar = RelativeLayout(size_hint_y=None, height=60)
        self.info_bar = Label(text=f"환율: {current_rate} 기준", font_name=K_FONT, font_size=28, color=(0.4, 0.45, 0.5, 1), pos_hint={'center_x': 0.5, 'center_y': 0.5})
        self.copy_btn = StyledButton(text="복사", bg_color=SOFT_BLUE, size_hint=(None, None), size=(120, 50), pos_hint={'right': 1, 'center_y': 0.5}, f_size=26, radius=12, t_color=(1,1,1,1))
        self.copy_btn.bind(on_release=self.copy_to_clipboard)
        top_bar.add_widget(self.info_bar); top_bar.add_widget(self.copy_btn); main_layout.add_widget(top_bar)
        
        scroll = ScrollView(do_scroll_x=False)
        grid = GridLayout(cols=1, size_hint_y=None, spacing=12, padding=[10, 5]) 
        grid.bind(minimum_height=grid.setter('height'))
        
        vnd_list = [1000, 5000, 10000, 20000, 30000, 50000, 100000, 200000, 300000, 500000, 1000000]
        self.calculated_data = []
        for vnd in vnd_list:
            krw = vnd / current_rate if current_rate else 0
            if vnd < 10000: krw = round(krw, -1)
            else: krw = round(krw, -2)
            self.calculated_data.append(f"{vnd:,}동 = {int(krw):,}원")
            card = BoxLayout(orientation='horizontal', size_hint_y=None, height=115, padding=[30, 0], spacing=5)
            with card.canvas.before:
                Color(*CARD_BG); card.rect = RoundedRectangle(pos=card.pos, size=card.size, radius=[20,])
                Color(0.88, 0.9, 0.93, 1); card.line = Line(rounded_rectangle=(card.x, card.y, card.width, card.height, 20), width=1)
            card.bind(pos=self._update_card, size=self._update_card)
            
            vnd_lbl = Label(text=f"{vnd:,} ₫", font_name=K_FONT, font_size=46, bold=True, color=TEXT_BLACK, halign='right', size_hint_x=0.43)
            
            # 🔥 기존 '>' 텍스트 대신 좌우 반전된 back.png 이미지 배치 (작게)
            arrow_img = FlippedBackImage(source=ICON_BACKSPACE, size_hint_x=0.14, size_hint_y=0.4, pos_hint={'center_y': 0.5}, opacity=0.6)
            
            krw_lbl = Label(text=f"약 {int(krw):,} 원", font_name=K_FONT, font_size=46, bold=True, color=TEXT_BLACK, halign='left', size_hint_x=0.43)
            
            vnd_lbl.bind(size=vnd_lbl.setter('text_size')); krw_lbl.bind(size=krw_lbl.setter('text_size'))
            card.add_widget(vnd_lbl); card.add_widget(arrow_img); card.add_widget(krw_lbl); grid.add_widget(card)
            
        scroll.add_widget(grid); main_layout.add_widget(scroll)
        close_btn = StyledButton(text="닫기", bg_color=ACCENT_MINT, size_hint_y=None, height=120, f_size=42, radius=25, t_color=(1,1,1,1))
        close_btn.bind(on_release=self.dismiss); main_layout.add_widget(close_btn); self.content = main_layout
    
    def copy_to_clipboard(self, inst):
        copy_text = f"[환율 {self.current_rate} 기준 퀵 환산표]\n" + "\n".join(self.calculated_data)
        Clipboard.copy(copy_text)
        self.copy_btn.text = "복사됨!"
        Clock.schedule_once(lambda dt: setattr(self.copy_btn, 'text', "복사"), 1.5)
    def _update_card(self, instance, value):
        instance.rect.pos = instance.pos; instance.rect.size = instance.size
        instance.line.rounded_rectangle = (instance.x, instance.y, instance.width, instance.height, 20)

class RateTextInput(TextInput):
    def insert_text(self, substring, from_undo=False):
        if substring not in "0123456789.": return
        if substring == "." and "." in self.text: return
        super().insert_text(substring, from_undo=from_undo); self.update_label_to_manual()
    def do_backspace(self, from_undo=False, mode='bkspc'):
        super().do_backspace(from_undo=from_undo, mode=mode); self.update_label_to_manual()
    def update_label_to_manual(self):
        app = App.get_running_app(); now = datetime.datetime.now().strftime("%y.%m.%d %H:%M")
        app.update_label.text = f"{now} 수동 입력"
        app.save_memo_direct()
        Clock.schedule_once(lambda dt: app.execute_calc(app.row1.input.text, app.row1.input), 0)

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

class ThemeSavePopup(Popup):
    def __init__(self, on_confirm, **kwargs):
        super().__init__(**kwargs)
        self.title, self.title_font, self.size_hint = "저장 확인", K_FONT, (0.8, 0.3)
        self.separator_color, self.background = (0,0,0,0), ""
        layout = BoxLayout(orientation='vertical', padding=30, spacing=20)
        with layout.canvas.before:
            Color(*MAIN_BG); self.bg = RoundedRectangle(pos=layout.pos, size=layout.size, radius=[25,])
        layout.bind(pos=lambda i,v: setattr(self.bg, 'pos', i.pos), size=lambda i,v: setattr(self.bg, 'size', i.size))
        layout.add_widget(Label(text="수정한 메모를 저장할까요?", font_name=K_FONT, font_size=38, color=TEXT_BLACK))
        btn_box = BoxLayout(spacing=20, size_hint_y=0.4)
        cancel_btn = StyledButton(text="취소", bg_color=NUM_LIGHT_GRAY, f_size=32)
        cancel_btn.bind(on_release=self.dismiss)
        confirm_btn = StyledButton(text="저장하기", bg_color=ACCENT_MINT, f_size=32, t_color=(1,1,1,1))
        confirm_btn.bind(on_release=lambda x: [on_confirm(), self.dismiss()])
        btn_box.add_widget(cancel_btn); btn_box.add_widget(confirm_btn); layout.add_widget(btn_box); self.content = layout

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
        self.formula = Label(text="", font_size=55, color=(0.4, 0.5, 0.5, 1), halign='right', text_size=(Window.width*0.8, None), font_name=K_FONT)
        self.display = Label(text="", font_size=100, bold=True, color=TEXT_BLACK, halign='right', text_size=(Window.width*0.8, None), font_name=K_FONT)
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
                self.pop_flag_img = Image(source=self.target_row.flag_img.source, size_hint=(0.7, 0.7), pos_hint={'center_x': 0.5, 'center_y': 0.5})
                btn.bind(on_release=self.toggle_currency)
                f_layout.add_widget(btn); f_layout.add_widget(self.pop_flag_img)
                grid.add_widget(f_layout); continue
                
            if txt == 'BACKSPACE':
                btn = StyledButton(bg_color=clr, radius=15)
                img = Image(source=ICON_BACKSPACE, size_hint=(0.6, 0.6), pos_hint={'center_x': 0.5, 'center_y': 0.5})
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
        curr_disp = self.display.text.replace(',', '')
        curr_form = self.formula.text.replace(',', '')

        if key == 'C':
            self.formula.text, self.display.text = "", ""
        elif key == 'BACK':
            if curr_disp:
                new_v = curr_disp[:-1]
                self.display.text = "{:,}".format(int(new_v)) if new_v else ""
            elif curr_form:
                parts = curr_form.strip().split(' ')
                if parts:
                    last = parts.pop()
                    if last in '+-*/' and parts:
                        self.display.text = parts.pop()
                        self.formula.text = " ".join(parts) + " " if parts else ""
                    else:
                        self.formula.text = " ".join(parts)
        elif key in '+-*/':
            if curr_disp:
                self.formula.text += "{:,}".format(int(curr_disp)) + " " + key + " "
                self.display.text = ""
            elif curr_form:
                f_strip = curr_form.strip()
                if f_strip and f_strip[-1] in '+-*/':
                    self.formula.text = f_strip[:-1] + " " + key + " "
        else:
            if "=" in self.formula.text: self.formula.text, self.display.text = "", ""
            new_v = curr_disp + key
            if new_v.isdigit(): self.display.text = "{:,}".format(int(new_v))
        
        self.apply_btn.text = "연산 결과 확인" if self.formula.text and "=" not in self.formula.text else "금액 적용하기"

    def apply(self, inst):
        if self.formula.text and "=" not in self.formula.text:
            try:
                expr = (self.formula.text + self.display.text).replace(',', ''); res = str(eval(expr)); res = res.split('.')[0] if '.' in res and res.split('.')[1] == '0' else res
                self.formula.text += self.display.text + " ="; self.display.text = "{:,}".format(int(float(res))); self.apply_btn.text = "금액 적용하기"
            except: self.display.text, self.formula.text = "Error", ""
        else:
            val = self.display.text.replace(',', '')
            if val and (val.replace('.','',1).isdigit()):
                formatted_val = "{:,}".format(int(float(val)))
                self.target_row.input.text = formatted_val; self.main_app.execute_calc(formatted_val, self.target_row.input)
            self.dismiss()

class ExchangeRateApp(App):
    def build(self):
        self.is_swapped, self.is_updating = False, False
        
        saved_data = load_data()
        self.last_saved_memo = saved_data["memo"]
        initial_rate = saved_data["rate"]
        
        root = BoxLayout(orientation='vertical', padding=[25, 25], spacing=18)
        root.add_widget(Label(text="환율 계산기", font_size=52, bold=True, size_hint_y=None, height=100, color=OP_DARK_BLUE, font_name=K_FONT))
        self.row1 = CardInput(label_text="VND", flag_url=FLAG_VN); self.row2 = CardInput(label_text="KRW", flag_url=FLAG_KR)
        root.add_widget(self.row1); root.add_widget(self.row2)
        ctrl_area = BoxLayout(orientation='vertical', size_hint_y=None, height=145)
        ctrl_box = BoxLayout(size_hint_y=None, height=100, spacing=15)
        
        self.rate_in = RateTextInput(text=initial_rate, multiline=False, font_size=45, size_hint_x=0.35, halign='center', background_normal='', background_color=(0.9, 0.92, 0.95, 1), foreground_color=TEXT_BLACK, font_name=K_FONT, input_type='text')
        
        live_btn = StyledButton(text="실시간", bg_color=ACCENT_MINT, size_hint_x=0.25, f_size=32, t_color=(1,1,1,1)); live_btn.bind(on_release=lambda x: self.get_rate())
        swap_btn = StyledButton(text="⇅ 위치 변경", bg_color=SOFT_BLUE, size_hint_x=0.25, f_size=32, t_color=(1,1,1,1)); swap_btn.bind(on_release=lambda x: self.swap())
        ctrl_box.add_widget(Label(text="환율", font_size=38, bold=True, size_hint_x=0.15, font_name=K_FONT, color=TEXT_BLACK)); ctrl_box.add_widget(self.rate_in); ctrl_box.add_widget(live_btn); ctrl_box.add_widget(swap_btn)
        date_line = BoxLayout(size_hint_y=None, height=45); date_line.add_widget(Widget(size_hint_x=0.15))
        now_time = datetime.datetime.now().strftime("%y.%m.%d %H:%M")
        
        init_label = f"{now_time} 수동 입력" if initial_rate else "환율을 업데이트 하세요"
        self.update_label = Label(text=init_label, font_size=28, color=(0.5, 0.5, 0.5, 1), font_name=K_FONT, size_hint_x=0.4, halign='center', valign='top')
        
        self.update_label.bind(size=lambda l, s: setattr(l, 'text_size', s))
        date_line.add_widget(self.update_label); date_line.add_widget(Widget(size_hint_x=0.45)); ctrl_area.add_widget(ctrl_box); ctrl_area.add_widget(date_line); root.add_widget(ctrl_area)
        memo_container = BoxLayout(orientation='vertical', size_hint_y=1, padding=[5, 5])
        with memo_container.canvas.before:
            Color(*MEMO_YELLOW); self.memo_rect = RoundedRectangle(pos=(0,0), size=(0,0), radius=[25,])
            Color(0.8, 0.78, 0.7, 0.5); self.memo_line = Line(rounded_rectangle=(0,0,0,0, 25), width=1.2)
        memo_container.bind(pos=self.update_memo_design, size=self.update_memo_design)
        memo_header = BoxLayout(orientation='horizontal', size_hint_y=None, height=85, padding=[15, 10], spacing=10)
        quick_btn = StyledButton(text="퀵 환산", bg_color=SOFT_BLUE, size_hint_x=0.25, f_size=32, radius=15, t_color=(1,1,1,1))
        quick_btn.bind(on_release=lambda x: QuickRatePopup(current_rate=float(self.rate_in.text if self.rate_in.text else 1)).open())
        memo_header.add_widget(quick_btn); memo_header.add_widget(Label(text="MEMO", font_size=38, bold=True, color=OP_DARK_BLUE, font_name=K_FONT, halign='center', size_hint_x=0.5))
        save_btn = StyledButton(text="저장", bg_color=ACCENT_MINT, size_hint_x=0.25, f_size=32, radius=15, t_color=(1,1,1,1)); save_btn.bind(on_release=lambda x: ThemeSavePopup(on_confirm=self.save_memo_direct).open())
        memo_header.add_widget(save_btn); memo_container.add_widget(memo_header)
        
        self.memo_input = TextInput(text=self.last_saved_memo, font_size=40, background_color=(0,0,0,0), foreground_color=TEXT_BLACK, padding=[30, 15], font_name=K_FONT, multiline=True, line_height=1.2, cursor_color=ACCENT_MINT)
        memo_container.add_widget(self.memo_input); root.add_widget(memo_container)
        main_calc_btn = StyledButton(text="계산기 열기", bg_color=BTN_ORANGE, size_hint_y=None, height=180, f_size=55, bold=True, radius=40, t_color=(1,1,1,1)); main_calc_btn.bind(on_release=lambda x: CalculatorPopup(self, self.row1).open())
        root.add_widget(main_calc_btn); return root
    
    def clear_all_inputs(self, inst): 
        try:
            self.is_updating = True
            self.row1.input.text = ""; self.row2.input.text = ""
        finally: self.is_updating = False

    def execute_calc(self, value, source_input):
        if self.is_updating or not value or value == ".": return
        try:
            r_text = self.rate_in.text
            if not r_text or r_text == ".": return
            r, v = float(r_text), float(value.replace(',', ''))
            is_row1 = (source_input == self.row1.input)
            res = (v / r if not self.is_swapped else v * r) if is_row1 else (v * r if not self.is_swapped else v / r)
            target_input = self.row2.input if is_row1 else self.row1.input
            self.is_updating = True; target_input.text = f"{int(res):,}"; self.is_updating = False
        except: self.is_updating = False
        
    def on_start(self): 
        pass 
        
    def update_memo_design(self, instance, value):
        self.memo_rect.pos, self.memo_rect.size = instance.pos, instance.size; self.memo_line.rounded_rectangle = (instance.x, instance.y, instance.width, instance.height, 25)
        
    def save_memo_direct(self): 
        self.last_saved_memo = self.memo_input.text
        save_data(self.rate_in.text, self.last_saved_memo)
        
    def swap(self):
        self.is_updating = True; v1, v2 = self.row1.input.text, self.row2.input.text; self.is_swapped = not self.is_swapped
        if self.is_swapped: self.row1.name_label.text, self.row1.flag_img.source, self.row2.name_label.text, self.row2.flag_img.source = "KRW", FLAG_KR, "VND", FLAG_VN
        else: self.row1.name_label.text, self.row1.flag_img.source, self.row2.name_label.text, self.row2.flag_img.source = "VND", FLAG_VN, "KRW", FLAG_KR
        self.row1.input.text, self.row2.input.text = v2, v1; self.is_updating = False
        
    def get_rate(self):
        try:
            data = requests.get("https://open.er-api.com/v6/latest/KRW", timeout=5).json()
            if data['result'] == 'success':
                self.rate_in.text = f"{data['rates']['VND']:.2f}"; now = datetime.datetime.now().strftime("%y.%m.%d %H:%M")
                self.update_label.text = f"{now} 기준"
                self.save_memo_direct()
                self.execute_calc(self.row1.input.text, self.row1.input) if self.row1.input.text else None
        except: pass

if __name__ == "__main__":
    ExchangeRateApp().run()
