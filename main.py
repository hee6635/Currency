import os
import time
import datetime
import requests
import json
from kivy.app import App
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.gridlayout import GridLayout
from kivy.uix.relativelayout import RelativeLayout
from kivy.uix.label import Label
from kivy.uix.textinput import TextInput
from kivy.uix.popup import Popup
from kivy.uix.modalview import ModalView
from kivy.uix.image import Image
from kivy.uix.widget import Widget
from kivy.uix.behaviors import ButtonBehavior
from kivy.core.window import Window
from kivy.graphics import Color, RoundedRectangle, Line, PushMatrix, PopMatrix, Ellipse, Rectangle 
from kivy.clock import Clock
from kivy.uix.scrollview import ScrollView
from kivy.core.clipboard import Clipboard
from kivy.properties import BooleanProperty
from kivy.animation import Animation

try:
    from android.runnable import run_on_ui_thread
    from jnius import autoclass
    PythonActivity = autoclass('org.kivy.android.PythonActivity')
    ANDROID = True
except:
    ANDROID = False

Window.softinput_mode = 'resize'

DATA_FILE = "app_data.json"
ICON_SET = "set.png"      
IMAGE_HERB = "herb.png"    
FLAG_VN = "vn.png"        
FLAG_KR = "kr.png"        
ICON_BACKSPACE = "back.png"  
ICON_CLEAR = "x.png"       

def load_data():
    default_data = {
        "rate": "", 
        "memo": "※ 최신 복사 내용만 붙여넣기 지원\n\n여행 메모  (예시)\n1만동 = 약 550원\n5만동 = 약 2,800원\n\n오늘 할일\n야시장 가기",
        "settings": {"auto_update": True, "auto_zeros": False, "round_krw": False, "auto_font": False, "auto_save": False, "theme": 1}
    }
    if os.path.exists(DATA_FILE):
        try:
            with open(DATA_FILE, "r", encoding="utf-8") as f: 
                data = json.load(f)
                if "settings" not in data: data["settings"] = default_data["settings"]
                else:
                    for k in ["round_krw", "auto_font", "auto_save", "theme"]:
                        if k not in data["settings"]: data["settings"][k] = default_data["settings"][k]
                return data
        except: pass
    return default_data

def save_data(data_dict):
    with open(DATA_FILE, "w", encoding="utf-8") as f: json.dump(data_dict, f, ensure_ascii=False)

def get_safe_font():
    paths = ['/system/fonts/NotoSansCJK-Regular.ttc', '/system/fonts/DroidSansFallback.ttf']
    for p in paths:
        if os.path.exists(p): return p
    return 'NanumGothic.ttf'

K_FONT = get_safe_font()
MAIN_BG, CARD_BG = (0.93, 0.94, 0.96, 1), (1, 1, 1, 1)
TEXT_BLACK = (0.15, 0.15, 0.18, 1)
NUM_LIGHT_GRAY = (0.92, 0.93, 0.95, 1)
MUTED_COLOR = (0.5, 0.5, 0.5, 1)

Window.clearcolor = MAIN_BG

class UnderlineLayout(RelativeLayout):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        with self.canvas.after:
            Color(0.92, 0.92, 0.94, 1)
            self.line = Line(points=[0, 0, self.width, 0], width=1)
        self.bind(size=self.update_line)
    def update_line(self, *args):
        self.line.points = [0, 0, self.width, 0]

class StyledButton(ButtonBehavior, Label):
    def __init__(self, bg_color=(1, 1, 1, 1), radius=20, f_size=45, t_color=TEXT_BLACK, **kwargs):
        super().__init__(**kwargs)
        self.original_color = bg_color
        self.font_size, self.color, self.font_name, self.radius = f_size, t_color, K_FONT, [radius,]
        self.light_color = [min(1, c + 0.15) for c in bg_color[:3]] + [1]
        self.dark_color = [max(0, c - 0.15) for c in bg_color[:3]] + [1]
        with self.canvas.before:
            self.shadow_dark = Color(*self.dark_color); self.rect_dark = RoundedRectangle(pos=self.pos, size=self.size, radius=self.radius)
            self.shadow_light = Color(*self.light_color); self.rect_light = RoundedRectangle(pos=self.pos, size=self.size, radius=self.radius)
            self.btn_color_obj = Color(*self.original_color); self.rect = RoundedRectangle(pos=self.pos, size=self.size, radius=self.radius)
        self.bind(pos=self.update_rect, size=self.update_rect)
        
    def update_color(self, new_bg_color):
        self.original_color = new_bg_color
        self.light_color = [min(1, c + 0.15) for c in new_bg_color[:3]] + [1]
        self.dark_color = [max(0, c - 0.15) for c in new_bg_color[:3]] + [1]
        self.shadow_dark.rgba = self.dark_color
        self.shadow_light.rgba = self.light_color
        self.btn_color_obj.rgba = new_bg_color

    def on_press(self):
        self.rect.pos = (self.pos[0] + 3, self.pos[1] - 3); self.shadow_light.a = 0; self.shadow_dark.a = 0
    def on_release(self):
        self.rect.pos = self.pos; self.shadow_light.a = 1; self.shadow_dark.a = 1
    def update_rect(self, *args):
        self.rect_dark.pos = (self.pos[0] + 4, self.pos[1] - 4); self.rect_dark.size = self.size
        self.rect_light.pos = (self.pos[0] - 4, self.pos[1] + 4); self.rect_light.size = self.size
        self.rect.pos = self.pos; self.rect.size = self.size

class ImageButton(ButtonBehavior, Image):
    def on_press(self): self.color = (0.5, 0.5, 0.5, 1)
    def on_release(self): self.color = (0.6, 0.6, 0.6, 1)

class TextButton(ButtonBehavior, Label):
    def on_press(self): self.opacity = 0.5
    def on_release(self): self.opacity = 1.0

class ThemePillSwitch(ButtonBehavior, Widget):
    def __init__(self, main_app, **kwargs):
        super().__init__(**kwargs)
        self.main_app = main_app
        self.theme_id = main_app.settings.get("theme", 1)
        self.size_hint = (None, None); self.size = (160, 52)
        with self.canvas.before:
            self.track_color = Color(0.85, 0.85, 0.85, 1)
            self.track_rect = RoundedRectangle(pos=self.pos, size=self.size, radius=[26])
            self.thumb_color = Color(*self.get_theme_color(self.theme_id))
            self.thumb_circle = Ellipse(size=(42, 42))
        self.bind(pos=self.update_ui, size=self.update_ui)
        Clock.schedule_once(self.update_ui, 0)

    def get_theme_color(self, t_id):
        if t_id == 1: return (0.15, 0.45, 0.85, 1) 
        elif t_id == 2: return (1.0, 0.6, 0.3, 1)  
        else: return (0.25, 0.25, 0.25, 1)         

    def update_ui(self, *args):
        self.track_rect.pos = self.pos; self.track_rect.size = self.size; self.track_rect.radius = [self.height/2]
        gap = (self.width - 42 - 10) / 2
        target_x = self.x + 5 + (self.theme_id - 1) * gap
        self.thumb_circle.pos = (target_x, self.y + 5)
        self.thumb_color.rgba = self.get_theme_color(self.theme_id)

    def on_release(self):
        self.theme_id += 1
        if self.theme_id > 3: self.theme_id = 1
        gap = (self.width - 42 - 10) / 2
        target_x = self.x + 5 + (self.theme_id - 1) * gap
        Animation(pos=(target_x, self.y + 5), t='out_quad', duration=0.2).start(self.thumb_circle)
        Animation(rgba=self.get_theme_color(self.theme_id), t='out_quad', duration=0.2).start(self.thumb_color)
        self.main_app.apply_theme_ui(self.theme_id)

class PillSwitch(ButtonBehavior, Widget):
    active = BooleanProperty(False)
    def __init__(self, active_color, active=False, **kwargs):
        super().__init__(**kwargs)
        self.active_color = active_color
        self.active = active
        self.size_hint = (None, None); self.size = (100, 52)
        with self.canvas.before:
            self.track_color = Color(0.85, 0.85, 0.85, 1) if not self.active else Color(*self.active_color)
            self.track_rect = RoundedRectangle(pos=self.pos, size=self.size, radius=[self.height/2])
            Color(1, 1, 1, 1); self.thumb_circle = Ellipse(size=(42, 42))
        self.bind(pos=self.update_ui, size=self.update_ui, active=self.animate_switch)
        Clock.schedule_once(self.update_ui, 0)
    def update_ui(self, *args):
        self.track_rect.pos = self.pos; self.track_rect.size = self.size; self.track_rect.radius = [self.height/2]
        if self.active: self.thumb_circle.pos = (self.right - 42 - 5, self.y + 5); self.track_color.rgba = self.active_color
        else: self.thumb_circle.pos = (self.x + 5, self.y + 5); self.track_color.rgba = (0.85, 0.85, 0.85, 1)
    def animate_switch(self, instance, value):
        target_x = self.right - 42 - 5 if value else self.x + 5
        target_color = self.active_color if value else (0.85, 0.85, 0.85, 1)
        Animation(pos=(target_x, self.y + 5), t='out_quad', duration=0.2).start(self.thumb_circle)
        Animation(rgba=target_color, t='out_quad', duration=0.2).start(self.track_color)
    def on_release(self): self.active = not self.active

class CommaTextInput(TextInput):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.k_mode = False
    def insert_text(self, substring, from_undo=False):
        if substring not in "0123456789.": return
        if self.k_mode and self.text.endswith('K') and self.cursor[0] == len(self.text): self.cursor = (len(self.text) - 1, 0)
        super().insert_text(substring, from_undo=from_undo); self.format_and_calc()
    def do_backspace(self, from_undo=False, mode='bkspc'):
        if self.k_mode and self.text.endswith('K') and self.cursor[0] == len(self.text): self.cursor = (len(self.text) - 1, 0)
        super().do_backspace(from_undo=from_undo, mode=mode); self.format_and_calc()
    def format_and_calc(self):
        app = App.get_running_app()
        if app.is_updating: return
        raw = self.text.replace(",", "").replace("K", "")
        target_font = 58
        if app.settings.get("auto_font", False):
            if len(raw) > 11: target_font = 40
            elif len(raw) > 8: target_font = 48
        self.font_size = target_font 
        if not raw: 
            app.is_updating = True; self.text = ""; app.is_updating = False
            app.execute_calc("", self); return
        try:
            formatted = "{:,}".format(int(float(raw)))
            if self.k_mode: formatted += "K" 
            if self.text != formatted:
                app.is_updating = True; self.text = formatted; app.is_updating = False
                if self.k_mode: self.cursor = (max(0, len(self.text) - 1), 0)
                else: self.cursor = (len(self.text), 0)
            app.execute_calc(raw, self)
        except: pass

# ✅ 붙여넣기 버그 수정 - 버스트 감지 후 클립보드 원본으로 직접 교체
class AutoPasteMemoInput(TextInput):
    def insert_text(self, substring, from_undo=False):
        app = App.get_running_app()
        if app.programmatic_insert:
            return super().insert_text(substring, from_undo=from_undo)
        now = time.time()
        if now - app.last_replace_time < app.replace_cooldown:
            return super().insert_text(substring, from_undo=from_undo)
        if now - app.last_input_time > app.burst_window:
            app.burst_count = 0
            app.burst_newlines = 0
            app.burst_started = False
        if not app.burst_started:
            app.before_text = self.text
            app.before_cursor = self.cursor_index()
            app.burst_started = True
        app.last_input_time = now
        app.burst_count += 1
        if substring == "\n":
            app.burst_newlines += 1
        is_paste_like = (
            
            len(substring) >= 5
        )
        if is_paste_like:
            Clock.unschedule(app.replace_with_clipboard)
            Clock.schedule_once(app.replace_with_clipboard, 0.08)
            return
        return super().insert_text(substring, from_undo=from_undo)

class CardInput(BoxLayout):
    def __init__(self, label_text, flag_url, cursor_c, **kwargs):
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
        self.input = CommaTextInput(hint_text="", multiline=False, background_color=(0,0,0,0), foreground_color=TEXT_BLACK, font_size=58, halign='right', padding=[10, 45, 85, 0], font_name=K_FONT, input_type='number', cursor_color=cursor_c)
        self.clear_btn = ImageButton(source=ICON_CLEAR, pos_hint={'right': 0.98, 'center_y': 0.5}, size_hint=(None, None), size=(60, 60), opacity=0, color=(0.6, 0.6, 0.6, 1))
        self.clear_btn.bind(on_release=lambda x: [setattr(self.input, 'text', ""), App.get_running_app().clear_all_inputs(None)])
        self.input.bind(text=lambda i, v: setattr(self.clear_btn, 'opacity', 1 if v else 0))
        input_container.add_widget(self.input); input_container.add_widget(self.clear_btn); self.add_widget(input_container)
    
    def set_auto_zero_mode(self, is_active):
        is_vnd = FLAG_VN in self.flag_img.source
        if is_vnd:
            self.input.k_mode = is_active
            self.input.hint_text, self.name_label.text = ("000 생략", "VND (K)") if is_active else ("", "VND")
        else: 
            self.input.k_mode = False
            self.name_label.text = "KRW"
            self.input.hint_text = ""  
        if self.input.text: self.input.format_and_calc()
        
    def update_rect(self, *args):
        self.rect.pos, self.rect.size = self.pos, self.size
        self.line.rounded_rectangle = (self.x, self.y, self.width, self.height, 25)

class RateTextInput(TextInput):
    def insert_text(self, substring, from_undo=False):
        if substring not in "0123456789.": return
        if substring == "." and "." in self.text: return
        super().insert_text(substring, from_undo=from_undo); self.update_label_to_manual()
    def do_backspace(self, from_undo=False, mode='bkspc'):
        super().do_backspace(from_undo=from_undo, mode=mode); self.update_label_to_manual()
    def update_label_to_manual(self):
        app = App.get_running_app()
        app.update_label.text = f"{datetime.datetime.now().strftime('%y.%m.%d %H:%M')} 수동 입력"
        app.update_rate_desc()
        app.save_rate_and_settings()
        Clock.schedule_once(lambda dt: app.execute_calc(app.row1.input.text, app.row1.input), 0)

class SettingsPopup(ModalView):
    def __init__(self, main_app, **kwargs):
        super().__init__(**kwargs)
        self.main_app = main_app
        self.size_hint = (1, 1) 
        self.background = ""; self.background_color = (1, 1, 1, 1) 
        self.original_theme = self.main_app.settings.get("theme", 1)
        self.is_saved = False
        self.bind(on_dismiss=self.on_cancel)
        main_layout = BoxLayout(orientation='vertical')
        header = RelativeLayout(size_hint_y=None, height=130)
        with header.canvas.before: Color(1,1,1,1); Rectangle(pos=(0,0), size=Window.size)
        title = Label(text="설정", font_size=42, bold=True, color=TEXT_BLACK, font_name=K_FONT, pos_hint={'center_x': 0.5, 'center_y': 0.5})
        self.settings_save_btn = StyledButton(
            text="저장", f_size=34, radius=18,
            bg_color=self.main_app.c_main, t_color=(1,1,1,1),
            size_hint=(None, None), size=(130, 80),
            pos_hint={'right': 0.97, 'center_y': 0.5},
            font_name=K_FONT, bold=True
        )
        self.settings_save_btn.bind(on_release=self.save_and_close)
        header.add_widget(title); header.add_widget(self.settings_save_btn); main_layout.add_widget(header)
        with main_layout.canvas.after: Color(0.9, 0.9, 0.9, 1); Line(points=[0, Window.height-130, Window.width, Window.height-130], width=1)
        scroll = ScrollView(do_scroll_x=False, do_scroll_y=False) 
        list_grid = GridLayout(cols=1, size_hint_y=None, spacing=10)
        list_grid.bind(minimum_height=list_grid.setter('height'))
        theme_row = UnderlineLayout(size_hint_y=None, height=140)
        theme_lbl = Label(text="앱 테마 변경\n(블루/기본/다크)", font_name=K_FONT, font_size=32, color=TEXT_BLACK, size_hint=(0.6, 1), pos_hint={'x': 0.02, 'center_y': 0.5}, halign='left', valign='middle')
        theme_lbl.bind(size=theme_lbl.setter('text_size'))
        self.theme_sw = ThemePillSwitch(main_app=self.main_app, pos_hint={'right': 0.98, 'center_y': 0.5})
        theme_row.add_widget(theme_lbl); theme_row.add_widget(self.theme_sw); list_grid.add_widget(theme_row)
        s_list = [
            ("auto_update", "시작 시 환율 자동 업데이트"),
            ("auto_zeros", "VND 입력 시 000 생략 (K)"),
            ("round_krw", "KRW 100원 단위 반올림"),
            ("auto_font", "금액 길이에 맞춰 폰트 자동 조절"),
            ("auto_save", "메모 자동 저장 (버튼 불필요)")
        ]
        for k, t in s_list:
            row = UnderlineLayout(size_hint_y=None, height=120)
            lbl = Label(text=t, font_name=K_FONT, font_size=34, color=TEXT_BLACK, size_hint=(0.7, 1), pos_hint={'x': 0.02, 'center_y': 0.5}, halign='left', valign='middle')
            lbl.bind(size=lbl.setter('text_size'))
            sw = PillSwitch(active_color=self.main_app.c_main, active=bool(self.main_app.settings.get(k, False)), pos_hint={'right': 0.98, 'center_y': 0.5})
            setattr(self, f"sw_{k}", sw)
            row.add_widget(lbl); row.add_widget(sw); list_grid.add_widget(row)
        list_grid.add_widget(Widget(size_hint_y=None, height=Window.height*0.3))
        scroll.add_widget(list_grid); main_layout.add_widget(scroll)
        self.add_widget(main_layout)
        
    def save_and_close(self, inst):
        self.is_saved = True
        for k in ["auto_update", "auto_zeros", "round_krw", "auto_font", "auto_save"]:
            self.main_app.settings[k] = getattr(self, f"sw_{k}").active
        self.main_app.change_theme(self.theme_sw.theme_id) 
        self.main_app.update_ui_for_settings()
        if self.main_app.row1.input.text: self.main_app.row1.input.format_and_calc()
        if self.main_app.row2.input.text: self.main_app.row2.input.format_and_calc()
        self.dismiss()

    def on_cancel(self, inst):
        if not self.is_saved:
            if self.theme_sw.theme_id != self.original_theme:
                self.main_app.apply_theme_ui(self.original_theme)

class QuickRatePopup(ModalView):
    def __init__(self, current_rate, **kwargs):
        super().__init__(**kwargs)
        self.current_rate = current_rate
        app = App.get_running_app()
        self.size_hint = (1, 1) 
        self.background = ""; self.background_color = (1, 1, 1, 1) 
        main_layout = BoxLayout(orientation='vertical')
        header = RelativeLayout(size_hint_y=None, height=130)
        with header.canvas.before: Color(1,1,1,1); Rectangle(pos=(0,0), size=Window.size)
        x_btn = ImageButton(source=ICON_CLEAR, size_hint=(None, None), size=(60, 60), pos_hint={'x': 0.05, 'center_y': 0.5})
        x_btn.bind(on_release=lambda x: self.dismiss())
        title = Label(text="퀵 환산표", font_size=42, bold=True, color=TEXT_BLACK, font_name=K_FONT, pos_hint={'center_x': 0.5, 'center_y': 0.5})
        self.copy_btn = TextButton(text="복사", font_size=34, color=app.c_main, bold=True, size_hint=(None, None), size=(120, 100), pos_hint={'right': 0.98, 'center_y': 0.5}, font_name=K_FONT)
        self.copy_btn.bind(on_release=self.copy_to_clipboard)
        header.add_widget(x_btn); header.add_widget(title); header.add_widget(self.copy_btn); main_layout.add_widget(header)
        with main_layout.canvas.after: Color(0.9, 0.9, 0.9, 1); Line(points=[0, Window.height-130, Window.width, Window.height-130], width=1)
        info = Label(text=f"현재 환율: {current_rate} 기준", font_size=32, color=MUTED_COLOR, font_name=K_FONT, size_hint_y=None, height=80)
        main_layout.add_widget(info)
        scroll = ScrollView(do_scroll_x=False, do_scroll_y=False) 
        grid = GridLayout(cols=1, size_hint_y=None, spacing=0) 
        grid.bind(minimum_height=grid.setter('height'))
        vnd_list = [1000, 5000, 10000, 20000, 30000, 50000, 100000, 200000, 300000, 500000, 1000000]
        self.calculated_data = []
        for vnd in vnd_list:
            krw = vnd / current_rate if current_rate else 0
            if vnd < 10000: krw = int((krw + 5) // 10) * 10
            else: krw = int((krw + 50) // 100) * 100
            self.calculated_data.append(f"{vnd:,}동 = {int(krw):,}원")
            row = UnderlineLayout(size_hint_y=None, height=130)
            box = BoxLayout(orientation='horizontal', size_hint=(1, 1), spacing=5, padding=[10, 0])
            vnd_lbl = Label(text=f"{vnd:,} ₫", font_name=K_FONT, font_size=46, bold=True, color=TEXT_BLACK, size_hint_x=0.40, halign='right', valign='middle')
            vnd_lbl.bind(size=vnd_lbl.setter('text_size'))
            arrow_lbl = Label(text="→", font_name=K_FONT, font_size=55, color=MUTED_COLOR, size_hint_x=0.20, halign='center', valign='middle')
            arrow_lbl.bind(size=arrow_lbl.setter('text_size'))
            krw_lbl = Label(text=f"{int(krw):,} 원", font_name=K_FONT, font_size=44, color=app.c_text, size_hint_x=0.40, halign='left', valign='middle')
            krw_lbl.bind(size=krw_lbl.setter('text_size'))
            box.add_widget(vnd_lbl); box.add_widget(arrow_lbl); box.add_widget(krw_lbl)
            row.add_widget(box); grid.add_widget(row)
        grid.add_widget(Widget(size_hint_y=None, height=47))
        scroll.add_widget(grid); main_layout.add_widget(scroll)
        self.add_widget(main_layout)

    def copy_to_clipboard(self, inst):
        lines = [f"[환율 {self.current_rate} 기준 퀵 환산표]"] + self.calculated_data
        copy_text = "\n".join(lines).strip()
        Clipboard.copy(copy_text)
        self.copy_btn.text = "완료"
        Clock.schedule_once(lambda dt: setattr(self.copy_btn, 'text', "복사"), 1.5)

class ThemeSavePopup(ModalView):
    def __init__(self, on_confirm, on_select_all, **kwargs):
        super().__init__(**kwargs)
        self.size_hint = (0.85, None); self.height = 300; self.background = ""; self.background_color = (0,0,0, 0.4) 
        main_layout = RelativeLayout()
        with main_layout.canvas.before: 
            Color(1, 1, 1, 1); self.bg_rect = RoundedRectangle(pos=(0,0), size=self.size, radius=[35])
            Color(0.85, 0.85, 0.85, 1); self.h_line = Line(points=[0, 110, self.width, 110], width=1)
            self.v_line1 = Line(points=[self.width/3, 0, self.width/3, 110], width=1)
            self.v_line2 = Line(points=[2*self.width/3, 0, 2*self.width/3, 110], width=1)
        main_layout.bind(size=self.update_graphics)
        box = BoxLayout(orientation='vertical')
        lbl_box = RelativeLayout(size_hint_y=None, height=190)
        lbl = Label(text="메모 관리", font_name=K_FONT, font_size=38, bold=True, color=TEXT_BLACK, pos_hint={'center_x': 0.5, 'center_y': 0.5})
        lbl_box.add_widget(lbl)
        box.add_widget(lbl_box)
        btn_box = BoxLayout(size_hint_y=None, height=110)
        c_btn = TextButton(text="취소", font_size=32, color=MUTED_COLOR, font_name=K_FONT)
        c_btn.bind(on_release=lambda x: self.dismiss())
        sel_btn = TextButton(text="전체선택", font_size=32, color=(0.3, 0.3, 0.3, 1), font_name=K_FONT)
        def do_select_all(x):
            self.dismiss()
            def _focus_and_select(dt):
                memo = App.get_running_app().memo_input
                memo.focus = True
                Clock.schedule_once(lambda dt2: on_select_all(), 0.1)
            Clock.schedule_once(_focus_and_select, 0.2)
        sel_btn.bind(on_release=do_select_all)
        s_btn = TextButton(text="저장", font_size=32, bold=True, color=(0, 0, 0, 1), font_name=K_FONT)
        s_btn.bind(on_release=lambda x: [on_confirm(), self.dismiss()])
        btn_box.add_widget(c_btn); btn_box.add_widget(sel_btn); btn_box.add_widget(s_btn)
        box.add_widget(btn_box)
        main_layout.add_widget(box)
        self.add_widget(main_layout)

    def update_graphics(self, instance, value): 
        self.bg_rect.size = instance.size
        self.h_line.points = [0, 110, instance.width, 110]
        self.v_line1.points = [instance.width/3, 0, instance.width/3, 110]
        self.v_line2.points = [2*instance.width/3, 0, 2*instance.width/3, 110]

class HerbPopup(ModalView):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)
        self.size_hint = (1, 1); self.background = ""; self.background_color = (0,0,0, 0.7) 
        main_layout = RelativeLayout()
        img = Image(source=IMAGE_HERB, size_hint=(0.9, 0.9), pos_hint={'center_x': 0.5, 'center_y': 0.5})
        main_layout.add_widget(img)
        self.add_widget(main_layout)
    def on_touch_down(self, touch):
        self.dismiss(); return True

class CalculatorPopup(ModalView):
    def __init__(self, main_app, target_row, **kwargs):
        super().__init__(**kwargs)
        self.main_app, self.target_row = main_app, target_row
        self.size_hint = (1, 1)
        self.background = ""
        main_layout = BoxLayout(orientation='vertical', padding=[25, 25], spacing=20)
        with main_layout.canvas.before: Color(*MAIN_BG); self.bg_rect = RoundedRectangle(pos=main_layout.pos, size=main_layout.size)
        main_layout.bind(pos=self.update_bg, size=self.update_bg)
        display_box = BoxLayout(orientation='vertical', size_hint_y=0.25, padding=[25, 15])
        with display_box.canvas.before: 
            Color(1, 1, 1, 1); self.disp_rect = RoundedRectangle(pos=display_box.pos, size=display_box.size, radius=[20,])
            self.disp_line_color = Color(*self.main_app.c_main[:3], 0.2)
            self.disp_line = Line(rounded_rectangle=(0,0,0,0,20), width=1.5)
        display_box.bind(pos=self.update_disp_rect, size=self.update_disp_rect)
        self.formula = Label(text="", font_size=55, color=MUTED_COLOR, halign='right', text_size=(Window.width*0.8, None), font_name=K_FONT)
        self.display = Label(text="", font_size=100, bold=True, color=TEXT_BLACK, halign='right', text_size=(Window.width*0.8, None), font_name=K_FONT)
        display_box.add_widget(self.formula); display_box.add_widget(self.display); main_layout.add_widget(display_box)
        grid = GridLayout(cols=4, spacing=25, size_hint_y=0.62)
        c_sub = self.main_app.c_sub
        btns = [['7', NUM_LIGHT_GRAY], ['8', NUM_LIGHT_GRAY], ['9', NUM_LIGHT_GRAY], ['/', c_sub], ['4', NUM_LIGHT_GRAY], ['5', NUM_LIGHT_GRAY], ['6', NUM_LIGHT_GRAY], ['*', c_sub], ['1', NUM_LIGHT_GRAY], ['2', NUM_LIGHT_GRAY], ['3', NUM_LIGHT_GRAY], ['-', c_sub], ['C', (1, 0.88, 0.88, 1)], ['0', NUM_LIGHT_GRAY], ['BACKSPACE', NUM_LIGHT_GRAY], ['+', c_sub], ['00', NUM_LIGHT_GRAY], ['000', NUM_LIGHT_GRAY], ['0000', NUM_LIGHT_GRAY], ['FLAG', (0.9, 0.94, 1, 1)]]
        for txt, clr in btns:
            f_layout = RelativeLayout()
            if txt == 'FLAG':
                btn = StyledButton(bg_color=clr, radius=15); self.pop_flag_img = Image(source=self.target_row.flag_img.source, size_hint=(0.7, 0.7), pos_hint={'center_x': 0.5, 'center_y': 0.5}); btn.bind(on_release=self.toggle_currency); f_layout.add_widget(btn); f_layout.add_widget(self.pop_flag_img); grid.add_widget(f_layout); continue
            if txt == 'BACKSPACE':
                btn = StyledButton(bg_color=clr, radius=15); img = Image(source=ICON_BACKSPACE, size_hint=(0.6, 0.6), pos_hint={'center_x': 0.5, 'center_y': 0.5}); btn.bind(on_release=lambda x: self.on_key_press('BACK')); f_layout.add_widget(btn); f_layout.add_widget(img); grid.add_widget(f_layout); continue
            t_color = self.main_app.c_text if txt in '/+*-' else TEXT_BLACK
            btn = StyledButton(text=txt, bg_color=clr, radius=15, f_size=80 if len(txt)<2 else 50, t_color=t_color); btn.bind(on_release=lambda x, t=txt: self.on_key_press(t)); grid.add_widget(btn)
        main_layout.add_widget(grid)
        self.apply_btn = StyledButton(text="금액 적용하기", bg_color=self.main_app.c_main, size_hint_y=0.14, f_size=55, radius=20, t_color=(1,1,1,1))
        self.apply_btn.bind(on_release=self.apply)
        main_layout.add_widget(self.apply_btn)
        self.add_widget(main_layout)

    def update_bg(self, instance, value): self.bg_rect.pos, self.bg_rect.size = instance.pos, instance.size
    def update_disp_rect(self, instance, value): self.disp_rect.pos, self.disp_rect.size = instance.pos, instance.size; self.disp_line.rounded_rectangle = (instance.x, instance.y, instance.width, instance.height, 20)
    def toggle_currency(self, inst): self.main_app.swap(); self.target_row = self.main_app.row1; self.pop_flag_img.source = self.target_row.flag_img.source
    def on_key_press(self, key):
        curr_disp = self.display.text.replace(',', ''); curr_form = self.formula.text.replace(',', '')
        if key == 'C': self.formula.text, self.display.text = "", ""
        elif key == 'BACK':
            if curr_disp: new_v = curr_disp[:-1]; self.display.text = "{:,}".format(int(new_v)) if new_v else ""
            elif curr_form:
                parts = curr_form.strip().split(' ')
                if parts:
                    last = parts.pop()
                    if last in '+-*/' and parts: self.display.text = parts.pop(); self.formula.text = " ".join(parts) + " " if parts else ""
                    else: self.formula.text = " ".join(parts)
        elif key in '+-*/':
            if curr_disp: self.formula.text += "{:,}".format(int(curr_disp)) + " " + key + " "; self.display.text = ""
            elif curr_form:
                f_strip = curr_form.strip()
                if f_strip and f_strip[-1] in '+-*/': self.formula.text = f_strip[:-1] + " " + key + " "
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
                num = float(val); k_on = getattr(self.target_row.input, 'k_mode', False); raw_num = num / 1000 if k_on else num
                formatted_val = "{:,}".format(int(raw_num))
                if k_on: formatted_val += "K"
                self.target_row.input.text = formatted_val; self.main_app.execute_calc(str(raw_num), self.target_row.input) 
            self.dismiss()

class ExchangeRateApp(App):
    def set_theme_colors(self, theme_id):
        if theme_id == 1:   
            self.c_main, self.c_sub, self.c_muted, self.c_memo, self.c_text = (0.15, 0.45, 0.85, 1), (0.4, 0.6, 0.85, 1), (0.5, 0.6, 0.75, 1), (0.92, 0.95, 0.98, 1), (0.1, 0.2, 0.4, 1)
        elif theme_id == 2: 
            self.c_main, self.c_sub, self.c_muted, self.c_memo, self.c_text = (1.0, 0.6, 0.3, 1), (0.35, 0.78, 0.7, 1), (0.4, 0.6, 0.85, 1), (1.0, 1.0, 0.88, 1), (0.15, 0.15, 0.18, 1)
        else:               
            self.c_main, self.c_sub, self.c_muted, self.c_memo, self.c_text = (0.25, 0.25, 0.25, 1), (0.55, 0.55, 0.55, 1), (0.7, 0.7, 0.7, 1), (0.95, 0.95, 0.95, 1), (0.1, 0.1, 0.1, 1)

    def apply_theme_ui(self, theme_id):
        self.set_theme_colors(theme_id)
        self.title_lbl.color = self.c_text
        self.memo_title.color = self.c_text
        self.memo_rect_color.rgba = self.c_memo
        self.memo_line_color.rgba = [max(0, c - 0.1) for c in self.c_memo[:3]] + [0.5]
        self.live_btn.update_color(self.c_main if theme_id!=2 else self.c_sub) 
        self.swap_btn.update_color(self.c_muted)
        self.quick_btn.update_color(self.c_sub if theme_id!=2 else self.c_muted)
        self.save_btn.update_color(self.c_main if theme_id!=2 else self.c_sub)
        self.herb_btn.update_color(self.c_sub if theme_id!=2 else self.c_muted)
        self.main_calc_btn.update_color(self.c_main)
        self.memo_input.cursor_color = self.c_main
        self.row1.input.cursor_color = self.c_main
        self.row2.input.cursor_color = self.c_main

    def change_theme(self, theme_id):
        self.settings["theme"] = theme_id
        self.save_rate_and_settings()
        self.apply_theme_ui(theme_id)

    def update_rate_desc(self):
        r = self.rate_in.text
        if r:
            try: self.rate_desc_label.text = f"1원 = {float(r):.2f}동"
            except: self.rate_desc_label.text = ""
        else:
            self.rate_desc_label.text = ""

    def add_bottom_newlines(self, text, count=20):
        return text.rstrip('\n') + '\n' * count

    def replace_with_clipboard(self, dt):
        clip = Clipboard.paste() or ""
        if not clip:
            self.reset_paste_state()
            return
        clip = clip.replace("\r\n", "\n").replace("\r", "\n")
        self.programmatic_insert = True
        try:
            ti = self.memo_input
            ti.text = self.before_text[:self.before_cursor] + clip + self.before_text[self.before_cursor:]
            new_cursor = self.before_cursor + len(clip)
            ti.cursor = ti.get_cursor_from_index(new_cursor)
            ti.focus = True
        finally:
            self.programmatic_insert = False
        self.last_replace_time = time.time()
        self.reset_paste_state()

    def reset_paste_state(self):
        self.last_input_time = 0.0
        self.burst_count = 0
        self.burst_newlines = 0
        self.burst_started = False
        self.before_text = self.memo_input.text if hasattr(self, "memo_input") else ""
        self.before_cursor = self.memo_input.cursor_index() if hasattr(self, "memo_input") else 0

    def build(self):
        self.is_swapped, self.is_updating = False, False
        self.app_data = load_data()
        self.settings = self.app_data["settings"]
        self.last_saved_memo = self.app_data["memo"]
        initial_rate = self.app_data["rate"]

        self.programmatic_insert = False
        self.last_input_time = 0.0
        self.last_replace_time = 0.0
        self.replace_cooldown = 0.45
        self.burst_window = 0.12
        self.burst_count = 0
        self.burst_newlines = 0
        self.burst_started = False
        self.before_text = ""
        self.before_cursor = 0

        self.set_theme_colors(self.settings.get("theme", 1))
        
        root = BoxLayout(orientation='vertical', padding=[25, 25], spacing=18)
        header_box = RelativeLayout(size_hint_y=None, height=100)
        self.title_lbl = Label(text="환율 계산기", font_size=52, bold=True, color=self.c_text, font_name=K_FONT, halign='center', pos_hint={'center_x': 0.5, 'center_y': 0.5})
        settings_layout = RelativeLayout(size_hint=(None, None), size=(100, 100), pos_hint={'right': 1, 'center_y': 0.5})
        settings_btn = StyledButton(bg_color=MAIN_BG)
        settings_img = Image(source=ICON_SET, size_hint=(0.6, 0.6), pos_hint={'center_x': 0.5, 'center_y': 0.5})
        settings_btn.bind(on_release=lambda x: SettingsPopup(self).open())
        settings_layout.add_widget(settings_btn); settings_layout.add_widget(settings_img)
        header_box.add_widget(self.title_lbl); header_box.add_widget(settings_layout)
        root.add_widget(header_box)
        self.row1 = CardInput(label_text="VND", flag_url=FLAG_VN, cursor_c=self.c_main)
        self.row2 = CardInput(label_text="KRW", flag_url=FLAG_KR, cursor_c=self.c_main)
        root.add_widget(self.row1); root.add_widget(self.row2)

        ctrl_area = BoxLayout(orientation='vertical', size_hint_y=None, height=145)
        ctrl_box = BoxLayout(size_hint_y=None, height=100, spacing=15)
        self.rate_in = RateTextInput(
            text=initial_rate, multiline=False, font_size=45,
            size_hint_x=0.45, halign='center',
            background_normal='', background_color=(0.9, 0.92, 0.95, 1),
            foreground_color=TEXT_BLACK, font_name=K_FONT, input_type='text'
        )
        t_id = self.settings.get("theme", 1)
        self.live_btn = StyledButton(text="실시간", bg_color=self.c_main if t_id!=2 else self.c_sub, size_hint_x=0.25, f_size=32, t_color=(1,1,1,1))
        self.live_btn.bind(on_release=lambda x: self.get_rate())
        self.swap_btn = StyledButton(text="⇅ 위치 변경", bg_color=self.c_muted, size_hint_x=0.25, f_size=32, t_color=(1,1,1,1))
        self.swap_btn.bind(on_release=lambda x: self.swap())
        ctrl_box.add_widget(Widget(size_hint_x=0.02))
        ctrl_box.add_widget(Label(text="환율", font_size=34, bold=True, size_hint_x=0.03, font_name=K_FONT, color=TEXT_BLACK))
        ctrl_box.add_widget(self.rate_in)
        ctrl_box.add_widget(self.live_btn)
        ctrl_box.add_widget(self.swap_btn)
        ctrl_area.add_widget(ctrl_box)

        date_line = BoxLayout(size_hint_y=None, height=45, spacing=15)
        date_line.add_widget(Widget(size_hint_x=0.02))
        date_line.add_widget(Widget(size_hint_x=0.03))
        init_desc = f"1원 = {float(initial_rate):.2f}동" if initial_rate else ""
        self.rate_desc_label = Label(
            text=init_desc, font_size=30, color=MUTED_COLOR,
            font_name=K_FONT, size_hint_x=0.45, bold=True,
            halign='center', valign='middle'
        )
        self.rate_desc_label.bind(size=lambda l, s: setattr(l, 'text_size', s))
        date_line.add_widget(self.rate_desc_label)
        init_label = f"{datetime.datetime.now().strftime('%y.%m.%d %H:%M')} 수동 입력" if initial_rate else "환율을 업데이트 하세요"
        self.update_label = Label(
            text=init_label, font_size=30, color=MUTED_COLOR,
            font_name=K_FONT, size_hint_x=0.50,
            halign='left', valign='middle',
            shorten=True, shorten_from='right'
        )
        self.update_label.bind(size=lambda l, s: setattr(l, 'text_size', s))
        date_line.add_widget(self.update_label)
        ctrl_area.add_widget(date_line)
        root.add_widget(ctrl_area)

        memo_container = BoxLayout(orientation='vertical', size_hint_y=1, padding=[5, 5])
        with memo_container.canvas.before: 
            self.memo_rect_color = Color(*self.c_memo)
            self.memo_rect = RoundedRectangle(pos=(0,0), size=(0,0), radius=[25,])
            self.memo_line_color = Color(*[max(0, c - 0.1) for c in self.c_memo[:3]] + [0.5])
            self.memo_line = Line(rounded_rectangle=(0,0,0,0, 25), width=1.2)
        memo_container.bind(pos=self.update_memo_design, size=self.update_memo_design)
        memo_header = BoxLayout(orientation='horizontal', size_hint_y=None, height=85, padding=[15, 10], spacing=10)
        self.quick_btn = StyledButton(text="퀵 환산", bg_color=self.c_sub if t_id!=2 else self.c_muted, size_hint_x=0.25, f_size=32, radius=15, t_color=(1,1,1,1))
        self.quick_btn.bind(on_release=lambda x: QuickRatePopup(current_rate=float(self.rate_in.text if self.rate_in.text else 1)).open())
        memo_header.add_widget(self.quick_btn)
        self.memo_title = Label(text="MEMO", font_size=38, bold=True, color=self.c_text, font_name=K_FONT, halign='center', size_hint_x=0.5)
        memo_header.add_widget(self.memo_title)
        self.save_btn = StyledButton(text="저장", bg_color=self.c_main if t_id!=2 else self.c_sub, size_hint_x=0.25, f_size=32, radius=15, t_color=(1,1,1,1))
        self.save_btn.bind(on_release=lambda x: ThemeSavePopup(on_confirm=self.save_memo_direct, on_select_all=self.memo_input.select_all).open())
        memo_header.add_widget(self.save_btn)
        memo_container.add_widget(memo_header)
        self.memo_scroll = ScrollView(
            do_scroll_x=False, do_scroll_y=True,
            always_overscroll=False,
            bar_width=15, bar_margin=12,
            scroll_type=['bars', 'content'],
            bar_color=(0.5, 0.5, 0.5, 0.6),
            bar_inactive_color=(0.6, 0.6, 0.6, 0.3),
            size_hint=(1, 1)
        )
        self.memo_input = AutoPasteMemoInput(
            text=self.add_bottom_newlines(self.last_saved_memo),
            font_size=40,
            background_color=(0,0,0,0), foreground_color=TEXT_BLACK,
            padding=[30, 20, 30, 20], font_name=K_FONT,
            multiline=True, line_height=1.2,
            cursor_color=self.c_main, size_hint_y=None
        )
        def update_memo_height(*args):
            self.memo_input.height = max(self.memo_scroll.height, self.memo_input.minimum_height)
        self.memo_scroll.bind(height=update_memo_height)
        self.memo_input.bind(minimum_height=update_memo_height)
        self.memo_input.bind(focus=self.on_memo_focus)
        self.memo_input.bind(text=self.on_memo_text_change)
        self.memo_input.bind(cursor=self.ensure_cursor_visible)
        self.memo_scroll.add_widget(self.memo_input)
        memo_container.add_widget(self.memo_scroll)
        root.add_widget(memo_container)
        self.bottom_box = BoxLayout(orientation='horizontal', size_hint_y=None, height=180, spacing=20)
        self.herb_btn = StyledButton(text="고수 X", bg_color=self.c_sub if t_id!=2 else self.c_muted, size_hint_x=0.25, f_size=55, bold=True, radius=40, t_color=(1,1,1,1))
        self.herb_btn.bind(on_release=lambda x: HerbPopup().open())
        self.main_calc_btn = StyledButton(text="계산기 열기", bg_color=self.c_main, size_hint_x=0.75, f_size=55, bold=True, radius=40, t_color=(1,1,1,1))
        self.main_calc_btn.bind(on_release=lambda x: CalculatorPopup(self, self.row1).open())
        self.bottom_box.add_widget(self.herb_btn); self.bottom_box.add_widget(self.main_calc_btn)
        root.add_widget(self.bottom_box)
        Clock.schedule_once(lambda dt: self.update_ui_for_settings(), 0)
        return root

    def on_memo_focus(self, instance, value):
        if value:
            Animation(height=0, opacity=0, duration=0.2, t='out_quad').start(self.bottom_box)
            Clock.schedule_once(lambda dt: self.ensure_cursor_visible(), 0.3)
        else:
            Animation(height=180, opacity=1, duration=0.2, t='out_quad').start(self.bottom_box)

    def ensure_cursor_visible(self, *args):
        if not self.memo_input.focus:
            return
        def _adjust(dt):
            ti = self.memo_input
            sv = self.memo_scroll
            max_scroll = ti.height - sv.height
            if max_scroll <= 0:
                return
            current_scroll_y = sv.scroll_y * max_scroll
            cursor_y = ti.cursor_pos[1]
            visible_bottom = current_scroll_y
            visible_top = current_scroll_y + sv.height
            padding = 120
            if cursor_y < visible_bottom + padding:
                target = max(0, cursor_y - padding)
            elif cursor_y > visible_top - padding:
                target = min(max_scroll, cursor_y - sv.height + padding)
            else:
                return
            new_scroll_y = target / max_scroll if max_scroll > 0 else 1
            Animation(scroll_y=new_scroll_y, duration=0.15, t='out_quad').start(sv)
        Clock.schedule_once(_adjust, 0)

    def on_memo_text_change(self, instance, value):
        if self.settings.get("auto_save", False):
            self.save_memo_direct()

    def on_stop(self):
        # ✅ 포커스 해제 후 저장
        self.memo_input.focus = False
        self.app_data["memo"] = self.memo_input.text
        self.app_data["rate"] = self.rate_in.text
        self.app_data["settings"] = self.settings
        save_data(self.app_data)

    def on_pause(self):
        # ✅ 포커스 명시적 해제 → 돌아왔을 때 키보드 정상 작동
        self.memo_input.focus = False
        self.app_data["memo"] = self.memo_input.text
        self.app_data["rate"] = self.rate_in.text
        self.app_data["settings"] = self.settings
        save_data(self.app_data)
        return True

    def on_resume(self):
        # ✅ 복귀 시 키보드 모드 재설정
        Window.softinput_mode = 'resize'

    def save_rate_and_settings(self):
        self.app_data["rate"] = self.rate_in.text
        self.app_data["settings"] = self.settings
        save_data(self.app_data)

    def save_memo_direct(self):
        self.last_saved_memo = self.memo_input.text
        self.app_data["memo"] = self.memo_input.text
        self.app_data["rate"] = self.rate_in.text
        self.app_data["settings"] = self.settings
        save_data(self.app_data)

    def update_ui_for_settings(self):
        is_auto_zeros = self.settings.get("auto_zeros", False)
        self.row1.set_auto_zero_mode(is_auto_zeros)
        self.row2.set_auto_zero_mode(is_auto_zeros)
    
    def clear_all_inputs(self, inst): 
        try: self.is_updating = True; self.row1.input.text = ""; self.row2.input.text = ""
        finally: self.is_updating = False
        
    def execute_calc(self, value, source_input):
        if self.is_updating: return
        is_row1 = (source_input == self.row1.input)
        target_input = self.row2.input if is_row1 else self.row1.input
        if not value or value == ".": self.is_updating = True; target_input.text = ""; self.is_updating = False; return
        try:
            r_text = self.rate_in.text
            if not r_text or r_text == ".": return
            r = float(r_text); v = float(value.replace(',', '').replace('K', ''))
            is_auto_zeros = self.settings.get("auto_zeros", False)
            source_is_vnd = FLAG_VN in (self.row1.flag_img.source if is_row1 else self.row2.flag_img.source)
            actual_v = v * 1000 if (is_auto_zeros and source_is_vnd) else v
            target_actual = actual_v / r if source_is_vnd else actual_v * r
            target_is_vnd = not source_is_vnd
            if self.settings.get("round_krw", False) and not target_is_vnd:
                target_actual = int((target_actual + 50) // 100) * 100 
            display_res = target_actual / 1000 if (is_auto_zeros and target_is_vnd) else target_actual
            self.is_updating = True
            if getattr(target_input, 'k_mode', False): target_input.text = f"{int(display_res):,}K"
            else: target_input.text = f"{int(display_res):,}"
            self.is_updating = False
        except: self.is_updating = False
        
    def update_memo_design(self, instance, value): 
        self.memo_rect.pos, self.memo_rect.size = instance.pos, instance.size
        self.memo_line.rounded_rectangle = (instance.x, instance.y, instance.width, instance.height, 25)
        
    def swap(self):
        self.is_updating = True; v1, v2 = self.row1.input.text, self.row2.input.text
        self.is_swapped = not self.is_swapped
        if self.is_swapped: self.row1.name_label.text, self.row1.flag_img.source = "KRW", FLAG_KR; self.row2.name_label.text, self.row2.flag_img.source = "VND", FLAG_VN
        else: self.row1.name_label.text, self.row1.flag_img.source = "VND", FLAG_VN; self.row2.name_label.text, self.row2.flag_img.source = "KRW", FLAG_KR
        self.row1.input.text, self.row2.input.text = v2, v1
        self.is_updating = False
        self.update_ui_for_settings()
        
    def on_start(self): 
        if self.settings.get("auto_update", True): 
            self.get_rate()
        
    def get_rate(self):
        try:
            data = requests.get("https://open.er-api.com/v6/latest/KRW", timeout=3).json() 
            if data['result'] == 'success':
                self.rate_in.text = f"{data['rates']['VND']:.2f}"
                now = datetime.datetime.now().strftime("%y.%m.%d %H:%M")
                self.update_label.text = f"{now} 기준"
                self.update_rate_desc()
                self.save_rate_and_settings()
                if self.row1.input.text: self.execute_calc(self.row1.input.text, self.row1.input)
            else:
                self.update_label.text = "업데이트 실패 (서버 오류)"
        except: 
            self.update_label.text = "업데이트 실패 (인터넷 확인)"

if __name__ == "__main__":
    ExchangeRateApp().run()
