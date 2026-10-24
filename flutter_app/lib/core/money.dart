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
