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
}
