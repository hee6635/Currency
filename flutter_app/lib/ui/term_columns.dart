import 'package:flutter/material.dart';

import '../core/money.dart';
import 'common.dart';
import 'motion.dart';
import 'theme.dart';

/// 넣은 금액(위)과 바꾼 금액(아래)을 항목마다 세로로 줄 맞춰 보여준다.
///   150,000 + 30,000 + 27,000  동
///     7,972 +  1,594 +  1,435  원
class TermColumns extends StatelessWidget {
  const TermColumns({
    super.key,
    required this.expr,
    required this.from,
    required this.convert,
    required this.topSize,
    required this.bottomSize,
    this.cursor = false,
    this.highlightLast = false,
    this.total,
  });

  final String expr;
  final Currency from;

  /// 환율이 없으면 null → 아래 줄 없음
  final double Function(double)? convert;
  final double topSize, bottomSize;

  /// 마지막 금액 끝에 깜빡이는 커서와 입력 애니메이션
  final bool cursor;

  /// 마지막 항목(방금 넣은 것)을 금색 바탕으로
  final bool highlightLast;

  /// 지정하면 끝에 "= 합계" 칸
  final (double, double?)? total;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (parts, trailing) = exprParts(expr);
    final to = from.other;
    final topColor = p.ink;
    final bottomColor = currencyAccent(to, p);
    final top = TextStyle(
      fontSize: topSize,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.6,
      color: topColor,
      fontFeatures: tabular,
      height: 1.15,
    );
    final bottom = TextStyle(
      fontSize: bottomSize,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.3,
      color: bottomColor,
      fontFeatures: tabular,
      height: 1.2,
    );
    final opTop = top.copyWith(color: p.muted, fontWeight: FontWeight.w500);
    final opBottom = bottom.copyWith(
      color: bottomColor.withValues(alpha: 0.6),
      fontWeight: FontWeight.w600,
    );
    final hasBottom = convert != null;

    Widget col(Widget a, Widget? b, {bool hi = false, bool center = false}) {
      final c = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            center ? CrossAxisAlignment.center : CrossAxisAlignment.end,
        children: [a, if (hasBottom) b ?? Text('', style: bottom)],
      );
      if (!hi) return c;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: p.gold.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(10),
        ),
        child: c,
      );
    }

    Widget gap(String op) => Padding(
      padding: EdgeInsets.symmetric(horizontal: topSize * 0.22),
      child: col(
        Text(op, style: opTop),
        op.isEmpty ? null : Text(op, style: opBottom),
        center: true,
      ),
    );

    final cells = <Widget>[];
    if (parts.isEmpty) {
      cells.add(
        cursor
            ? AnimatedNumberText(
                '0',
                cursorColor: p.gold,
                style: top.copyWith(color: p.muted.withValues(alpha: 0.6)),
              )
            : Text('0', style: top.copyWith(color: p.muted)),
      );
    }
    for (var i = 0; i < parts.length; i++) {
      final (sign, text, v) = parts[i];
      final last = i == parts.length - 1;
      if (i > 0 || sign == opSub) cells.add(gap(sign));
      final topW = last && cursor && trailing.isEmpty
          ? AnimatedNumberText(text, cursorColor: p.gold, style: top)
          : Text(text, style: top);
      cells.add(
        col(
          topW,
          Text(v == null || convert == null ? '—' : fmt(convert!(v)), style: bottom),
          hi: last && highlightLast && parts.length > 1,
        ),
      );
    }
    if (trailing.isNotEmpty) {
      cells.add(
        Padding(
          padding: EdgeInsets.only(left: topSize * 0.22),
          child: col(
            cursor
                ? AnimatedNumberText(trailing, cursorColor: p.gold, style: opTop)
                : Text(trailing, style: opTop),
            null,
          ),
        ),
      );
    }
    if (total case (final t, final r)?) {
      cells.add(gap('='));
      cells.add(
        col(
          Text(fmt(t), style: top.copyWith(fontWeight: FontWeight.w800)),
          Text(r == null ? '—' : fmt(r), style: bottom.copyWith(fontWeight: FontWeight.w900)),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: cells,
    );
  }
}

/// 항목이 [maxBeforeScroll]개까지는 칸에 맞게 줄이고, 더 많으면 글씨 크기를 지키고
/// 좌우로 밀어 볼 수 있게 한다 (최근 것이 늘 보이게 오른쪽 끝에 붙는다).
class TermsView extends StatelessWidget {
  const TermsView({
    super.key,
    required this.child,
    this.maxBeforeScroll = 3,
    this.alignment = Alignment.centerRight,
  });

  final TermColumns child;
  final Alignment alignment;
  final int maxBeforeScroll;

  @override
  Widget build(BuildContext context) {
    final count = exprParts(child.expr).$1.length + (child.total == null ? 0 : 1);
    return LayoutBuilder(
      builder: (context, box) {
        if (count <= maxBeforeScroll || !box.hasBoundedWidth) {
          return Align(
            alignment: alignment,
            child: FittedBox(fit: BoxFit.scaleDown, child: child),
          );
        }
        return Align(
          alignment: Alignment.centerRight,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: box.maxWidth,
              // 왼쪽 끝은 흐리게 사라지게 (밀면 더 있다는 표시)
              child: ShaderMask(
                shaderCallback: (r) => const LinearGradient(
                  colors: [Colors.transparent, Colors.black],
                  stops: [0, 0.12],
                ).createShader(r),
                blendMode: BlendMode.dstIn,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
