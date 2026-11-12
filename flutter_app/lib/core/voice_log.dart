import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// 말 한 번(누르고 뗀 한 번)의 기록. 인식 실패도 남긴다.
class VoiceLogEntry {
  VoiceLogEntry({
    required this.at,
    required this.currency,
    required this.heard,
    required this.chosen,
    required this.result,
    required this.problem,
    required this.events,
    this.wrong = false,
  });

  final DateTime at;

  /// 입력 통화 ('동' / '원')
  final String currency;

  /// 폰이 들은 말 후보들 (가장 그럴듯한 것부터)
  final List<String> heard;

  /// 앱이 고른 문장
  final String? chosen;

  /// 반영한 결과 ("+ 30,000"). 반영 못 했으면 빈 문자열
  final String result;

  /// 실패·안내 문구
  final String? problem;

  /// 과정: "누름 0.0", "준비 0.4", "오류 no_match 2.1", "뗌 3.2" …
  final List<String> events;

  /// 사용자가 "틀렸어요"로 표시
  bool wrong;

  bool get failed => result.isEmpty;

  Map<String, dynamic> toJson() => {
    't': at.millisecondsSinceEpoch,
    'c': currency,
    'h': heard,
    if (chosen != null) 'x': chosen,
    'r': result,
    if (problem != null) 'p': problem,
    'e': events,
    if (wrong) 'w': true,
  };

  static VoiceLogEntry fromJson(Map<String, dynamic> j) => VoiceLogEntry(
    at: DateTime.fromMillisecondsSinceEpoch(j['t'] as int),
    currency: j['c'] as String? ?? '',
    heard: [for (final h in (j['h'] as List? ?? const [])) h as String],
    chosen: j['x'] as String?,
    result: j['r'] as String? ?? '',
    problem: j['p'] as String?,
    events: [for (final e in (j['e'] as List? ?? const [])) e as String],
    wrong: j['w'] as bool? ?? false,
  );

  /// 복사해서 보내기 좋은 글자 형태
  String toText() {
    String two(int n) => n.toString().padLeft(2, '0');
    final time =
        '${at.year}-${two(at.month)}-${two(at.day)} ${two(at.hour)}:${two(at.minute)}:${two(at.second)}';
    final said = heard.isEmpty ? '(아무것도 못 들음)' : '"${heard.first}"';
    final others = heard.length > 1
        ? ' (후보: ${heard.skip(1).map((h) => '"$h"').join(' / ')})'
        : '';
    final outcome = failed ? '✗ ${problem ?? '반영 안 됨'}' : '→ $result';
    return [
      '[$time] $currency | 들림: $said$others $outcome${wrong ? ' [틀림]' : ''}',
      if (chosen != null && heard.isNotEmpty && chosen != heard.first)
        '  고른 문장: "$chosen"',
      '  과정: ${events.join(', ')}',
    ].join('\n');
  }
}

/// 음성 기록 저장소: 앱 폴더의 파일에 한 줄씩 저장, 최근 [maxEntries]개만 유지.
class VoiceLog extends ChangeNotifier {
  static const maxEntries = 5000;
  final List<VoiceLogEntry> entries = [];
  File? _file;

  Future<void> load() async {
    if (kIsWeb) return; // 웹(화면 확인용)에서는 메모리에만
    try {
      final dir = await getApplicationDocumentsDirectory();
      _file = File('${dir.path}/voice_log.jsonl');
      if (await _file!.exists()) {
        final lines = await _file!.readAsLines();
        for (final l in lines) {
          if (l.trim().isEmpty) continue;
          try {
            entries.add(VoiceLogEntry.fromJson(jsonDecode(l)));
          } catch (_) {}
        }
      }
      notifyListeners();
    } catch (_) {
      _file = null;
    }
  }

  Future<void> add(VoiceLogEntry e) async {
    entries.add(e);
    final trimmed = entries.length > maxEntries;
    if (trimmed) entries.removeRange(0, entries.length - maxEntries);
    notifyListeners();
    if (_file == null) return;
    try {
      if (trimmed) {
        await _rewrite();
      } else {
        await _file!.writeAsString(
          '${jsonEncode(e.toJson())}\n',
          mode: FileMode.append,
          flush: true,
        );
      }
    } catch (_) {}
  }

  Future<void> toggleWrong(VoiceLogEntry e) async {
    e.wrong = !e.wrong;
    notifyListeners();
    await _rewrite();
  }

  Future<void> clear() async {
    entries.clear();
    notifyListeners();
    await _rewrite();
  }

  Future<void> _rewrite() async {
    if (_file == null) return;
    try {
      await _file!.writeAsString(
        entries.map((e) => '${jsonEncode(e.toJson())}\n').join(),
        flush: true,
      );
    } catch (_) {}
  }

  /// 전체(또는 틀린 것만) 글자로
  String export({bool wrongOnly = false}) {
    final list = wrongOnly
        ? entries.where((e) => e.wrong || e.failed)
        : entries;
    return [
      '[베트남 환율 음성 기록 ${list.length}개]',
      for (final e in list) e.toText(),
    ].join('\n');
  }
}
