import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 베트남 폴리머 지폐를 닮은 그림 (실물 사진 대신 직접 그림).
/// 실제 지폐처럼 색, "500.000 ĐỒNG" 표기, 투명창, 문양을 살렸다.
class Banknote extends StatelessWidget {
  const Banknote({super.key, required this.value, required this.color, this.width = 96});

  final int value;
  final Color color;
  final double width;

  static const aspect = 2.15;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(width, width / aspect),
    painter: _NotePainter(value, color),
  );
}

String _dotted(int v) {
  final s = v.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}

class _NotePainter extends CustomPainter {
  _NotePainter(this.value, this.color);
  final int value;
  final Color color;

  @override
  void paint(Canvas c, Size size) {
    final w = size.width, h = size.height;
    final rr = RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(h * 0.09));
    final dark = Color.lerp(color, Colors.black, 0.28)!;
    final light = Color.lerp(color, Colors.white, 0.35)!;

    // 그림자
    c.drawRRect(
      rr.shift(Offset(0, h * 0.04)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.05),
    );

    c.save();
    c.clipRRect(rr);

    // 바탕
    c.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [dark, color, light],
          stops: const [0, 0.55, 1],
        ).createShader(Offset.zero & size),
    );

    // 물결 문양 (기요셰)
    final wave = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.5, h * 0.008)
      ..color = Colors.white.withValues(alpha: 0.13);
    for (var k = 0; k < 14; k++) {
      final path = Path();
      final baseY = h * (0.05 + k * 0.07);
      for (var x = 0.0; x <= w; x += w / 60) {
        final y = baseY + math.sin(x / w * math.pi * 4 + k * 0.6) * h * 0.05;
        x == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      c.drawPath(path, wave);
    }

    // 오른쪽 둥근 문양 (인물 초상 자리)
    final center = Offset(w * (h >= 60 ? 0.72 : 0.8), h * 0.5);
    final r = h * (h >= 60 ? 0.38 : 0.3);
    c.drawCircle(center, r, Paint()..color = Colors.white.withValues(alpha: 0.12));
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(0.5, h * 0.01)
      ..color = Colors.white.withValues(alpha: 0.28);
    for (var i = 0; i < 4; i++) {
      c.drawCircle(center, r * (1 - i * 0.16), ring);
    }
    for (var i = 0; i < 24; i++) {
      final a = i * math.pi / 12;
      c.drawLine(
        center + Offset(math.cos(a), math.sin(a)) * r * 0.5,
        center + Offset(math.cos(a), math.sin(a)) * r * 0.84,
        ring,
      );
    }
    _star(c, center, r * 0.36, const Color(0xFFFFE08A).withValues(alpha: 0.85));

    // 폴리머 투명창
    final win = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.9, h * 0.2, w * 0.07, h * 0.6),
      Radius.circular(h * 0.04),
    );
    c.drawRRect(win, Paint()..color = Colors.white.withValues(alpha: 0.42));

    // 안쪽 테두리
    c.drawRRect(
      rr.deflate(h * 0.055),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.6, h * 0.012)
        ..color = Colors.white.withValues(alpha: 0.35),
    );
    c.restore();

    // 글자
    final shadow = [Shadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: h * 0.04)];
    if (h >= 60) {
      _text(c, 'NGÂN HÀNG NHÀ NƯỚC VIỆT NAM', Offset(w * 0.07, h * 0.12), h * 0.075, FontWeight.w700, shadow, spacing: h * 0.008);
    }
    if (h >= 60) {
      final tp = _text(c, _dotted(value), Offset(w * 0.07, h * 0.32), h * 0.27, FontWeight.w900, shadow);
      _text(c, 'ĐỒNG', Offset(w * 0.07, h * 0.32 + tp.height * 0.95), h * 0.13, FontWeight.w800, shadow, spacing: h * 0.02);
    } else {
      // 작은 썸네일: 숫자만 크게, 가운데 높이에
      final tp = _measure(_dotted(value), h * 0.34, FontWeight.w900, shadow);
      tp.paint(c, Offset(w * 0.08, (h - tp.height) / 2));
    }
  }

  TextPainter _text(Canvas c, String s, Offset at, double size, FontWeight weight, List<Shadow> shadow, {double spacing = 0}) {
    final tp = _measure(s, size, weight, shadow, spacing: spacing);
    tp.paint(c, at);
    return tp;
  }

  TextPainter _measure(String s, double size, FontWeight weight, List<Shadow> shadow, {double spacing = 0}) {
    return TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          color: Colors.white,
          fontSize: size,
          fontWeight: weight,
          letterSpacing: spacing,
          height: 1,
          shadows: shadow,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  void _star(Canvas c, Offset center, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rad = i.isEven ? r : r * 0.4;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = center + Offset(math.cos(a), math.sin(a)) * rad;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    c.drawPath(path..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(_NotePainter old) => old.value != value || old.color != color;
}
