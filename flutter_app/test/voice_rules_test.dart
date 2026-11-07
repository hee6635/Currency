import 'package:flutter_test/flutter_test.dart';
import 'package:vn_currency/core/money.dart';
import 'package:vn_currency/core/voice_rules.dart';

void main() {
  tearDown(() {
    spokenExtraFixes = [];
    spokenPhrases = {};
  });

  test('규칙 파일 읽기: 잘못된 항목은 건너뜀', () {
    final r = VoiceRules.parse('''
      {"version": 3,
       "fixes": [{"from": "삼촌", "to": "삼천"}, {"from": "(", "to": "x"}, {"oops": 1}],
       "phrases": {"오 만 동": "50000"},
       "timing": {"releaseDelayMs": 99999}}''')!;
    expect(r.version, 3);
    expect(r.fixes.length, 1);
    expect(r.phrases['오만동'], '50000');
    expect(r.releaseDelayMs, 5000); // 최대값으로 제한
    expect(VoiceRules.parse('not json'), isNull);
  });

  test('받아온 규칙과 가르친 말이 음성 해석에 바로 적용', () {
    expect(applySpoken('', '쌈만', addMode: true).expr, '10000'); // 보정 전: 틀림
    spokenExtraFixes = [(RegExp('쌈만'), '삼만')];
    expect(applySpoken('', '쌈만', addMode: true).expr, '30000');

    spokenPhrases = {'이촌동': '2000'};
    expect(applySpoken('', '이 촌 동', addMode: true).expr, '2000');
    expect(applySpoken('', '이촌동 더하기 오만', addMode: true).expr, '2000+50000');
  });
}
