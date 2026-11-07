import 'package:flutter_test/flutter_test.dart';
import 'package:vn_currency/core/money.dart';

String type(List<String> keys) => keys.fold('', applyKey);

void main() {
  group('fmt / koreanUnit', () {
    test('콤마와 반올림', () {
      expect(fmt(0), '0');
      expect(fmt(999), '999');
      expect(fmt(1000), '1,000');
      expect(fmt(1234567.6), '1,234,568');
      expect(fmt(-2500), '-2,500');
    });

    test('1만 미만은 단위 표시 안 함 (숫자와 똑같으니까)', () {
      expect(koreanUnit(8130), '');
      expect(koreanUnit(150000), '15만');
      expect(koreanUnit(1234567), '123만 4,567');
      expect(koreanUnit(250000000), '2억 5,000만');
    });

    test('반올림 단위', () {
      expect(roundTo(8134, 100), 8100);
      expect(roundTo(8150, 100), 8200);
    });
  });

  group('evaluate', () {
    test('곱셈·나눗셈 먼저', () {
      expect(evaluate('2+3×4'), 14);
      expect(evaluate('100−20÷4'), 95);
      expect(evaluate('150000+50000'), 200000);
    });

    test('끝에 남은 연산자는 무시', () {
      expect(evaluate('100+'), 100);
      expect(evaluate(''), 0);
    });

    test('0으로 나누면 null (예전 앱은 여기서 꺼졌음)', () {
      expect(evaluate('5÷0'), isNull);
    });
  });

  group('applyKey', () {
    test('숫자와 묶음 0', () {
      expect(type(['5', '000']), '5000');
      expect(type(['1', '00', 'K']), '100000');
    });

    test('맨 앞 0 무시', () {
      expect(type(['0', '000', '7']), '7');
    });

    test('연산자 연속 입력은 마지막 것으로 교체', () {
      expect(type(['5', opAdd, opMul, '2']), '5×2');
      expect(type([opAdd]), '');
    });

    test('= 은 결과로 바꾸고, 0 나누기나 음수는 비움', () {
      expect(type(['5', '0', opMul, '3', '=']), '150');
      expect(type(['5', opDiv, '0', '=']), '');
      expect(type(['3', opSub, '5', '=']), '');
    });

    test('지우기 — 예전 앱처럼 "Error" 상태에서 꺼지지 않음', () {
      expect(type(['5', opDiv, '0', 'back']), '5÷');
      expect(type(['back', 'back']), '');
      expect(type(['1', '2', 'C']), '');
    });

    test('자릿수 제한 12자리', () {
      final s = type(List.filled(20, '9'));
      expect(s.length, 12);
    });
  });

  group('parsePasted — 붙여넣기 (예전 앱은 여러 글자 붙여넣기를 무시했음)', () {
    test('다양한 형식', () {
      expect(parsePasted('50000'), '50000');
      expect(parsePasted('50,000đ'), '50000');
      expect(parsePasted('Giá: 120.000 VND'), '120000');
      expect(parsePasted('50K'), '50000');
      expect(parsePasted('안녕'), isNull);
    });
  });

  group('parseRate — 예전 앱은 "." 저장 시 다음 실행부터 계속 꺼졌음', () {
    test('잘못된 값 거부', () {
      expect(parseRate('.'), isNull);
      expect(parseRate(''), isNull);
      expect(parseRate('0'), isNull);
      expect(parseRate('-3'), isNull);
      expect(parseRate('18.45'), 18.45);
      expect(parseRate('18,45'), 18.45);
    });
  });

  group('parseSpokenAmount — 음성으로 말한 금액', () {
    int? v(String t) => parseSpokenAmount(t)?.value;
    Currency? c(String t) => parseSpokenAmount(t)?.currency;

    test('한글 숫자', () {
      expect(v('이십칠만 동'), 270000);
      expect(v('오만'), 50000);
      expect(v('만 오천'), 15000);
      expect(v('삼백오십만'), 3500000);
      expect(v('천오백'), 1500);
      expect(v('이억 삼천만'), 230000000);
      expect(v('십오만 원'), 150000);
    });

    test('아라비아 숫자와 섞인 말', () {
      expect(v('27만 동'), 270000);
      expect(v('27만 5천'), 275000);
      expect(v('270,000동'), 270000);
      expect(v('2.5만'), 25000);
      expect(v('50K'), 50000);
      expect(v('50케이'), 50000);
    });

    test('통화 알아듣기', () {
      expect(c('이십칠만 동'), Currency.vnd);
      expect(c('오만 원'), Currency.krw);
      expect(c('27만'), isNull);
    });

    test('숫자가 없으면 null', () {
      expect(parseSpokenAmount('안녕하세요'), isNull);
      expect(parseSpokenAmount(''), isNull);
    });
  });

  group('applySpoken — 음성 규칙', () {
    VoiceStep say(String e, String t, {bool add = true}) =>
        applySpoken(e, t, addMode: add);

    test('처음 말한 숫자는 그대로, 이어서 말하면 이어 붙음', () {
      expect(say('', '오만').expr, '50000');
      expect(say('50000', '더하기 삼만').expr, '50000+30000');
      expect(say('50000+', '삼만').expr, '50000+30000');
      expect(say('', '오만 더하기').expr, '50000+');
      expect(say('50000', '곱하기').expr, '50000×');
      expect(say('50000+', '빼기').expr, '50000−');
    });

    test('네 가지 연산', () {
      expect(say('', '이십만 더하기 오만').expr, '200000+50000');
      expect(say('', '오십만 마이너스 삼만').expr, '500000−30000');
      expect(say('', '삼만 곱하기 사').expr, '30000×4');
      expect(say('', '백만 나누기 4').expr, '1000000÷4');
    });

    test('숫자 뒤에 숫자: 더하기 모드면 더하고, 아니면 안내', () {
      final on = say('50000', '삼만');
      expect(on.expr, '50000+30000');
      expect(on.headline, '+ 30,000');
      final off = say('50000', '삼만', add: false);
      expect(off.expr, '50000');
      expect(off.changed, isFalse);
      expect(off.message, contains('연산'));
    });

    test('지워 / 다 지워', () {
      expect(say('7+3×10+5', '지워').expr, '7+3×10+');
      expect(say('7+3×10+5', '지워').headline, '5 지움');
      expect(say('7+3×10+', '지워').expr, '7+3×10');
      expect(say('7+3×10', '지워 지워').expr, '7+3');
      expect(say('7+3×10', '다 지워').expr, '');
      expect(say('7+3×10', '새로').expr, '');
      expect(say('50000+30000', '지워 오천').expr, '50000+5000');
    });

    test('얼마 / 결과', () {
      final r = say('50000+30000', '얼마');
      expect(r.expr, '80000');
      expect(r.headline, '= 80,000');
      expect(say('', '삼만 곱하기 사 결과').expr, '120000');
    });

    test('원/동은 무시 (방향 안 바꿈)', () {
      expect(say('', '오만 원').expr, '50000');
      expect(say('', '이십칠만 동').expr, '270000');
    });

    test('못 알아들으면 그대로', () {
      final r = say('50000', '안녕하세요');
      expect(r.expr, '50000');
      expect(r.changed, isFalse);
    });
  });

  group('normalizeSpoken — 잘못 알아들은 말 보정', () {
    String say(String t, {String e = ''}) =>
        applySpoken(e, t, addMode: true).expr;

    test('숫자 단위 오인식', () {
      expect(say('이촌동'), '2000');
      expect(say('이촌 동'), '2000');
      expect(say('삼전 원'), '3000');
      expect(say('오망'), '50000');
      expect(say('심만'), '100000');
      expect(say('심오만'), '150000');
      expect(say('빽만'), '1000000');
      expect(say('오 만'), '50000');
      expect(say('이만 오촌'), '25000');
    });

    test('끝말 떼기', () {
      expect(say('오만이요'), '50000');
      expect(say('삼천원이에요'), '3000');
      expect(say('이만이'), '20000');
      expect(say('이십이'), '22');
    });

    test('연산·명령 비슷한 말', () {
      expect(say('삼만 고파기 셋'), '30000×3');
      expect(say('오만 배기 삼천'), '50000−3000');
      expect(say('오만 더 하기 삼천'), '50000+3000');
      expect(say('십만 나눠 4'), '100000÷4');
      expect(say('오만 플러스 삼만 얼마야'), '80000');
      expect(say('치워', e: '50000+3000'), '50000+');
      expect(say('전부 지워', e: '50000+3000'), '');
      expect(say('처음부터', e: '50000'), '');
    });
  });

  test('K(천) 단위: 5K, 오케이, OK, 오십 케이', () {
    String say(String t) => applySpoken('', t, addMode: true).expr;
    expect(say('5K'), '5000');
    expect(say('5k'), '5000');
    expect(say('50K'), '50000');
    expect(say('오케이'), '5000');
    expect(say('오 케이'), '5000');
    expect(say('OK'), '5000');
    expect(say('okay'), '5000');
    expect(say('오십 케이'), '50000');
    expect(say('이십오 케이'), '25000');
    expect(say('백 케이'), '100000');
    expect(say('오만'), '50000');
    expect(say('오만 더하기 5K'), '50000+5000');
  });

  group('음성 기록 55개에서 나온 오인식', () {
    String say(String t, {String e = ''}) =>
        applySpoken(e, t, addMode: true).expr;
    tearDown(() => spokenPhrases = {});

    test('비슷한 소리', () {
      expect(say('3탄'), '3000');
      expect(say('삼탄'), '3000');
      expect(say('우만동'), '50000');
      expect(say('젤만'), '70000');
      expect(say('57,000 /'), '57000'); // 끝에 붙은 기호는 잡음
      expect(say('오만 더하기'), '50000+'); // 말로 한 연산은 유지
    });

    test('가르친 숫자 말은 통째로만 바꿈', () {
      spokenPhrases = {'7': '70000', '이촌동': '2000'};
      expect(say('7'), '70000');
      expect(say('70'), '70'); // 70의 7은 그대로
      expect(say('이촌동'), '2000');
    });

    test('수상한 글자 점수', () {
      expect(spokenSuspicion('뭐만'), greaterThan(0));
      expect(spokenSuspicion('오만'), 0);
      expect(spokenSuspicion('7만'), 0);
    });
  });
}
