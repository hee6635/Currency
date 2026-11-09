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

/// 더하기·빼기로 나뉜 항목들: "50000+30000×2−5000" → [(+,50000),(+,60000),(−,5000)]
/// 곱하기·나누기는 한 항목으로 묶어 계산한 값. 0으로 나누면 그 항목은 null.
List<(String sign, double? value)> exprTerms(String expr) {
  final t = _tokens(expr);
  while (t.isNotEmpty && operators.contains(t.last)) {
    t.removeLast();
  }
  final out = <(String, double?)>[];
  if (t.isEmpty) return out;
  var sign = opAdd;
  double? term = double.parse(t[0]);
  for (var i = 1; i + 1 < t.length; i += 2) {
    final op = t[i];
    final n = double.parse(t[i + 1]);
    if (op == opMul) {
      if (term != null) term *= n;
    } else if (op == opDiv) {
      term = (term == null || n == 0) ? null : term / n;
    } else {
      out.add((sign, term));
      sign = op;
      term = n;
    }
  }
  out.add((sign, term));
  return out;
}

/// 화면에 줄 맞춰 보여줄 항목: 부호, 보기 좋은 글자("30,000 × 2"), 계산한 값
/// 끝에 연산자만 남았으면 trailing 에 담는다.
(List<(String sign, String text, double? value)>, String trailing) exprParts(
  String expr,
) {
  final t = _tokens(expr);
  var trailing = '';
  if (t.isNotEmpty && operators.contains(t.last)) trailing = t.removeLast();
  final values = exprTerms(expr);
  final out = <(String, String, double?)>[];
  var buf = <String>[];
  var sign = opAdd;
  void flush() {
    if (buf.isEmpty) return;
    final i = out.length;
    out.add((
      sign,
      buf.map((x) => operators.contains(x) ? ' $x ' : fmt(int.parse(x))).join(),
      i < values.length ? values[i].$2 : null,
    ));
    buf = [];
  }

  for (final x in t) {
    if (x == opAdd || x == opSub) {
      flush();
      sign = x;
    } else {
      buf.add(x);
    }
  }
  flush();
  return (out, trailing);
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
          _smallUnits.containsKey(next) ||
          _bigUnits.containsKey(next) ||
          next == '케' ||
          next == 'k' ||
          next == 'K';
      if (nextIsUnit || prevIsNum || seen) {
        numVal = _sinoDigits[ch]!.toDouble();
        seen = true;
      }
      i++;
      continue;
    }
    // K(천): 앞의 숫자 전체에 곱한다 ("오십 케이" = 50 × 1000, "25K" = 25,000)
    if (ch == 'k' || ch == 'K' || t.startsWith('케이', i)) {
      final v = section + (numVal ?? 0);
      section = (v == 0 ? 1 : v) * 1000;
      numVal = null;
      seen = true;
      i += t.startsWith('케이', i) ? 2 : 1;
      continue;
    }
    if (_smallUnits.containsKey(ch)) {
      section += (numVal ?? 1) * _smallUnits[ch]!;
      numVal = null;
      seen = true;
      i++;
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

/// 음성인식이 비슷한 소리로 잘못 알아듣는 말 보정 (순서대로 적용).
/// 예: "이촌 동" → "이천 동", "고파기" → "곱하기", "오만이요" → "오만"
final List<(RegExp, String)> _fixes = [
  // 전부 지우기
  (RegExp(r'(다|모두|전부|싹)\s*(지워|지어|치워|지워줘|지우기|삭제)|처음부터|리셋|초기화'), ' 다지워 '),
  // 하나 지우기
  (RegExp(r'지워줘|지어|치워|지우기|삭제'), ' 지워 '),
  // 연산
  (RegExp(r'더\s*하기|더해\s*(요|줘)?|더하고|풀러스|플러스'), ' 더하기 '),
  (RegExp(r'뺴기|배기|빼기|빼고|마이나스|마이너스|빼\s*(요|줘)'), ' 빼기 '),
  (RegExp(r'곱\s*하기|고파기|곱파기|고바기|곱빼기|곱해\s*(요|줘)?|곱하고|곱셈'), ' 곱하기 '),
  (RegExp(r'나눠\s*(요|줘)?|나누고|나뉘기|나누기|나눗셈'), ' 나누기 '),
  // 결과
  (RegExp(r'얼마\s*(야|지|예요|에요|요)?|계산\s*해?\s*(줘|요)?|결과|합계'), ' 얼마 '),
  // "오 케이"를 영어 OK로 적는 경우 → 5K
  (RegExp(r'(^|\s)[Oo]\s*[Kk](?:[Aa][Yy])?(?=\s|$)'), r'$1 5K'),
  // 고유어 숫자 (곱하기 셋 등)
  (RegExp(r'하나'), '1'),
  (RegExp(r'(?<=^|\s)둘(?=\s|$)'), '2'),
  (RegExp(r'셋'), '3'),
  (RegExp(r'넷'), '4'),
  (RegExp(r'다섯'), '5'),
  (RegExp(r'여섯'), '6'),
  (RegExp(r'일곱'), '7'),
  (RegExp(r'여덟|여덜'), '8'),
  (RegExp(r'아홉'), '9'),
  (RegExp(r'(?<=^|\s)열(?=\s|$)'), '10'),
  // 숫자 단위 오인식: 이촌/이전 → 이천, 오망 → 오만, 심만 → 십만, 빽만 → 백만
  (RegExp(r'([0-9일이삼사오육칠팔구])\s*(촌|전|쳔|철|탄|턴|청|첨)'), r'$1천'),
  // 만·천 앞 비슷한 소리: 우만 → 오만, 젤만 → 칠만
  (RegExp(r'(^|\s)(우|어)(?=\s*[만천백])'), r'$1오'),
  (RegExp(r'(^|\s)(젤|첼|치|질)(?=\s*만)'), r'$1칠'),
  // 음성인식이 끝에 붙인 연산 기호(말로 한 "더하기"가 아니라 기호만) → 잡음으로 버림
  (RegExp(r'\s*[+\-−×xX*÷/]\s*$'), ' '),
  (RegExp(r'([0-9일이삼사오육칠팔구십백천])\s*망'), r'$1만'),
  (RegExp(r'(^|[\s이삼사오육칠팔구])(심|쉽)(?=[\s일이삼사오육칠팔구만천백]|$)'), r'$1십'),
  (RegExp(r'빽|벡'), '백'),
  // 숫자 뒤 띄어 읽기: "오 만" → "오만"
  (RegExp(r'([0-9일이삼사오육칠팔구십백천])\s+(만|천|백|억)'), r'$1$2'),
  // 끝말: "오만이요", "삼천원이에요", "이만이" → 숫자만
  (RegExp(r'(이요|이에요|예요|에요|입니다|이야|이고|요)(?=\s|$)'), ' '),
  (RegExp(r'([만천억])이(?=\s|$)'), r'$1'),
];

/// 앱 밖에서 받아온 보정 규칙(인터넷)과 내 폰에서 가르친 말.
/// AppState가 채워 넣는다.
List<(RegExp, String)> spokenExtraFixes = [];
Map<String, String> spokenPhrases = {};

/// 수상한 정도: 만·천·백·십 바로 앞에 숫자가 아닌 글자가 붙은 경우의 수
/// (예: "우만" → 1). 후보를 고를 때 낮은 쪽을 고른다.
int spokenSuspicion(String text) {
  final t = normalizeSpoken(text);
  return RegExp(r'([가-힣])(?=[만천백십])')
      .allMatches(t)
      .where((m) => !'일이삼사오육칠팔구십백천만억'.contains(m.group(1)!))
      .length;
}

/// 음성인식 결과를 계산하기 좋게 다듬기
String normalizeSpoken(String text) {
  var t = ' $text ';
  // 1) 통째로 바꿀 말 (가르친 말 등): 띄어쓰기 없이 비교, 긴 것부터
  if (spokenPhrases.isNotEmpty) {
    var c = text.replaceAll(RegExp(r'\s+'), '');
    var hit = false;
    final keys = spokenPhrases.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    for (final k in keys) {
      if (k.isEmpty) continue;
      // 숫자만 있는 말("7")은 통째로 같을 때만 (70의 7까지 바꾸지 않게)
      if (RegExp(r'^[0-9.,]+$').hasMatch(k)) {
        if (c == k) {
          c = ' ${spokenPhrases[k]} ';
          hit = true;
        }
        continue;
      }
      // 나머지는 앞뒤가 숫자가 아닐 때만
      final re = RegExp('(?<![0-9])${RegExp.escape(k)}(?![0-9])');
      if (re.hasMatch(c)) {
        c = c.replaceAll(re, ' ${spokenPhrases[k]} ');
        hit = true;
      }
    }
    if (hit) t = ' $c ';
  }
  // 2) 받아온 규칙 → 3) 앱 기본 규칙
  for (final (re, rep) in [...spokenExtraFixes, ..._fixes]) {
    t = t.replaceAllMapped(re, (m) {
      var out = rep;
      for (var g = 1; g <= m.groupCount; g++) {
        out = out.replaceAll('\$$g', m.group(g) ?? '');
      }
      return out;
    });
  }
  return t.replaceAll(RegExp(r'\s+'), ' ').trim();
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
VoiceStep applySpoken(String expr, String raw, {required bool addMode}) {
  final text = normalizeSpoken(raw);
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
