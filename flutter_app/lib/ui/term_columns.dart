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
    this.editTok,
    this.pendingTok,
    this.onTapTok,
  });

  /// 골라서 고치는 중인 숫자의 토큰 번호 (커서와 금색 바탕이 그 숫자에)
  final int? editTok;

  /// 고른 숫자 뒤에 방금 넣은 연산자가 있을 때 그 연산자 토큰 번호 (커서가 그 뒤에)
  final int? pendingTok;

  /// 숫자를 눌렀을 때 (토큰 번호)
  final void Function(int tok)? onTapTok;

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
        crossAxisAlignment: center
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.end,
        children: [
          a,
          if (hasBottom) b ?? Text('', style: bottom),
        ],
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
    // 숫자가 추가되거나 바뀔 때 살짝 올라오며 나타난다
    Widget pop(Key key, Widget child) => _PopIn(key: key, child: child);

    for (var i = 0; i < parts.length; i++) {
      final part = parts[i];
      final last = i == parts.length - 1;
      if (i > 0 || part.sign == opSub) cells.add(gap(part.sign));
      final editingHere = part.pieces.any(
        (x) => x.$1 == editTok || x.$1 == pendingTok,
      );
      final lastNumTok = part.pieces.last.$1;
      // 항목 안의 숫자·×÷ 를 하나씩 그린다 (숫자는 따로 누를 수 있다)
      final topRow = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          for (final (tok, text) in part.pieces)
            if (isOperator(text))
              Padding(
                padding: EdgeInsets.symmetric(horizontal: topSize * 0.18),
                child: tok == pendingTok && cursor
                    ? AnimatedNumberText(
                        text,
                        cursorColor: p.gold,
                        style: opTop,
                      )
                    : Text(text, style: opTop),
              )
            else
              Builder(
                builder: (context) {
                  final selected = tok == editTok;
                  final cursorHere =
                      cursor &&
                      (editTok == null && pendingTok == null
                          ? last && trailing.isEmpty && tok == lastNumTok
                          : selected);
                  Widget w = cursorHere
                      ? AnimatedNumberText(
                          text,
                          cursorColor: p.gold,
                          style: top,
                        )
                      : pop(ValueKey('n$tok$text'), Text(text, style: top));
                  if (selected) {
                    w = Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: p.gold.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: w,
                    );
                  }
                  if (onTapTok != null) {
                    w = GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTapTok!(tok),
                      child: w,
                    );
                  }
                  return w;
                },
              ),
        ],
      );
      final v = part.value;
      cells.add(
        col(
          topRow,
          pop(
            ValueKey('v$i${v ?? ''}'),
            Text(
              v == null || convert == null ? '—' : fmt(convert!(v)),
              style: bottom,
            ),
          ),
          hi:
              (editingHere && editTok == null && pendingTok != null) ||
              (last && highlightLast && parts.length > 1 && editTok == null),
        ),
      );
    }
    if (trailing.isNotEmpty) {
      cells.add(
        Padding(
          padding: EdgeInsets.only(left: topSize * 0.22),
          child: col(
            cursor
                ? AnimatedNumberText(
                    trailing,
                    cursorColor: p.gold,
                    style: opTop,
                  )
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
          Text(
            r == null ? '—' : fmt(r),
            style: bottom.copyWith(fontWeight: FontWeight.w900),
          ),
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
    final count =
        exprParts(child.expr).$1.length + (child.total == null ? 0 : 1);
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
              child: _EdgeScroll(child: child),
            ),
          ),
        );
      },
    );
  }
}

/// 좌우로 밀어 보는 금액 줄. 앞쪽이 더 있으면 왼쪽 끝을 흐리게 하고,
/// 맨 앞까지 밀면 흐림이 사라져 첫 금액이 또렷하게 보인다. 끝에서는 스프링처럼 튕긴다.
class _EdgeScroll extends StatefulWidget {
  const _EdgeScroll({required this.child});
  final Widget child;

  @override
  State<_EdgeScroll> createState() => _EdgeScrollState();
}

class _EdgeScrollState extends State<_EdgeScroll> {
  final _ctrl = ScrollController();
  bool _moreOnLeft = true;

  void _update() {
    if (!_ctrl.hasClients) return;
    final pos = _ctrl.position;
    // reverse: true 라서 오른쪽(최근)이 0, 맨 왼쪽(처음)이 maxScrollExtent
    final more = pos.pixels < pos.maxScrollExtent - 1;
    if (more != _moreOnLeft) setState(() => _moreOnLeft = more);
  }

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_update);
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  @override
  void didUpdateWidget(_EdgeScroll old) {
    super.didUpdateWidget(old);
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scroll = SingleChildScrollView(
      controller: _ctrl,
      scrollDirection: Axis.horizontal,
      reverse: true,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      child: widget.child,
    );
    return TweenAnimationBuilder<double>(
      tween: Tween(end: _moreOnLeft ? 0.12 : 0.0),
      duration: const Duration(milliseconds: 180),
      // 위젯 모양을 바꾸지 않아야 밀어 둔 위치가 그대로 남는다 → 흐림 폭만 바꾼다
      builder: (context, fade, child) => ShaderMask(
        shaderCallback: (r) => LinearGradient(
          colors: fade <= 0.001
              ? const [Colors.black, Colors.black]
              : const [Colors.transparent, Colors.black],
          stops: [0, fade <= 0.001 ? 1 : fade],
        ).createShader(r),
        blendMode: BlendMode.dstIn,
        child: child,
      ),
      child: scroll,
    );
  }
}

/// 새 값이 나타날 때 살짝 아래에서 올라오며 밝아진다 (키가 바뀌면 다시 재생)
class _PopIn extends StatelessWidget {
  const _PopIn({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: key,
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 6),
          child: child,
        ),
      ),
    );
  }
}
