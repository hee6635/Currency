import 'package:flutter/material.dart';

import 'theme.dart';

/// 사용 설명서. [voiceFirst]면 음성 입력 부분으로 바로 내려간다.
class GuidePage extends StatefulWidget {
  const GuidePage({super.key, this.voiceFirst = false});
  final bool voiceFirst;

  static Future<void> open(BuildContext context, {bool voiceFirst = false}) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => GuidePage(voiceFirst: voiceFirst),
        ),
      );

  @override
  State<GuidePage> createState() => _GuidePageState();
}

class _GuidePageState extends State<GuidePage> {
  final _voiceKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.voiceFirst) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _voiceKey.currentContext;
        if (ctx != null) Scrollable.ensureVisible(ctx);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(
        title: const Text('사용 설명서'),
        backgroundColor: p.bg,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 2),
              child: Text(
                '궁금한 줄을 누르면 자세히 펼쳐져요.',
                style: TextStyle(fontSize: 14, color: p.muted),
              ),
            ),
            const _Section(
              icon: Icons.calculate_outlined,
              title: '환산',
              summary: '숫자를 누르면 바로 원화',
              lines: [
                '입력한 금액마다 바로 아래에 원화가 나와요. 합계는 아래 결과 카드에.',
                '입력한 금액을 누르면 그 금액만 고쳐요. 빈 곳을 누르면 다시 맨 끝.',
                '⇅ 나 국기 버튼: 동 ↔ 원 바꾸기.',
                '결과 카드를 누르면 복사, 📋 는 복사한 금액 붙여넣기.',
                'C 전부 지우기 · ⌫ 한 글자 지우기.',
              ],
            ),
            _Section(
              key: _voiceKey,
              initiallyOpen: widget.voiceFirst,
              icon: Icons.mic_none_rounded,
              title: '말로 입력',
              summary: '버튼이나 음량 ↓ 를 누른 채로 말하기',
              lines: const [
                '"말로 입력" → 큰 마이크를 누른 채로 말하고 떼면 들어가요.',
                '음량 ↓ 를 누른 채로 말해도 돼요. 환산 화면이면 바로 들어요.',
                '음량 ↑ 는 하나 지우기.',
                '숫자만 이어서 말하면 더해요 ("오만" → "삼만").',
                '틀리면 "틀렸어요 · 고쳐서 기억하기"로 알려 주세요.',
              ],
              table: const [
                ('오만 · 27만 5천 · 50K', '숫자'),
                ('더하기 · 빼기 · 곱하기 · 나누기', '+ − × ÷'),
                ('지워', '하나 지우기'),
                ('다 지워 · 새로', '전부 지우기'),
              ],
            ),
            const _Section(
              icon: Icons.widgets_outlined,
              title: '홈 화면에서 바로',
              summary: '위젯 · 측면 버튼으로 바로 말하기',
              steps: [
                (
                  '위젯 놓기',
                  ['홈 화면 빈 곳을 길게 누르기', '위젯 → 베트남 환율', '긴 것이나 네모를 골라 놓기'],
                ),
                (
                  '측면 버튼 두 번 누르기로 열기',
                  [
                    '설정 → 유용한 기능 → 측면 버튼 → 두 번 누르기',
                    '모드 및 루틴 → ⚙ → 루틴 추가',
                    '동작 → 앱 → 앱 동작 실행 → 베트남 환율 → 말로 입력',
                    '저장',
                  ],
                ),
              ],
              lines: [
                '창이 뜨면 음량 ↓ 를 누른 채로 말하면 돼요.',
                '"앱으로 이동"을 누르면 하던 계산을 앱에서 이어서 해요.',
                '앱 아이콘을 길게 눌러도 "말로 입력"이 있어요.',
              ],
            ),
            const _Section(
              icon: Icons.history_rounded,
              title: '최근 계산 🕘',
              summary: '지운 계산 5개 다시 불러오기',
              lines: [
                '지우거나 앱을 닫으면 하던 계산이 남아요 (최근 5개).',
                '입력 칸 위 🕘 → 누르면 불러와서 이어서 계산해요.',
              ],
            ),
            const _Section(
              icon: Icons.currency_exchange_rounded,
              title: '환율과 설정',
              summary: '왼쪽 위 환율 버튼',
              lines: [
                '환율은 하루 1번 갱신되는 시장 중간값이에요.',
                '"직접 입력"으로 환전소 환율을 쓸 수 있어요.',
                '수수료 반영, 더하기 모드도 여기서 켜고 꺼요.',
              ],
            ),
            const _Section(
              icon: Icons.apps_rounded,
              title: '다른 탭',
              summary: '환산표 · 지폐 · 보여주기 · 메모',
              lines: [
                '지폐: + / − 로 장수를 세면 합계가 나와요. 사진을 누르면 크게.',
                '보여주기: 누르면 베트남어 문장이 크게 떠요.',
                '메모: 쓰면 자동 저장.',
              ],
            ),
            const _Section(
              icon: Icons.tune_rounded,
              title: '음성 인식 고치기',
              summary: '잘못 알아들을 때',
              lines: [
                '말한 내용은 설정 → "음성 기록"에 남아요.',
                '☁ 로 올리면 4시간 안에 자동으로 고쳐져요 (앱 다시 켜면 적용).',
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatefulWidget {
  const _Section({
    super.key,
    required this.icon,
    required this.title,
    required this.summary,
    this.lines = const [],
    this.steps = const [],
    this.table = const [],
    this.initiallyOpen = false,
  });

  final IconData icon;
  final String title;

  /// 접혀 있을 때 보이는 한 줄
  final String summary;
  final List<String> lines;

  /// 번호 붙은 따라하기 (제목, 단계들)
  final List<(String, List<String>)> steps;
  final List<(String, String)> table;
  final bool initiallyOpen;

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final w = widget;
    final body = TextStyle(fontSize: 15, height: 1.5, color: p.ink);
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _open ? p.gold : p.line),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(w.icon, size: 22, color: p.goldText),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            w.title,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: p.ink,
                            ),
                          ),
                          Text(
                            w.summary,
                            style: TextStyle(fontSize: 13.5, color: p.muted),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.expand_more_rounded, color: p.muted),
                    ),
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: !_open
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: 12, right: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final (t, items) in w.steps) ...[
                                Text(
                                  t,
                                  style: body.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: p.goldText,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                for (final (n, item) in items.indexed)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 3),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        SizedBox(
                                          width: 22,
                                          child: Text(
                                            '${n + 1}.',
                                            style: body.copyWith(
                                              color: p.muted,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(item, style: body),
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 10),
                              ],
                              for (final l in w.lines)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '•  ',
                                        style: body.copyWith(color: p.muted),
                                      ),
                                      Expanded(child: Text(l, style: body)),
                                    ],
                                  ),
                                ),
                              if (w.table.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: p.line),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      for (final (i, (say, does))
                                          in w.table.indexed)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 9,
                                          ),
                                          decoration: BoxDecoration(
                                            border: i == 0
                                                ? null
                                                : Border(
                                                    top: BorderSide(
                                                      color: p.line,
                                                    ),
                                                  ),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                flex: 6,
                                                child: Text(
                                                  say,
                                                  style: body.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                flex: 4,
                                                child: Text(
                                                  does,
                                                  textAlign: TextAlign.right,
                                                  style: body.copyWith(
                                                    color: p.muted,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
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
