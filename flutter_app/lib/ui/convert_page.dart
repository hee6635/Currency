import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/money.dart';
import 'common.dart';
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
                              SizedBox(height: fromH, child: const _InputCard()),
                              const SizedBox(height: 8),
                              SizedBox(height: toH, child: const _ResultCard()),
                            ],
                          ),
                          Positioned(
                            top: fromH + 4 - 24,
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

class _CardLabel extends StatelessWidget {
  const _CardLabel(this.currency, this.color, {this.trailing});
  final Currency currency;
  final Color color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      FlagIcon(currency, size: 20),
      const SizedBox(width: 8),
      Text(
        '${currency.name} · ${currency.code}',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color),
      ),
      const Spacer(),
      ?trailing,
    ],
  );
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CardLabel(
            s.from,
            p.muted,
            trailing: IconButton(
              tooltip: '금액 붙여넣기',
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.content_paste_rounded, size: 20, color: p.muted),
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
                  child: Text(
                    prettyExpr(s.expr),
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.8,
                      color: s.expr.isEmpty ? p.muted.withValues(alpha: 0.6) : p.ink,
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
          feeLine = '수수료 ${s.feePercent.toStringAsFixed(1)}% 반영 ≈ ${fmt(s.withFee(r))}${to.unit}';
        }
      }
    }

    return DecoratedBox(
      decoration: navyCard(p),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CardLabel(
                  to,
                  p.onNavyMuted,
                  trailing: Icon(Icons.copy_rounded, size: 16, color: p.onNavyMuted),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        big,
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1.2,
                          color: s.expr.isEmpty ? p.onNavyMuted.withValues(alpha: 0.7) : p.onNavy,
                          fontFeatures: tabular,
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
                  style: TextStyle(fontSize: 13, color: p.onNavyMuted, fontFeatures: tabular),
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
    );
  }
}

class _SwapButton extends StatelessWidget {
  const _SwapButton();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: p.bg, width: 4),
      ),
      child: Material(
        color: p.gold,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            HapticFeedback.selectionClick();
            AppScope.read(context).swap();
          },
          child: Tooltip(
            message: '통화 바꾸기',
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(Icons.swap_vert_rounded, color: p.navy, size: 24),
            ),
          ),
        ),
      ),
    );
  }
}

enum _KeyKind { num, small, op, k, eq, clear, back }

class Keypad extends StatelessWidget {
  const Keypad({super.key});

  static const _rows = [
    ['7', '8', '9', opDiv],
    ['4', '5', '6', opMul],
    ['1', '2', '3', opSub],
    ['K', '0', '000', opAdd],
    ['C', '00', 'back', '='],
  ];

  static _KeyKind _kind(String k) {
    if (operators.contains(k)) return _KeyKind.op;
    return switch (k) {
      'K' => _KeyKind.k,
      '=' => _KeyKind.eq,
      'C' => _KeyKind.clear,
      'back' => _KeyKind.back,
      '00' || '000' => _KeyKind.small,
      _ => _KeyKind.num,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (i, row) in _rows.indexed) ...[
          if (i > 0) const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: [
                for (final (j, k) in row.indexed) ...[
                  if (j > 0) const SizedBox(width: 8),
                  Expanded(child: _Key(k, _kind(k))),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Key extends StatelessWidget {
  const _Key(this.k, this.kind);
  final String k;
  final _KeyKind kind;

  static const _names = {
    'K': '천 단위, 000 붙이기',
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
      _KeyKind.k => (p.kBg, p.kFg),
      _KeyKind.eq => (p.navy, p.onNavy),
      _KeyKind.clear => (p.surface, p.danger),
      _ => (p.surface, p.ink),
    };
    final double size = switch (kind) {
      _KeyKind.small => 21,
      _KeyKind.k || _KeyKind.clear => 22,
      _KeyKind.op || _KeyKind.eq => 28,
      _ => 26,
    };
    final child = kind == _KeyKind.back
        ? Icon(Icons.backspace_outlined, color: fg, size: 24)
        : Text(
            k,
            style: TextStyle(
              fontSize: size,
              fontWeight: kind == _KeyKind.k || kind == _KeyKind.clear
                  ? FontWeight.w800
                  : FontWeight.w500,
              color: fg,
              fontFeatures: tabular,
            ),
          );

    final s = AppScope.read(context);
    return Semantics(
      button: true,
      label: _names[k] ?? k,
      excludeSemantics: true,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            HapticFeedback.selectionClick();
            s.press(k);
          },
          onLongPress: kind == _KeyKind.back ? () => s.press('C') : null,
          child: Center(child: child),
        ),
      ),
    );
  }
}
