import 'package:flutter/material.dart';

import '../state/app_state.dart';

/// 앱 아이콘의 남색 + 금색을 기본으로 한 색 묶음
@immutable
class Palette extends ThemeExtension<Palette> {
  const Palette({
    required this.bg,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.line,
    required this.navy,
    required this.navyHi,
    required this.onNavy,
    required this.onNavyMuted,
    required this.gold,
    required this.goldText,
    required this.opBg,
    required this.opFg,
    required this.kBg,
    required this.kFg,
    required this.danger,
  });

  final Color bg, surface, ink, muted, line;
  final Color navy, navyHi, onNavy, onNavyMuted;
  final Color gold, goldText;
  final Color opBg, opFg, kBg, kFg, danger;

  static const light = Palette(
    bg: Color(0xFFF2F3F7),
    surface: Color(0xFFFFFFFF),
    ink: Color(0xFF10172A),
    muted: Color(0xFF5D6577),
    line: Color(0xFFE7E9EF),
    navy: Color(0xFF17264F),
    navyHi: Color(0xFF2B4386),
    onNavy: Color(0xFFFFFFFF),
    onNavyMuted: Color(0xFFC3CCE3),
    gold: Color(0xFFE3B65A),
    goldText: Color(0xFF8C5E05),
    opBg: Color(0xFFE6EAF4),
    opFg: Color(0xFF17264F),
    kBg: Color(0xFFFBF0D9),
    kFg: Color(0xFF7F5300),
    danger: Color(0xFFC0392B),
  );

  static const dark = Palette(
    bg: Color(0xFF0A0F1D),
    surface: Color(0xFF151C2E),
    ink: Color(0xFFEDF0F7),
    muted: Color(0xFF9AA3B6),
    line: Color(0xFF242D42),
    navy: Color(0xFF1D2F61),
    navyHi: Color(0xFF34509B),
    onNavy: Color(0xFFFFFFFF),
    onNavyMuted: Color(0xFFBCC6E0),
    gold: Color(0xFFE8BE66),
    goldText: Color(0xFFE8BE66),
    opBg: Color(0xFF1E2840),
    opFg: Color(0xFFC9D5F2),
    kBg: Color(0xFF332812),
    kFg: Color(0xFFF0C766),
    danger: Color(0xFFFF8A7A),
  );

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(Palette? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return Palette(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      ink: l(ink, other.ink),
      muted: l(muted, other.muted),
      line: l(line, other.line),
      navy: l(navy, other.navy),
      navyHi: l(navyHi, other.navyHi),
      onNavy: l(onNavy, other.onNavy),
      onNavyMuted: l(onNavyMuted, other.onNavyMuted),
      gold: l(gold, other.gold),
      goldText: l(goldText, other.goldText),
      opBg: l(opBg, other.opBg),
      opFg: l(opFg, other.opFg),
      kBg: l(kBg, other.kBg),
      kFg: l(kFg, other.kFg),
      danger: l(danger, other.danger),
    );
  }
}

ThemeData buildTheme(Brightness b) {
  final p = b == Brightness.light ? Palette.light : Palette.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: p.navy,
    brightness: b,
  ).copyWith(
    primary: b == Brightness.light ? p.navy : p.navyHi,
    onPrimary: Colors.white,
    surface: p.bg,
    onSurface: p.ink,
    surfaceContainerLow: p.surface,
    surfaceContainerHighest: p.surface,
    secondary: p.gold,
    error: p.danger,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.bg,
    extensions: [p],
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surface,
      indicatorColor: p.opBg,
      elevation: 0,
      height: 68,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 12,
          fontWeight: s.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
          color: s.contains(WidgetState.selected) ? p.ink : p.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? p.opFg : p.muted,
        ),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

extension PaletteX on BuildContext {
  Palette get palette => Theme.of(this).extension<Palette>()!;
}

/// 금액 글자: 숫자 폭을 고정해서 바뀔 때 덜 흔들리게
const tabular = [FontFeature.tabularFigures()];

/// 화면 어디서나 상태를 꺼내 쓰기
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
    : super(notifier: state);

  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

String fmtTime(DateTime t) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${t.month}월 ${t.day}일 ${two(t.hour)}:${two(t.minute)}';
}
