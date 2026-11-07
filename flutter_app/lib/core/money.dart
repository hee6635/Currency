/// 숫자 서식, 한국식 단위, 키패드 수식 처리.
/// 화면과 분리된 순수 함수라서 테스트하기 쉽다.
library;

enum Currency {
  vnd('VND', '베트남 동', '동'),
  krw('KRW', '한국 원', '원');

  const Currency(this.code, this.name, this.unit);
  final String code;
  final String name;
  final String unit;

  Currency get other => this == vnd ? krw : vnd;
}

const opAdd = '+';
const opSub = '−';
const opMul = '×';
const opDiv = '÷';
const operators = [opAdd, opSub, opMul, opDiv];

const _maxDigits = 12;
const _maxLength = 48;

/// 1234567 → "1,234,567" (반올림)
String fmt(num n) {
  final v = n.round();
  final s = v.abs().toString();
  final buf = StringBuffer(v < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// 150000 → "15만", 1234567 → "123만 4,567". 1만 미만은 숫자와 같으니 빈 문자열.
String koreanUnit(num n) {
  final v = n.round().abs();
  if (v < 10000) return '';
  final eok = v ~/ 100000000;
  final man = (v % 100000000) ~/ 10000;
  final rest = v % 10000;
  return [
    if (eok > 0) '${fmt(eok)}억',
    if (man > 0) '${fmt(man)}만',
    if (rest > 0) fmt(rest),
  ].join(' ');
}

/// n을 step 단위로 반올림 (예: 8134 → 8100)
num roundTo(num n, int step) => (n / step).round() * step;

List<String> _tokens(String expr) =>
    RegExp(r'\d+|[+−×÷]').allMatches(expr).map((m) => m.group(0)!).toList();

bool hasOperator(String expr) => operators.any(expr.contains);

/// 수식 계산. 곱셈/나눗셈 먼저. 0으로 나누면 null.
/// 끝에 붙은 연산자는 무시한다 ("100+" → 100).
double? evaluate(String expr) {
  final t = _tokens(expr);
  while (t.isNotEmpty && operators.contains(t.last)) {
    t.removeLast();
  }
  if (t.isEmpty) return 0;
  double total = 0;
  double term = double.parse(t[0]);
  var sign = 1;
  for (var i = 1; i + 1 < t.length; i += 2) {
    final op = t[i];
    final n = double.parse(t[i + 1]);
    if (op == opMul) {
      term *= n;
    } else if (op == opDiv) {
      if (n == 0) return null;
      term /= n;
    } else {
      total += sign * term;
      sign = op == opAdd ? 1 : -1;
      term = n;
    }
  }
  return total + sign * term;
}

/// 수식을 보기 좋게: "150000+2000" → "150,000 + 2,000"
String prettyExpr(String expr) {
  if (expr.isEmpty) return '0';
  return _tokens(expr)
      .map((t) => operators.contains(t) ? ' $t ' : fmt(int.parse(t)))
      .join();
}

/// 키 하나를 눌렀을 때 새 수식. 잘못된 입력은 무시하고 원래 값을 돌려준다.
String applyKey(String expr, String key) {
  final last = expr.isEmpty ? '' : expr[expr.length - 1];
  final curNum = RegExp(r'\d+$').firstMatch(expr)?.group(0) ?? '';

  switch (key) {
    case 'C':
      return '';
    case 'back':
      return expr.isEmpty ? expr : expr.substring(0, expr.length - 1);
    case '=':
      final v = evaluate(expr);
      if (v == null || v <= 0) return '';
      return v.round().toString();
    case 'K':
      if (curNum.isEmpty || curNum.length + 3 > _maxDigits) return expr;
      return '${expr}000';
  }

  if (operators.contains(key)) {
    if (expr.isEmpty) return expr;
    if (operators.contains(last)) {
      return expr.substring(0, expr.length - 1) + key;
    }
    return expr.length >= _maxLength ? expr : expr + key;
  }

  // 숫자 (0, 00, 000 포함)
  if (!RegExp(r'^\d+$').hasMatch(key)) return expr;
  if (curNum == '0') {
    // "05" 같은 앞자리 0 방지: 0 뒤의 숫자는 0을 대신한다
    if (key.startsWith('0')) return expr;
    return expr.substring(0, expr.length - 1) + key;
  }
  if (curNum.isEmpty && (key != '0' || expr.isEmpty)) {
    if (key.startsWith('0')) return expr; // 00, 000, 맨 앞 0은 의미 없음
  }
  if (curNum.length + key.length > _maxDigits) return expr;
  if (expr.length + key.length > _maxLength) return expr;
  return expr + key;
}

/// 붙여넣은 글자에서 금액만 뽑기: "50,000đ" → "50000", "50K" → "50000"
String? parsePasted(String text) {
  final m = RegExp(r'(\d[\d,.\s]*)\s*([kK])?').firstMatch(text);
  if (m == null) return null;
  var digits = m.group(1)!.replaceAll(RegExp(r'[^\d]'), '');
  digits = digits.replaceFirst(RegExp(r'^0+'), '');
  if (digits.isEmpty) return null;
  if (m.group(2) != null) digits += '000';
  if (digits.length > _maxDigits) return null;
  return digits;
}

/// 직접 입력한 환율 검사: "18.45" → 18.45, 잘못된 값이면 null
double? parseRate(String text) {
  final v = double.tryParse(text.trim().replaceAll(',', '.'));
  if (v == null || v.isNaN || v <= 0 || v > 10000) return null;
  return v;
}

/// 말로 한 금액 해석 결과
class SpokenAmount {
  const SpokenAmount(this.value, this.currency);
  final int value;

  /// "동"/"원"을 말했으면 그 통화, 아니면 null
  final Currency? currency;
}

const _sinoDigits = {
  '영': 0,
  '공': 0,
  '일': 1,
  '이': 2,
  '삼': 3,
  '사': 4,
  '오': 5,
  '육': 6,
  '륙': 6,
  '칠': 7,
  '팔': 8,
  '구': 9,
};
const _smallUnits = {'십': 10, '백': 100, '천': 1000};
const _bigUnits = {'만': 10000, '억': 100000000};

/// 음성인식 결과를 금액으로: "이십칠만 동" → 270000(동), "27만 5천원" → 275000(원),
/// "오만" → 50000, "50K" → 50000, "270,000동" → 270000. 숫자가 없으면 null.
SpokenAmount? parseSpokenAmount(String text) {
  final t = text.replaceAll(RegExp(r'[\s,]'), '');
  if (t.isEmpty) return null;
  // "사", "삼동"처럼 한 글자 숫자만 말한 경우
  final single = RegExp(r'^([영공일이삼사오육칠팔구])(동|원)?$').firstMatch(t);
  if (single != null && _sinoDigits[single.group(1)]! > 0) {
    final c = single.group(2) == null
        ? null
        : (single.group(2) == '원' ? Currency.krw : Currency.vnd);
    return SpokenAmount(_sinoDigits[single.group(1)]!, c);
  }

  Currency? cur;
  if (RegExp(r'동|đồng|dong|VND', caseSensitive: false).hasMatch(t)) {
    cur = Currency.vnd;
  }
  if (RegExp(r'원|won|KRW', caseSensitive: false).hasMatch(t)) {
    // 둘 다 나오면 마지막에 말한 쪽
    final iw = t.lastIndexOf(RegExp(r'원|won|KRW', caseSensitive: false));
    final id = t.lastIndexOf(RegExp(r'동|đồng|dong|VND', caseSensitive: false));
    cur = iw > id ? Currency.krw : Currency.vnd;
  }

  double total = 0; // 만/억으로 묶인 부분
  double section = 0; // 만 아래 부분
  double? numVal; // 방금 읽은 숫자
  var seen = false;

  var i = 0;
  while (i < t.length) {
    final ch = t[i];
    final m = RegExp(r'^\d+(\.\d+)?').firstMatch(t.substring(i));
    if (m != null) {
      numVal = double.parse(m.group(0)!);
      seen = true;
      i += m.group(0)!.length;
      continue;
    }
    if (_sinoDigits.containsKey(ch)) {
      // "이" 같은 글자가 조사로 쓰일 수 있어서, 숫자 단위 앞뒤에 있을 때만 숫자로 본다
      final next = i + 1 < t.length ? t[i + 1] : '';
      final prevIsNum =
          i > 0 &&
          (_smallUnits.containsKey(t[i - 1]) ||
              _bigUnits.containsKey(t[i - 1]) ||
              _sinoDigits.containsKey(t[i - 1]));
      final nextIsUnit =
          _smallUnits.containsKey(next) || _bigUnits.containsKey(next);
      if (nextIsUnit || prevIsNum || seen) {
        numVal = _sinoDigits[ch]!.toDouble();
        seen = true;
      }
      i++;
      continue;
    }
    if (_smallUnits.containsKey(ch) ||
        ch == 'k' ||
        ch == 'K' ||
        t.startsWith('케이', i)) {
      final unit = _smallUnits[ch] ?? 1000;
      section += (numVal ?? 1) * unit;
      numVal = null;
      seen = true;
      i += t.startsWith('케이', i) ? 2 : 1;
      continue;
    }
    if (_bigUnits.containsKey(ch)) {
      section += numVal ?? 0;
      total += (section == 0 ? 1 : section) * _bigUnits[ch]!;
      section = 0;
      numVal = null;
      seen = true;
      i++;
      continue;
    }
    i++; // 동, 원, 조사 등은 건너뜀
  }
  if (!seen) return null;
  final v = (total + section + (numVal ?? 0)).round();
  if (v <= 0 || v.toString().length > 12) return null;
  return SpokenAmount(v, cur);
}

/// 말로 한 계산식 해석 결과
class SpokenExpr {
  const SpokenExpr(this.expr, this.currency, {required this.wantsResult});

  /// 키패드 수식 형식 ("200000+50000")
  final String expr;
  final Currency? currency;

  /// "얼마", "결과" 같은 말로 = 를 원했는지
  final bool wantsResult;
}

final _opWords = RegExp(r'더하기|플러스|빼기|마이너스|곱하기|곱|나누기|[+＋\-−×xX*÷/]');
final _resultWords = RegExp(r'얼마|결과|이퀄|equals?|=', caseSensitive: false);

String _opFor(String w) {
  if (RegExp(r'더하기|플러스|[+＋]').hasMatch(w)) return opAdd;
  if (RegExp(r'빼기|마이너스|[\-−]').hasMatch(w)) return opSub;
  if (RegExp(r'곱하기|곱|[×xX*]').hasMatch(w)) return opMul;
  return opDiv;
}

/// 음성인식 결과를 계산식으로: "이십만 더하기 오만 얼마" → "200000+50000" (결과 원함).
/// 연산이 없으면 금액 하나. 해석할 수 없으면 null.
SpokenExpr? parseSpokenExpression(String text) {
  final wantsResult = _resultWords.hasMatch(text);
  final body = text.replaceAll(_resultWords, ' ');
  final parts = <String>[];
  final ops = <String>[];
  var last = 0;
  for (final m in _opWords.allMatches(body)) {
    parts.add(body.substring(last, m.start));
    ops.add(_opFor(m.group(0)!));
    last = m.end;
  }
  parts.add(body.substring(last));

  final buf = StringBuffer();
  Currency? cur;
  for (var i = 0; i < parts.length; i++) {
    final a = parseSpokenAmount(parts[i]);
    if (a == null) {
      // 맨 끝 숫자가 빠진 "오만 더하기" 같은 경우는 앞부분만 쓴다
      if (i == parts.length - 1 && i > 0) break;
      return null;
    }
    cur ??= a.currency;
    if (a.currency != null) cur = a.currency;
    if (i > 0) buf.write(ops[i - 1]);
    buf.write(a.value);
  }
  return SpokenExpr(buf.toString(), cur, wantsResult: wantsResult);
}
