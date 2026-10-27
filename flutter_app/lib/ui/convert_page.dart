import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/money.dart';
import 'common.dart';
import 'motion.dart';
import 'rate_sheet.dart';
import 'theme.dart';

class ConvertPage extends StatelessWidget {
  const ConvertPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const PageHeader(title: '환율 계산'),
        Expanded(
          child: LayoutBuilder(
            builder: (context, box) {
              final compact = box.maxHeight < 560;
              final fromH = compact ? 96.0 : 116.0;
              final toH = compact ? 112.0 : 140.0;
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Column(
                  children: [
                    SizedBox(
                      height: fromH + 8 + toH,
                      child: Stack(
                        children: [
                          Column(
                            children: [
                              SizedBox(
                                height: fromH,
                                child: const _InputCard(),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(height: toH, child: const _ResultCard()),
                            ],
                          ),
                          Positioned(
                            top: fromH + 4 - 28,
                            left: 0,
                            right: 0,
                            child: const Center(child: _SwapButton()),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Expanded(child: Keypad()),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 카드 위쪽 통화 표시: 국기 + 통화 코드(굵게) + 이름, 반투명 알약 배경 위에
class _CardLabel extends StatelessWidget {
  const _CardLabel(this.currency, {required this.onNavy, this.trailing});
  final Currency currency;
  final bool onNavy;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final strong = onNavy ? p.onNavy : p.ink;
    final soft = onNavy ? p.onNavyMuted : p.muted;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
          decoration: BoxDecoration(
            color: onNavy
                ? Colors.white.withValues(alpha: 0.16)
                : currencyAccent(currency, p).withValues(
                    alpha: Theme.of(context).brightness == Brightness.light
                        ? 0.09
                        : 0.22,
                  ),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: FlagIcon(currency, size: 26),
              ),
              const SizedBox(width: 8),
              Text(
                currency.code,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: strong,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                currency.name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: soft,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        ?trailing,
      ],
    );
  }
}

class _InputCard extends StatelessWidget {
  const _InputCard();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = context.palette;
    final v = s.inputValue;
    final String sub;
    if (v == null) {
      sub = '0으로 나눌 수 없어요';
    } else if (hasOperator(s.expr)) {
      sub = '= ${fmt(v)}${s.from.unit}';
    } else {
      final u = koreanUnit(v);
      sub = u.isEmpty ? '' : '$u${s.from.unit}';
    }

    return Panel(
      padding: const EdgeInsets.fromLTRB(18, 10, 10, 12),
      child: _SwapSlide(
        value: s.from,
        fromBelow: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CardLabel(
              s.from,
              onNavy: false,
              trailing: IconButton(
                tooltip: '금액 붙여넣기',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.content_paste_rounded,
                  size: 20,
                  color: p.muted,
                ),
                onPressed: () async {
                  final data = await Clipboard.getData(Clipboard.kTextPlain);
                  if (!context.mounted) return;
                  final ok = s.pasteAmount(data?.text ?? '');
                  if (!ok) toast(context, '복사한 내용에 금액이 없어요');
                },
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: AnimatedNumberText(
                      prettyExpr(s.expr),
                      cursorColor: p.gold,
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.8,
                        color: s.expr.isEmpty
                            ? p.muted.withValues(alpha: 0.6)
                            : p.ink,
                        fontFeatures: tabular,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                sub,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: v == null ? p.danger : p.muted,
                  fontFeatures: tabular,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 통화를 바꿀 때 카드 내용이 자리를 바꾸듯 미끄러지며 바뀐다.
/// 위 카드는 위에서, 아래 카드는 아래에서 들어온다.
class _SwapSlide extends StatelessWidget {
  const _SwapSlide({
    required this.value,
    required this.fromBelow,
    required this.child,
  });
  final Currency value;
  final bool fromBelow;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) =>
          Stack(fit: StackFit.expand, children: [...previous, ?current]),
      transitionBuilder: (child, a) {
        final entering = child.key == ValueKey(value);
        final dir = fromBelow ? 1.0 : -1.0;
        final begin = Offset(0, (entering ? 0.6 : -0.6) * dir);
        return ClipRect(
          child: FadeTransition(
            opacity: a,
            child: SlideTransition(
              position: Tween(begin: begin, end: Offset.zero).animate(a),
              child: child,
            ),
          ),
        );
      },
      child: KeyedSubtree(key: ValueKey(value), child: child),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = context.palette;
    final to = s.from.other;
    final r = s.resultValue;

    String big;
    final subs = <String>[];
    String? feeLine;
    if (s.rate == null) {
      big = '—';
      subs.add(s.fetching ? '환율을 불러오는 중이에요' : '오른쪽 위 환율 버튼을 눌러 주세요');
    } else if (r == null) {
      big = '—';
    } else {
      big = '${fmt(r)}${to.unit}';
      if (r > 0) {
        if (to == Currency.krw) {
          if (r >= 1000) subs.add('약 ${fmt(roundTo(r, 100))}원');
          final u = koreanUnit(r);
          if (u.isNotEmpty) subs.add('$u원');
        } else {
          final u = koreanUnit(r);
          if (u.isNotEmpty) subs.add('$u동');
          if (r >= 1000) subs.add('${fmt(r / 1000)}K');
        }
        if (s.feePercent > 0) {
          feeLine =
              '수수료 ${s.feePercent.toStringAsFixed(1)}% 반영 ≈ ${fmt(s.withFee(r))}${to.unit}';
        }
      }
    }

    final colors = currencyGradient(to, p, Theme.of(context).brightness);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.last.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: r == null || r <= 0
              ? (s.rate == null ? () => showRateSheet(context) : null)
              : () {
                  Clipboard.setData(ClipboardData(text: fmt(r)));
                  HapticFeedback.lightImpact();
                  toast(context, '${fmt(r)}${to.unit} 복사했어요');
                },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            child: _SwapSlide(
              value: to,
              fromBelow: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CardLabel(
                    to,
                    onNavy: true,
                    trailing: Icon(
                      Icons.copy_rounded,
                      size: 18,
                      color: p.onNavyMuted,
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        // 결과가 바뀔 때 살짝 올라오며 바뀐다
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeIn,
                          layoutBuilder: (current, previous) => Stack(
                            alignment: Alignment.centerRight,
                            children: [...previous, ?current],
                          ),
                          transitionBuilder: (child, a) => FadeTransition(
                            opacity: a,
                            child: SlideTransition(
                              position: Tween(
                                begin: const Offset(0, 0.25),
                                end: Offset.zero,
                              ).animate(a),
                              child: child,
                            ),
                          ),
                          child: Text(
                            big,
                            key: ValueKey(big),
                            style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.2,
                              color: s.expr.isEmpty
                                  ? p.onNavyMuted.withValues(alpha: 0.7)
                                  : p.onNavy,
                              fontFeatures: tabular,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Text(
                    subs.join('  ·  '),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: p.onNavyMuted,
                      fontFeatures: tabular,
                    ),
                  ),
                  if (feeLine != null)
                    Text(
                      feeLine,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: p.gold,
                        fontFeatures: tabular,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 통화 바꾸기 버튼: 누르면 살짝 눌리고, 화살표가 반 바퀴 돈다
class _SwapButton extends StatefulWidget {
  const _SwapButton();

  @override
  State<_SwapButton> createState() => _SwapButtonState();
}

class _SwapButtonState extends State<_SwapButton> {
  double _turns = 0;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      label: '통화 바꾸기',
      excludeSemantics: true,
      child: Container(
        width: 56,
        height: 56,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(shape: BoxShape.circle, color: p.bg),
        child: PressableKey(
          color: p.gold,
          highlight: p.navyHi,
          onTap: () {
            HapticFeedback.mediumImpact();
            setState(() => _turns += 0.5);
            AppScope.read(context).swap();
          },
          child: AnimatedRotation(
            turns: _turns,
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutBack,
            child: Icon(Icons.swap_vert_rounded, color: p.navy, size: 28),
          ),
        ),
      ),
    );
  }
}

enum _KeyKind { num, small, op, eq, clear, back }

class Keypad extends StatelessWidget {
  const Keypad({super.key});

  static const _rows = [
    ['7', '8', '9', opDiv],
    ['4', '5', '6', opMul],
    ['1', '2', '3', opSub],
    ['00', '0', '000', opAdd],
    ['C', 'back', '='], // = 은 두 칸
  ];

  static _KeyKind _kind(String k) {
    if (operators.contains(k)) return _KeyKind.op;
    return switch (k) {
      '=' => _KeyKind.eq,
      'C' => _KeyKind.clear,
      'back' => _KeyKind.back,
      '00' || '000' => _KeyKind.small,
      _ => _KeyKind.num,
    };
  }

  @override
  Widget build(BuildContext context) {
    const gap = 8.0;
    return LayoutBuilder(
      builder: (context, box) {
        final cell = (box.maxWidth - gap * 3) / 4;
        return Column(
          children: [
            for (final (i, row) in _rows.indexed) ...[
              if (i > 0) const SizedBox(height: gap),
              Expanded(
                child: Row(
                  children: [
                    for (final (j, k) in row.indexed) ...[
                      if (j > 0) const SizedBox(width: gap),
                      SizedBox(
                        width: row.length == 3 && k == '='
                            ? cell * 2 + gap
                            : cell,
                        child: _Key(k, _kind(k)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Key extends StatelessWidget {
  const _Key(this.k, this.kind);
  final String k;
  final _KeyKind kind;

  static const _names = {
    'C': '모두 지우기',
    'back': '한 글자 지우기',
    '=': '계산하기',
    opAdd: '더하기',
    opSub: '빼기',
    opMul: '곱하기',
    opDiv: '나누기',
  };

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (Color bg, Color fg) = switch (kind) {
      _KeyKind.op => (p.opBg, p.opFg),
      _KeyKind.eq => (p.navy, p.onNavy),
      _KeyKind.clear => (p.surface, p.danger),
      _ => (p.surface, p.ink),
    };
    final double size = switch (kind) {
      _KeyKind.small => 21,
      _KeyKind.clear => 22,
      _KeyKind.op || _KeyKind.eq => 28,
      _ => 26,
    };
    final child = kind == _KeyKind.back
        ? Icon(Icons.backspace_outlined, color: fg, size: 24)
        : Text(
            k,
            style: TextStyle(
              fontSize: size,
              fontWeight: kind == _KeyKind.clear
                  ? FontWeight.w700
                  : FontWeight.w400,
              color: fg,
              fontFeatures: tabular,
            ),
          );

    final s = AppScope.read(context);
    final highlight = switch (kind) {
      _KeyKind.op => p.navyHi,
      _KeyKind.clear => p.danger,
      _ => p.gold,
    };
    return Semantics(
      button: true,
      label: _names[k] ?? k,
      excludeSemantics: true,
      child: PressableKey(
        color: bg,
        highlight: highlight,
        shadow: kind != _KeyKind.op,
        onTap: () {
          HapticFeedback.selectionClick();
          s.press(k);
        },
        onLongPress: kind == _KeyKind.back ? () => s.press('C') : null,
        child: child,
      ),
    );
  }
}
