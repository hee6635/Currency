import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/money.dart';
import '../state/app_state.dart';
import 'rate_sheet.dart';
import 'theme.dart';

/// 각 탭 위쪽: 제목 + 환율 버튼
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
                color: p.ink,
              ),
            ),
          ),
          const RateChip(),
        ],
      ),
    );
  }
}

class RateChip extends StatelessWidget {
  const RateChip({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = context.palette;
    final failed = s.fetchError != null;
    final label = s.rate == null
        ? (s.fetching ? '환율 불러오는 중' : '환율 입력하기')
        : '1원 = ${s.rate!.toStringAsFixed(2)}동';

    return Material(
      color: p.surface,
      shape: StadiumBorder(side: BorderSide(color: p.line)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => showRateSheet(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (s.fetching)
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: p.opFg,
                    ),
                  )
                else
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: failed || s.rate == null
                          ? p.danger
                          : s.source == RateSource.manual
                          ? p.gold
                          : const Color(0xFF2EAD6B),
                    ),
                  ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: p.ink,
                    fontFeatures: tabular,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 국기 (그림 파일 대신 직접 그려서 어떤 화면에서도 선명하게)
class FlagIcon extends StatelessWidget {
  const FlagIcon(this.currency, {super.key, this.size = 22});
  final Currency currency;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: currency == Currency.vnd ? _VnFlag() : _KrFlag(),
  );
}

class _VnFlag extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final r = s.width / 2;
    final center = Offset(r, r);
    c.drawCircle(center, r, Paint()..color = const Color(0xFFDA251D));
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rad = i.isEven ? r * 0.58 : r * 0.23;
      final a = -math.pi / 2 + i * math.pi / 5;
      final pt = center + Offset(math.cos(a) * rad, math.sin(a) * rad);
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    c.drawPath(path..close(), Paint()..color = const Color(0xFFFFCD00));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _KrFlag extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final r = s.width / 2;
    final center = Offset(r, r);
    c.drawCircle(center, r, Paint()..color = Colors.white);
    c.drawCircle(
      center,
      r - 0.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = const Color(0x22000000),
    );
    // 태극
    final t = r * 0.42;
    c.save();
    c.translate(r, r);
    c.rotate(math.atan2(2, 3));
    final red = Paint()..color = const Color(0xFFCD2E3A);
    final blue = Paint()..color = const Color(0xFF0047A0);
    c.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: t),
      math.pi,
      math.pi,
      true,
      red,
    );
    c.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: t),
      0,
      math.pi,
      true,
      blue,
    );
    c.drawCircle(Offset(-t / 2, 0), t / 2, red);
    c.drawCircle(Offset(t / 2, 0), t / 2, blue);
    c.restore();
    // 4괘 (단순화)
    final bar = Paint()
      ..color = const Color(0xFF111111)
      ..strokeWidth = r * 0.07;
    for (var k = 0; k < 4; k++) {
      final a = -math.pi * 3 / 4 + k * math.pi / 2;
      c.save();
      c.translate(r + math.cos(a) * r * 0.72, r + math.sin(a) * r * 0.72);
      c.rotate(a + math.pi / 2);
      for (var j = -1; j <= 1; j++) {
        final y = j * r * 0.11;
        c.drawLine(Offset(-r * 0.14, y), Offset(r * 0.14, y), bar);
      }
      c.restore();
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// 모서리가 둥근 흰 카드
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.line),
      ),
      child: child,
    );
  }
}

/// 통화마다 고유한 색: 동 = 베트남 국기 빨강, 원 = 남색.
/// 결과 카드가 바꿀 통화의 색을 따라가서 방향이 한눈에 보인다.
List<Color> currencyGradient(Currency c, Palette p, Brightness b) {
  if (c == Currency.krw) return [p.navyHi, p.navy];
  return b == Brightness.light
      ? const [Color(0xFFD7383F), Color(0xFF961A24)]
      : const [Color(0xFFB4323A), Color(0xFF6A131B)];
}

Color currencyAccent(Currency c, Palette p) =>
    c == Currency.vnd ? const Color(0xFFD32F2F) : p.navyHi;

/// 남색 강조 카드 (결과, 합계)
BoxDecoration navyCard(Palette p) => BoxDecoration(
  borderRadius: BorderRadius.circular(24),
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [p.navyHi, p.navy],
  ),
  boxShadow: [
    BoxShadow(
      color: p.navy.withValues(alpha: 0.25),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ],
);

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(milliseconds: 1400),
      ),
    );
}
