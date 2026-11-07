import 'dart:math' as math;

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
    return Stack(
      children: [
        _convertBody(),
        // 말로 입력한 뒤 3초 동안 크게 보여주는 확인 화면
        const Positioned.fill(child: _VoiceNoticeOverlay()),
      ],
    );
  }

  Widget _convertBody() {
    return Column(
      children: [
        // 제목 없이: 왼쪽 환율, 오른쪽 음성 입력
        const Padding(
          padding: EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Row(children: [RateChip(), Spacer(), _MicButton()]),
        ),
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
      glow: s.listening ? p.gold : null,
      child: _SwapSlide(
        value: s.from,
        fromBelow: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CardLabel(
              s.from,
              onNavy: false,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: '금액 붙여넣기',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.content_paste_rounded,
                      size: 20,
                      color: p.muted,
                    ),
                    onPressed: () async {
                      final data = await Clipboard.getData(
                        Clipboard.kTextPlain,
                      );
                      if (!context.mounted) return;
                      final ok = s.pasteAmount(data?.text ?? '');
                      if (!ok) toast(context, '복사한 내용에 금액이 없어요');
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: s.listening
                        // 듣는 중: 들리는 말을 그대로 보여준다
                        ? Text(
                            s.heard.isEmpty
                                ? '"이십칠만 동"처럼 말해 보세요'
                                : '${s.heard}…',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              color: s.heard.isEmpty ? p.muted : p.ink,
                            ),
                          )
                        : AnimatedNumberText(
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
            if (s.listening && s.addMode)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(Icons.add_circle_rounded, size: 15, color: p.gold),
                    const SizedBox(width: 4),
                    Text(
                      '더하기 모드',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: p.goldText,
                      ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  s.listening ? '' : sub,
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

/// 마이크 버튼: 듣는 중에는 금색으로 채워지고 둘레가 숨 쉬듯 퍼진다.
class _MicButton extends StatefulWidget {
  const _MicButton();

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = context.palette;
    if (s.listening && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!s.listening && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
    return Semantics(
      button: true,
      label: s.listening ? '음성 입력 멈추기' : '말로 금액 입력하기',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.mediumImpact();
          s.toggleVoice((m) => toast(context, m));
        },
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            final t = Curves.easeInOut.transform(_pulse.value);
            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: 44,
              padding: const EdgeInsets.fromLTRB(12, 0, 16, 0),
              decoration: BoxDecoration(
                color: s.listening ? p.gold : p.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: s.listening ? p.gold : p.line),
                boxShadow: s.listening
                    ? [
                        // 듣는 중: 둘레가 숨 쉬듯 퍼진다
                        BoxShadow(
                          color: p.gold.withValues(alpha: 0.45 * (1 - t) + 0.1),
                          blurRadius: 6 + 14 * t,
                          spreadRadius: 1 + 4 * t,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    s.listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                    size: 22,
                    color: s.listening ? p.navy : p.ink,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    s.listening ? '듣는 중' : '말로 입력',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: s.listening ? p.navy : p.ink,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 말로 입력한 내용을 화면 가운데에 크게 띄웠다가, 3초 뒤 입력 카드 쪽으로
/// 작아지며 사라진다. 누르면 바로 닫힌다.
class _VoiceNoticeOverlay extends StatelessWidget {
  const _VoiceNoticeOverlay();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = context.palette;
    final n = s.notice;
    final total = s.inputValue;
    final r = s.resultValue;
    final summary = n == null
        ? ''
        : [
            if (s.expr.isNotEmpty &&
                operators.contains(s.expr[s.expr.length - 1]))
              '${prettyExpr(s.expr)} …'
            else if (hasOperator(s.expr))
              '${prettyExpr(s.expr)} = ${total == null ? '—' : fmt(total)}${s.from.unit}'
            else if (s.expr.isNotEmpty)
              '${prettyExpr(s.expr)}${s.from.unit}',
            if (r != null && s.expr.isNotEmpty)
              '≈ ${fmt(r)}${s.from.other.unit}',
          ].join('\n');

    return IgnorePointer(
      ignoring: n == null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: s.dismissNotice,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          color: Colors.black.withValues(alpha: n == null ? 0 : 0.45),
          alignment: Alignment.center,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 380),
            reverseDuration: const Duration(milliseconds: 420),
            transitionBuilder: (child, a) {
              final entering = child.key == ValueKey(n?.id);
              if (entering) {
                // 확대되듯 튀어나옴
                return FadeTransition(
                  opacity: a,
                  child: ScaleTransition(
                    scale: Tween(
                      begin: 0.55,
                      end: 1.0,
                    ).chain(CurveTween(curve: Curves.easeOutBack)).animate(a),
                    child: child,
                  ),
                );
              }
              // 입력 카드 쪽(위)으로 작아지며 들어감
              return FadeTransition(
                opacity: a,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, -1.6),
                    end: Offset.zero,
                  ).chain(CurveTween(curve: Curves.easeInCubic)).animate(a),
                  child: ScaleTransition(
                    scale: Tween(begin: 0.3, end: 1.0).animate(a),
                    child: child,
                  ),
                ),
              );
            },
            child: n == null
                ? const SizedBox.shrink(key: ValueKey('none'))
                : Container(
                    key: ValueKey(n.id),
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.fromLTRB(28, 24, 28, 22),
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: p.gold, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: p.gold.withValues(alpha: 0.35),
                          blurRadius: 30,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            n.headline,
                            style: TextStyle(
                              fontSize: 54,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.5,
                              color: p.ink,
                              fontFeatures: tabular,
                            ),
                          ),
                        ),
                        if (summary.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            summary,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color: p.muted,
                              fontFeatures: tabular,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
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

  // 갤럭시 계산기처럼 지우기 키는 맨 위 줄 (= 이나 0 누를 때 잘못 누르지 않게).
  // 'swap' 자리(갤럭시의 %)는 국기 버튼: 누르면 동 ↔ 원 방향을 바꾼다.
  static const _rows = [
    ['C', 'back', 'swap', opDiv],
    ['7', '8', '9', opMul],
    ['4', '5', '6', opSub],
    ['1', '2', '3', opAdd],
    ['00', '0', '000', '='],
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
    // 갤럭시 계산기 비율.
    // 폰: 버튼은 완전한 원, 가로 간격 ≈ 지름의 1/5, 세로 간격 ≈ 지름의 1/3.
    // 폴드처럼 넓은 화면: 버튼을 가로로 긴 알약 모양으로 늘리고 양옆에 여백을 둔다.
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth, h = box.maxHeight;
        final rows = _rows.length;
        final d = math.min(w / (4 + 3 * 0.2), h / (rows + (rows - 1) * 0.32));
        final vGap = ((h - rows * d) / (rows - 1)).clamp(6.0, d * 0.45);
        final wide = (w - 3 * 0.2 * d) / 4 > d * 1.3;
        final keyW = wide
            ? math.min((w * 0.88 - 3 * 0.4 * d) / 4, d * 1.75)
            : d;
        final hGap = wide ? d * 0.4 : (w - 4 * d) / 3;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final (i, row) in _rows.indexed) ...[
              if (i > 0) SizedBox(height: vGap),
              SizedBox(
                height: d,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final (j, k) in row.indexed) ...[
                      if (j > 0) SizedBox(width: hGap),
                      SizedBox(
                        width: keyW,
                        height: d,
                        child: k == 'swap'
                            ? const _FlagSwapKey()
                            : _Key(k, _kind(k)),
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

/// = 버튼 색: 결과 카드(바꿀 통화)의 색을 따라간다
Color _eqColor(BuildContext context) {
  final s = AppScope.of(context);
  final c = currencyGradient(
    s.from.other,
    context.palette,
    Theme.of(context).brightness,
  );
  return Color.lerp(c.first, c.last, 0.55)!;
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
      _KeyKind.eq => (_eqColor(context), p.onNavy),
      _KeyKind.clear || _KeyKind.back => (p.surface, p.danger),
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
      _KeyKind.clear || _KeyKind.back => p.danger,
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

/// 키패드의 국기 버튼: 지금 입력하는 통화의 국기가 앞에 크게, 다른 통화 국기는 뒤에 작게.
/// 누르면 두 국기가 자리를 바꾸며 동 ↔ 원 방향이 바뀐다 (위쪽 바꾸기 버튼과 같은 동작).
class _FlagSwapKey extends StatelessWidget {
  const _FlagSwapKey();

  /// inset(테두리 안쪽 국기, 기본) / fill(꽉 찬 국기) / pair / badge / text("동→원")
  static const style = String.fromEnvironment(
    'FLAG_STYLE',
    defaultValue: 'inset',
  );

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = context.palette;
    return Semantics(
      button: true,
      label: '통화 바꾸기, 지금 ${s.from.name}에서 ${s.from.other.name}로',
      excludeSemantics: true,
      child: PressableKey(
        color: style == 'text' ? p.kBg : p.surface,
        highlight: p.gold,
        onTap: () {
          HapticFeedback.mediumImpact();
          s.swap();
        },
        child: switch (style) {
          'fill' => _fill(s.from),
          'inset' => Padding(
            // 버튼 테두리를 남기고 안쪽에만 국기
            padding: const EdgeInsets.all(7),
            child: _fill(s.from),
          ),
          'pair' => _pair(s.from),
          'badge' => _badge(s.from, p),
          _ => _text(s.from, p),
        },
      ),
    );
  }

  static const _dur = Duration(milliseconds: 320);

  // 버튼을 꽉 채운 국기. 누르면 지금 국기는 안쪽으로 물러나며 작아지고,
  // 다른 국기가 위에서 미끄러져 내려와 버튼을 채운다.
  Widget _fill(Currency from) => ClipRRect(
    borderRadius: BorderRadius.circular(999),
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 460),
      reverseDuration: const Duration(milliseconds: 460),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) =>
          Stack(fit: StackFit.expand, children: [...previous, ?current]),
      transitionBuilder: (child, a) {
        if (child.key == ValueKey(from)) {
          // 들어오는 국기: 위에서 아래로
          return SlideTransition(
            position: Tween(
              begin: const Offset(0, -1),
              end: Offset.zero,
            ).animate(a),
            child: child,
          );
        }
        // 나가는 국기: 뒤로 물러나듯 작아지고 어두워짐
        return ScaleTransition(
          scale: Tween(begin: 0.6, end: 1.0).animate(a),
          child: FadeTransition(
            opacity: Tween(begin: 0.25, end: 1.0).animate(a),
            child: child,
          ),
        );
      },
      child: ClipRRect(
        key: ValueKey(from),
        borderRadius: BorderRadius.circular(999),
        child: FlagFill(from),
      ),
    ),
  );

  Widget _ringed(Currency c, double size) => Container(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 2),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.2),
          blurRadius: 5,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: FlagIcon(c, size: size),
  );

  // 국기 두 개: 입력 중인 통화가 앞에 크게
  Widget _pair(Currency from) {
    Widget flag(Currency c) {
      final front = c == from;
      return AnimatedAlign(
        key: ValueKey(c),
        duration: _dur,
        curve: Curves.easeOutBack,
        alignment: front ? const Alignment(-1, 1) : const Alignment(1, -1),
        child: AnimatedScale(
          duration: _dur,
          curve: Curves.easeOutBack,
          scale: front ? 1 : 0.8,
          child: _ringed(c, 28),
        ),
      );
    }

    return SizedBox(
      width: 54,
      height: 46,
      child: Stack(children: [flag(from.other), flag(from)]),
    );
  }

  // 국기 하나 + 오른쪽 아래 작은 바꾸기 표시
  Widget _badge(Currency from, Palette p) => SizedBox(
    width: 48,
    height: 48,
    child: Stack(
      children: [
        Center(
          child: AnimatedSwitcher(
            duration: _dur,
            transitionBuilder: (child, a) => RotationTransition(
              turns: Tween(begin: 0.5, end: 1.0).animate(a),
              child: FadeTransition(opacity: a, child: child),
            ),
            child: KeyedSubtree(key: ValueKey(from), child: _ringed(from, 34)),
          ),
        ),
        Align(
          alignment: Alignment.bottomRight,
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: p.gold,
              shape: BoxShape.circle,
              border: Border.all(color: p.surface, width: 2),
            ),
            child: Icon(Icons.swap_vert_rounded, size: 13, color: p.navy),
          ),
        ),
      ],
    ),
  );

  // 글자로 방향 표시: "동→원"
  Widget _text(Currency from, Palette p) => AnimatedSwitcher(
    duration: _dur,
    transitionBuilder: (child, a) => FadeTransition(
      opacity: a,
      child: ScaleTransition(
        scale: Tween(begin: 0.7, end: 1.0).animate(a),
        child: child,
      ),
    ),
    child: Text(
      '${from.unit}→${from.other.unit}',
      key: ValueKey(from),
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: p.kFg,
        letterSpacing: -0.5,
      ),
    ),
  );
}
