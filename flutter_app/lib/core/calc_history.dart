import 'dart:convert';

/// 최근 계산 한 칸
class CalcEntry {
  const CalcEntry(this.id, this.expr, this.time);
  final int id;
  final String expr;
  final DateTime time;

  Map<String, Object> toJson() => {
    'id': id,
    'e': expr,
    't': time.millisecondsSinceEpoch,
  };
}

class CalcHistory {
  static const max = 5;

  /// 저장할 만한 식인지: 숫자가 하나라도 있어야 함
  static bool worthKeeping(String expr) => RegExp(r'[1-9]').hasMatch(expr);

  /// 식을 맨 위에 넣은 새 목록과 그 칸의 id. 넣을 게 없으면 (원래 목록, null).
  /// [replaceId] 칸이 있으면 그 칸을 바꾼다 (불러온 식을 고친 경우).
  static (List<CalcEntry>, int?) add(
    List<CalcEntry> list,
    String expr, {
    int? replaceId,
    required DateTime now,
  }) {
    if (!worthKeeping(expr)) return (list, null);
    final rest = list.where((e) => e.id != replaceId).toList();
    // 맨 위와 똑같은 식이면 시간만 새로
    final same = rest.where((e) => e.expr == expr).firstOrNull;
    if (same != null) rest.remove(same);
    final id = replaceId ?? same?.id ?? now.microsecondsSinceEpoch;
    final next = [CalcEntry(id, expr, now), ...rest];
    return (next.take(max).toList(), id);
  }

  static String encode(List<CalcEntry> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());

  static List<CalcEntry> decode(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      return [
        for (final j in jsonDecode(raw) as List)
          CalcEntry(
            (j['id'] as num).toInt(),
            j['e'] as String,
            DateTime.fromMillisecondsSinceEpoch((j['t'] as num).toInt()),
          ),
      ].take(max).toList();
    } catch (_) {
      return const [];
    }
  }
}
