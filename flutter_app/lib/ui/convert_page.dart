import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/money.dart';
import '../state/app_state.dart';
import 'common.dart';
import 'guide_page.dart';
import 'teach_dialog.dart';
import 'term_columns.dart';
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
        // 음성 모드: 네모 창이 떠 있고, 버튼을 누르고 있는 동안만 듣는다
        const Positioned.fill(child: _VoicePanel()),
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
              // 아래 가운데에 바꾸기 버튼이 겹치므로 아래 여백을 넉넉히
              final fromH = compact ? 108.0 : 130.0;
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
    // 금액마다 바꾼 금액은 위 숫자 바로 아래에 줄 맞춰 나온다. 여기는 오류만.
    final String sub = v == null ? '0으로 나눌 수 없어요' : '';

    return Panel(
      padding: const EdgeInsets.fromLTRB(18, 10, 10, 26),
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
                child: s.listening
                    // 듣는 중: 들리는 말을 그대로 보여준다
                    ? Align(
                        alignment: Alignment.centerRight,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            s.heard.isEmpty
                                ? '"이십칠만 동"처럼 말해 보세요'
                                : '${s.heard}…',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              color: s.heard.isEmpty ? p.muted : p.ink,
                            ),
                          ),
                        ),
                      )
                    // 위: 넣은 금액, 아래: 항목마다 바꾼 금액 (줄 맞춤)
                    : TermsView(
                        child: TermColumns(
                          expr: s.expr,
                          from: s.from,
                          convert: s.rate == null
                              ? null
                              : (v) => s.convert(v, s.from),
                          topSize: 34,
                          bottomSize: 19,
                          cursor: true,
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
            else if (!s.listening && sub.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  sub,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: v == null
                        ? p.danger
                        : currencyAccent(s.from.other, p),
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
    if (s.voiceMode && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!s.voiceMode && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
    return Semantics(
      button: true,
      label: s.voiceMode ? '음성 입력 멈추기' : '말로 금액 입력하기',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.mediumImpact();
          s.voiceMode ? s.closeVoice() : s.openVoice();
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
                color: s.voiceMode ? p.gold : p.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: s.voiceMode ? p.gold : p.line),
                boxShadow: s.voiceMode
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
                    s.voiceMode ? Icons.mic_rounded : Icons.mic_none_rounded,
                    size: 22,
                    color: s.voiceMode ? p.navy : p.ink,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    s.voiceMode ? '음성 모드' : '말로 입력',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: s.voiceMode ? p.navy : p.ink,
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

/// 음성 모드 창 (무전기 방식).
/// 가운데 네모 창에 지금까지의 식과 합계가 크게 보이고,
/// 아래 큰 버튼을 누르고 있는 동안만 듣는다. 떼면 반영.
class _VoicePanel extends StatelessWidget {
  const _VoicePanel();

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final p = context.palette;
    final open = s.voiceMode;
    return IgnorePointer(
      ignoring: !open,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: open ? 1 : 0,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: s.closeVoice, // 바깥 누르면 닫힘
          child: Container(
            color: Colors.black.withValues(alpha: 0.55),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AnimatedScale(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              scale: open ? 1 : 0.85,
              child: GestureDetector(
                onTap: () {}, // 창 안쪽은 닫히지 않게
                child: _panelCard(context, s, p),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _panelCard(BuildContext context, AppState s, Palette p) {
    final total = s.inputValue;
    final r = s.resultValue;
    final endsWithOp =
        s.expr.isNotEmpty && operators.contains(s.expr[s.expr.length - 1]);

    // 가운데 큰 글자: 듣는 중이면 들리는 말, 아니면 마지막으로 반영한 내용
    final String big;
    final bool bigMuted;
    if (s.listening && s.preview != null) {
      // 말하는 중에도 알아들은 숫자를 바로 보여준다
      big = s.preview!;
      bigMuted = false;
    } else if (s.listening) {
      big = s.heard.isNotEmpty
          ? '${s.heard}…'
          : (s.voiceReady ? '말하세요' : '준비 중…');
      bigMuted = s.heard.isEmpty;
    } else if (s.notice != null) {
      big = s.notice!.headline;
      bigMuted = false;
    } else {
      big = '버튼을 누른 채로 말하세요';
      bigMuted = true;
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 440),
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 22),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: s.listening ? p.gold : p.line, width: 2),
        boxShadow: [
          if (s.listening)
            BoxShadow(color: p.gold.withValues(alpha: 0.35), blurRadius: 30),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              FlagIcon(s.from, size: 22),
              const SizedBox(width: 8),
              Text(
                '${s.from.name}으로 계산',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: p.ink,
                ),
              ),
              const SizedBox(width: 8),
              if (s.addMode)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: p.gold.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '+ 더하기 모드',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: p.goldText,
                    ),
                  ),
                ),
              const Spacer(),
              IconButton(
                tooltip: '음성 입력 규칙',
                onPressed: () => GuidePage.open(context, voiceFirst: true),
                icon: Icon(Icons.help_outline_rounded, color: p.muted),
              ),
              IconButton(
                tooltip: '닫기',
                onPressed: s.closeVoice,
                icon: Icon(Icons.close_rounded, color: p.muted),
              ),
            ],
          ),
          // 지우기 버튼: 말로 "지워"/"다 지워"와 같다
          Row(
            children: [
              _PanelPill(
                icon: Icons.delete_outline_rounded,
                label: '전체 지우기',
                danger: true,
                onTap: s.expr.isEmpty || s.listening
                    ? null
                    : () {
                        final before = s.voiceClearAll();
                        HapticFeedback.mediumImpact();
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(
                              content: const Text('전부 지웠어요'),
                              duration: const Duration(seconds: 2),
                              action: SnackBarAction(
                                label: '되돌리기',
                                onPressed: () => s.restoreExpr(before),
                              ),
                            ),
                          );
                      },
              ),
              const Spacer(),
              _PanelPill(
                icon: Icons.undo_rounded,
                label: '하나 지우기',
                onTap: s.expr.isEmpty || s.listening ? null : s.voiceDeleteOne,
              ),
            ],
          ),
          // 듣는 중: 폰이 들은 말 그대로 (작게)
          SizedBox(
            height: 22,
            child: s.listening && s.preview != null && s.heard.isNotEmpty
                ? Text(
                    '"${s.heard}"',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: p.muted),
                  )
                : null,
          ),
          // 큰 글자: 바뀔 때마다 확대되듯 튀어나온다
          SizedBox(
            height: 48,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                transitionBuilder: (child, a) => FadeTransition(
                  opacity: a,
                  child: ScaleTransition(
                    scale: Tween(
                      begin: 0.6,
                      end: 1.0,
                    ).chain(CurveTween(curve: Curves.easeOutBack)).animate(a),
                    child: child,
                  ),
                ),
                child: FittedBox(
                  // 듣는 중 숫자가 바뀔 때마다, 손을 뗀 뒤 확정될 때마다 튀어나옴
                  key: ValueKey(
                    s.listening ? 'L|${s.preview}' : 'N|${s.notice?.id}',
                  ),
                  fit: BoxFit.scaleDown,
                  child: Text(
                    big,
                    style: TextStyle(
                      fontSize: bigMuted ? 20 : 36,
                      fontWeight: FontWeight.w800,
                      letterSpacing: bigMuted ? -0.5 : -1.5,
                      color: bigMuted ? p.muted : p.ink,
                      fontFeatures: tabular,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 위: 동, 아래: 원. 금액마다 줄 맞춰서, 방금 말한 것은 금색 바탕
          SizedBox(
            height: 84,
            child: s.expr.isEmpty
                ? null
                : TermsView(
                    maxBeforeScroll: 4,
                    alignment: Alignment.center,
                    child: TermColumns(
                      expr: s.expr,
                      from: s.from,
                      convert: s.rate == null
                          ? null
                          : (v) => s.convert(v, s.from),
                      topSize: 26,
                      bottomSize: 23,
                      highlightLast: true,
                      total: hasOperator(s.expr) && !endsWithOp && total != null
                          ? (total, r)
                          : null,
                    ),
                  ),
          ),
          const SizedBox(height: 20),
          const _TalkButton(),
          const SizedBox(height: 12),
          if (!s.listening && s.lastHeardRaw.isNotEmpty)
            TextButton.icon(
              onPressed: () async {
                final heard = s.lastHeardRaw;
                final n = await askOriginalNumber(context, heard);
                if (n == null) return;
                s.teach(heard, n);
                if (context.mounted) {
                  toast(context, '"$heard" → ${fmt(int.parse(n))} 으로 기억할게요');
                }
              },
              icon: const Icon(Icons.school_outlined, size: 18),
              label: const Text('틀렸어요 · 고쳐서 기억하기'),
            ),
          if (!s.listening && s.voiceProblem != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                s.voiceProblem!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: p.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Text(
            s.listening
                ? (s.voiceReady ? '듣는 중 · 다 말한 뒤 손을 떼세요' : '잠깐만요… 진동이 오면 말하세요')
                : '누르고 있는 동안 들어요 · "지워", "얼마"도 돼요',
            style: TextStyle(
              fontSize: 13,
              color: s.listening ? p.goldText : p.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// 누르고 있는 동안만 듣는 큰 버튼. 듣는 동안 둘레가 숨 쉬듯 퍼진다.
class _TalkButton extends StatefulWidget {
  const _TalkButton();

  @override
  State<_TalkButton> createState() => _TalkButtonState();
}

class _TalkButtonState extends State<_TalkButton>
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
      _pulse
        ..stop()
        ..value = 0;
    }
    return Semantics(
      button: true,
      label: '누르고 있는 동안 말하기',
      excludeSemantics: true,
      child: Listener(
        onPointerDown: (_) {
          HapticFeedback.selectionClick();
          s.pressTalk((m) => toast(context, m));
        },
        onPointerUp: (_) => s.releaseTalk(),
        onPointerCancel: (_) => s.releaseTalk(),
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, _) {
            final t = Curves.easeInOut.transform(_pulse.value);
            return SizedBox(
              width: 120,
              height: 120,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (s.listening)
                    Container(
                      width: 92 + 28 * t,
                      height: 92 + 28 * t,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: p.gold.withValues(alpha: 0.30 * (1 - t) + 0.08),
                      ),
                    ),
                  AnimatedScale(
                    duration: const Duration(milliseconds: 120),
                    scale: s.listening ? 0.94 : 1,
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: s.listening ? p.gold : p.navy,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.mic_rounded,
                        size: 40,
                        color: s.listening ? p.navy : Colors.white,
                      ),
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


/// 수식의 항목마다 바꾼 금액: "50000+30000" → "2,632 + 1,579" (항목이 min개보다 적으면 null)
String? convertedTerms(AppState s, {int min = 2}) {
  if (s.rate == null) return null;
  final t = exprTerms(s.expr);
  if (t.isEmpty || t.length < min) return null;
  final b = StringBuffer();
  for (var i = 0; i < t.length; i++) {
    final (sign, v) = t[i];
    if (i > 0 || sign == opSub) b.write(i == 0 ? '$sign ' : ' $sign ');
    b.write(v == null ? '—' : fmt(s.convert(v, s.from)));
  }
  return b.toString();
}


/// 음성 창 위쪽의 작은 알약 버튼. 누를 수 없으면 흐리게.
class _PanelPill extends StatelessWidget {
  const _PanelPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = danger ? p.danger : p.ink;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 160),
      opacity: onTap == null ? 0.35 : 1,
      child: Material(
        color: color.withValues(alpha: 0.08),
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onTap!();
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 17, color: color),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
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
