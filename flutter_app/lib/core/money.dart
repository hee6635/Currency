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

final _opWords = RegExp(r'더하기|플러스|빼기|마이너스|곱하기|곱|나누기|[+＋\-−×xX*÷/]');
final _resultWords = RegExp(r'얼마|결과|이퀄|equals?|=', caseSensitive: false);
final _clearAll = RegExp(r'다지워|모두지워|전부지워|새로');
final _deleteOne = RegExp(r'지워|지우기');

String _opFor(String w) {
  if (RegExp(r'더하기|플러스|[+＋]').hasMatch(w)) return opAdd;
  if (RegExp(r'빼기|마이너스|[\-−]').hasMatch(w)) return opSub;
  if (RegExp(r'곱하기|곱|[×xX*]').hasMatch(w)) return opMul;
  return opDiv;
}

bool _endsWithOp(String e) =>
    e.isNotEmpty && operators.contains(e[e.length - 1]);

/// 마지막 덩어리(숫자 하나 또는 연산 하나)를 지운다: (남은 식, 지운 것)
(String, String) removeLastToken(String e) {
  if (e.isEmpty) return (e, '');
  if (_endsWithOp(e)) return (e.substring(0, e.length - 1), e[e.length - 1]);
  final m = RegExp(r'\d+$').firstMatch(e)!;
  return (e.substring(0, m.start), m.group(0)!);
}

String _prettyToken(String t) => operators.contains(t) ? t : fmt(int.parse(t));

/// 말 한 번(마이크를 켰다 끈 한 번)의 결과
class VoiceStep {
  const VoiceStep(this.expr, this.headline, {this.message});

  /// 바뀐 뒤의 수식
  final String expr;

  /// 크게 보여줄 말 ("+ 30,000", "5 지움", "= 80,000"). 바뀐 게 없으면 빈 문자열
  final String headline;

  /// 알려줄 말 (못 알아들음 등)
  final String? message;

  bool get changed => headline.isNotEmpty;
}

/// 음성 규칙:
/// - 말한 숫자는 남아 있고, 이어서 말하면 이어 붙는다 ("오만" → "더하기 삼만").
/// - 숫자 뒤에 또 숫자만 말하면: 더하기 모드면 더하고, 아니면 안내만.
/// - "지워": 마지막 덩어리 하나, "다 지워"/"새로": 전부.
/// - "얼마"/"결과": = 를 누른 것처럼 합친다.
/// - "원"/"동"은 무시한다 (방향은 화면에서만 바꾼다).
VoiceStep applySpoken(String expr, String text, {required bool addMode}) {
  final compact = text.replaceAll(RegExp(r'\s'), '');
  if (_clearAll.hasMatch(compact)) return const VoiceStep('', '전부 지움');

  // "지워"
  var e = expr;
  final removed = <String>[];
  for (final _ in _deleteOne.allMatches(compact)) {
    final (rest, tok) = removeLastToken(e);
    if (tok.isEmpty) break;
    e = rest;
    removed.insert(0, tok);
  }
  final deleted = removed.isEmpty
      ? ''
      : '${removed.map(_prettyToken).join(' ')} 지움';

  // 남은 말: [앞 연산] 숫자 (연산 숫자)* [뒤 연산] [얼마]
  final wantsResult = _resultWords.hasMatch(text);
  final spoken = text.replaceAll(_deleteOne, ' ').replaceAll(_resultWords, ' ');
  final parts = <String>[];
  final ops = <String>[];
  var last = 0;
  for (final m in _opWords.allMatches(spoken)) {
    parts.add(spoken.substring(last, m.start));
    ops.add(_opFor(m.group(0)!));
    last = m.end;
  }
  parts.add(spoken.substring(last));

  String? leadingOp;
  if (ops.isNotEmpty && parts.first.trim().isEmpty) {
    leadingOp = ops.removeAt(0);
    parts.removeAt(0);
  }
  final body = StringBuffer();
  for (var i = 0; i < parts.length; i++) {
    final isLast = i == parts.length - 1;
    if (isLast && parts[i].trim().isEmpty && i > 0) break; // "오만 더하기"
    final a = parseSpokenAmount(parts[i]);
    if (a == null) {
      if (parts[i].trim().isEmpty && parts.length == 1) break; // 숫자 없이 연산/얼마만
      return VoiceStep(expr, '', message: '"$text"에서 금액을 못 찾았어요');
    }
    if (i > 0) body.write(ops[i - 1]);
    body.write(a.value);
  }
  // 숫자 뒤에 연산으로 끝난 경우 ("오만 더하기")
  if (parts.length > 1 && parts.last.trim().isEmpty) body.write(ops.last);
  final b = body.toString();

  String headline;
  if (b.isEmpty) {
    if (leadingOp != null && e.isNotEmpty) {
      e = _endsWithOp(e)
          ? e.substring(0, e.length - 1) + leadingOp
          : e + leadingOp;
      headline = leadingOp;
    } else {
      headline = deleted;
    }
  } else if (e.isEmpty) {
    e = b;
    headline = prettyExpr(b);
  } else if (_endsWithOp(e)) {
    if (leadingOp != null) e = e.substring(0, e.length - 1) + leadingOp;
    headline = '${e[e.length - 1]} ${prettyExpr(b)}';
    e += b;
  } else if (leadingOp != null) {
    e += leadingOp + b;
    headline = '$leadingOp ${prettyExpr(b)}';
  } else if (addMode) {
    e += opAdd + b;
    headline = '$opAdd ${prettyExpr(b)}';
  } else {
    return VoiceStep(expr, deleted, message: '연산을 같이 말해 주세요 (예: 더하기 삼만)');
  }
  if (deleted.isNotEmpty && b.isNotEmpty) headline = '$deleted · $headline';

  if (wantsResult && e.isNotEmpty) {
    e = applyKey(e, '=');
    headline = e.isEmpty ? '계산할 수 없어요' : '= ${fmt(int.parse(e))}';
  }
  if (e.length > 48) return VoiceStep(expr, '', message: '식이 너무 길어요');
  return VoiceStep(e, headline);
}
