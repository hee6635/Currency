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
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Section(
              icon: Icons.calculate_outlined,
              title: '환산',
              lines: [
                '키패드로 금액을 누르면 아래 카드에 바로 바뀐 금액이 나와요.',
                '00, 000 키로 0을 한 번에 입력해요.',
                '+ − × ÷ 로 계산하고, = 를 누르면 하나로 합쳐요.',
                '결과 카드를 누르면 금액이 복사돼요.',
                '입력 카드의 📋 버튼: 복사해 둔 금액(예: 50,000đ, 50K)을 붙여넣어요.',
                'C 는 전부 지우기, ⌫ 는 한 글자 지우기 (길게 누르면 전부).',
                '입력 칸에는 금액마다 바로 아래에 원화가 나오고, 결과 카드 왼쪽 아래에 동 합계가 나와요.',
                '입력 칸의 금액을 누르면 그 금액을 고쳐요 (⌫·숫자가 그 금액에). 빈 곳을 누르면 다시 맨 끝.',
                '🕘 최근 계산: 지운 계산과 앱을 닫을 때 하던 계산이 최근 5개까지 남아요. 누르면 불러와서 이어서 계산해요.',
              ],
            ),
            const _Section(
              icon: Icons.swap_vert_rounded,
              title: '방향 바꾸기 (동 ↔ 원)',
              lines: [
                '키패드 맨 위 국기 버튼이나 두 카드 사이 ⇅ 버튼을 누르면 바뀌어요.',
                '국기 버튼에는 지금 입력하는 통화의 국기가 보여요.',
                '결과 카드 색: 원으로 바꿀 때 남색, 동으로 바꿀 때 빨강.',
              ],
            ),
            _Section(
              key: _voiceKey,
              icon: Icons.mic_none_rounded,
              title: '음성 입력 (무전기 방식)',
              lines: const [
                '위쪽 "말로 입력"을 누르면 음성 창이 열려요.',
                '큰 마이크 버튼을 누른 채로, 진동이 온 뒤 말하고, 손을 떼면 입력돼요 (뗀 뒤 1초쯤 마저 들어요).',
                '말한 숫자는 남아 있어요. 다시 누르고 이어서 말하면 이어 붙어요.',
                '지금 입력 칸의 통화로 계산해요 ("원", "동"은 말해도 무시).',
                '폰의 음량 ↓ 버튼을 누르고 있어도 똑같이 들어요. 환산 화면에서는 음성 창을 안 열어도 바로 돼요.',
                '음성 창이 떠 있을 때 음량 ↑ 버튼은 "하나 지우기"예요.',
                'X 나 창 바깥을 누르면 닫혀요.',
                '말할 때마다(못 알아들은 것도) 설정 → "음성 기록"에 남아요. "백업"으로 파일을 보내면 앱 안 기록은 비워져요.',
                '틀리면 음성 창의 "틀렸어요 · 고쳐서 기억하기"(또는 기록을 누르기)로 원래 숫자를 알려주세요. 이 폰에서는 바로 맞게 처리돼요.',
                '음성 기록의 ☁ 버튼으로 GitHub에 기록을 올리면, 4시간마다 AI가 보고 보정 규칙을 고쳐요. 고친 규칙은 앱을 다시 켜면 적용돼요 (재설치 필요 없음).',
              ],
              table: const [
                ('오만 · 27만 5천 · 삼백만 · 50K', '숫자 입력'),
                ('더하기 · 플러스', '+'),
                ('빼기 · 마이너스', '−'),
                ('곱하기', '×'),
                ('나누기', '÷'),
                ('지워', '마지막 하나 지우기 (숫자 하나 또는 연산 하나)'),
                ('다 지워 · 새로', '전부 지우기'),
                ('얼마 · 결과', '계산해서 하나로 (= 와 같음)'),
              ],
              examples: const [
                '"오만" → 떼기 → "더하기 삼만" → 떼기  ⇒  50,000 + 30,000',
                '"7 더하기 3 곱하기 10 더하기 5" → "지워"  ⇒  7 + 3 × 10 +',
                '"삼만 곱하기 사 얼마"  ⇒  120,000',
              ],
            ),
            const _Section(
              icon: Icons.widgets_outlined,
              title: '홈 화면에서 바로 말하기',
              lines: [
                '위젯: 홈 화면을 길게 누르기 → 위젯 → "베트남 환율"에서 긴 것(4×1)이나 네모(2×2)를 놓으세요. 환율이 보이고, 누르면 바로 음성 창이 떠요.',
                '측면 버튼: 두 번 누르기 → 모드 및 루틴 → 동작에 "앱 동작 실행 → 베트남 환율 → 말로 입력"을 넣으면 두 번 누를 때 바로 음성 창이 떠요.',
                '그다음 음량 ↓ 를 누른 채로 말하고 떼면 입력돼요. 음량 ↑ 는 하나 지우기. 화면을 안 봐도 돼요.',
                '앱 아이콘을 길게 눌러도 "말로 입력"이 있어요.',
                '음성 창의 "앱으로 이동"을 누르면 하던 계산을 앱에서 이어서 해요. 닫으면 하던 계산은 최근 계산(🕘)에 남아요.',
                '위젯의 환율은 앱이 마지막으로 받은 값이에요. 앱을 하루 한 번쯤 열면 새로 바뀌어요.',
              ],
            ),
            const _Section(
              icon: Icons.add_circle_outline_rounded,
              title: '더하기 모드',
              lines: [
                '설정에서 켜고 끌 수 있어요 (처음엔 켜져 있음).',
                '켜면: 숫자만 이어서 말해도 더해요. "오만" → "삼만" ⇒ 50,000 + 30,000',
                '끄면: 숫자 뒤에 숫자를 말하면 "연산을 같이 말해 주세요" 안내만 떠요.',
                '켜져 있으면 음성 창에 "+ 더하기 모드"가 보여요.',
              ],
            ),
            const _Section(
              icon: Icons.currency_exchange_rounded,
              title: '환율과 설정',
              lines: [
                '왼쪽 위 환율 버튼을 누르면 환율과 설정 창이 열려요.',
                '환율은 하루 1번 갱신되는 시장 중간값이에요 (ExchangeRate-API).',
                '"직접 입력"으로 환전소 환율을 그대로 쓸 수 있어요.',
                '"환전 수수료 반영"을 켜면 실제로 받을 금액에 가까운 값도 보여줘요.',
                '인터넷이 없으면 마지막으로 받은 환율을 그대로 써요.',
              ],
            ),
            const _Section(
              icon: Icons.payments_outlined,
              title: '지폐 세기',
              lines: [
                '지폐별로 + / − 를 눌러 장수를 세면 합계와 원화 금액이 나와요.',
                '지폐 사진을 누르면 앞면과 뒷면을 크게 보여줘요.',
                '2만동과 50만동은 색이 비슷하니 조심하세요.',
              ],
            ),
            const _Section(
              icon: Icons.forum_outlined,
              title: '보여주기',
              lines: [
                '카드를 누르면 베트남어 문장이 화면 가득 크게 떠요. 직원에게 보여주세요.',
                '화면을 누르면 닫혀요.',
              ],
            ),
            const _Section(
              icon: Icons.sticky_note_2_outlined,
              title: '메모',
              lines: ['입력하면 자동으로 저장돼요.'],
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    super.key,
    required this.icon,
    required this.title,
    required this.lines,
    this.table = const [],
    this.examples = const [],
  });

  final IconData icon;
  final String title;
  final List<String> lines;
  final List<(String, String)> table;
  final List<String> examples;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final body = TextStyle(fontSize: 15, height: 1.55, color: p.ink);
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: p.goldText),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: p.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: body.copyWith(color: p.muted)),
                  Expanded(child: Text(l, style: body)),
                ],
              ),
            ),
          if (table.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: p.line),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  for (final (i, (say, does)) in table.indexed)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        border: i == 0
                            ? null
                            : Border(top: BorderSide(color: p.line)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: Text(
                              say,
                              style: body.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 6,
                            child: Text(
                              does,
                              style: body.copyWith(color: p.muted),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (examples.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '예시',
              style: body.copyWith(
                fontWeight: FontWeight.w800,
                color: p.goldText,
              ),
            ),
            for (final e in examples)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(e, style: body.copyWith(fontSize: 14)),
              ),
          ],
        ],
      ),
    );
  }
}
