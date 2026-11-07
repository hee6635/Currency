import 'dart:convert';

import 'package:http/http.dart' as http;

/// 앱을 다시 설치하지 않아도 바뀌는 음성 보정 규칙.
/// GitHub 저장소의 flutter_app/voice_rules.json 을 앱이 켜질 때 받아온다.
class VoiceRules {
  const VoiceRules({
    this.version = 0,
    this.fixes = const [],
    this.phrases = const {},
    this.releaseDelayMs = 1200,
    this.finalWaitMs = 3500,
    this.relistenDelayMs = 600,
    this.listenMode = 'dictation',
  });

  final int version;

  /// (정규식, 바꿀 말). 바꿀 말에는 $1~$9 사용 가능
  final List<(RegExp, String)> fixes;

  /// 들린 말(띄어쓰기 없이) → 원래 말 (예: "이촌동" → "이천")
  final Map<String, String> phrases;

  /// 손 뗀 뒤 더 듣는 시간, 그 뒤 최종 결과 기다리는 시간
  final int releaseDelayMs;
  final int finalWaitMs;

  /// 누르고 있는 중 폰 음성인식이 혼자 끝났을 때 다시 듣기까지 기다리는 시간
  final int relistenDelayMs;

  /// 'dictation'(받아쓰기) / 'search'(짧은 말) / 'confirmation'
  final String listenMode;

  static const maxFixes = 500;

  /// 잘못된 항목은 건너뛰고 쓸 수 있는 것만 읽는다. 형식이 틀리면 null.
  static VoiceRules? parse(String body) {
    try {
      final j = jsonDecode(body);
      if (j is! Map) return null;
      final fixes = <(RegExp, String)>[];
      for (final f in (j['fixes'] as List? ?? const [])) {
        if (fixes.length >= maxFixes) break;
        if (f is! Map) continue;
        final from = f['from'], to = f['to'];
        if (from is! String ||
            to is! String ||
            from.isEmpty ||
            from.length > 200) {
          continue;
        }
        try {
          fixes.add((RegExp(from), to));
        } catch (_) {}
      }
      final phrases = <String, String>{};
      final ph = j['phrases'];
      if (ph is Map) {
        ph.forEach((k, v) {
          if (k is String && v is String && k.trim().isNotEmpty) {
            phrases[compact(k)] = v;
          }
        });
      }
      final t = j['timing'];
      int ms(String key, int def, int lo, int hi) {
        final v = t is Map ? t[key] : null;
        return v is num ? v.toInt().clamp(lo, hi) : def;
      }

      return VoiceRules(
        version: (j['version'] as num?)?.toInt() ?? 0,
        fixes: fixes,
        phrases: phrases,
        releaseDelayMs: ms('releaseDelayMs', 1200, 0, 5000),
        finalWaitMs: ms('finalWaitMs', 3500, 500, 10000),
        relistenDelayMs: ms('relistenDelayMs', 600, 100, 3000),
        listenMode: switch (t is Map ? t['listenMode'] : null) {
          'search' => 'search',
          'confirmation' => 'confirmation',
          _ => 'dictation',
        },
      );
    } catch (_) {
      return null;
    }
  }

  static String compact(String s) => s.replaceAll(RegExp(r'\s+'), '');
}

/// 보정 규칙 받아오기: 작업 브랜치와 main 중 버전이 높은 쪽
class VoiceRulesService {
  VoiceRulesService({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  static const _base = 'https://raw.githubusercontent.com/hee6635/Currency';
  static const _path = 'flutter_app/voice_rules.json';
  static final urls = [
    Uri.parse('$_base/ccr-f1587883-vmaw6n/$_path'),
    Uri.parse('$_base/main/$_path'),
  ];

  /// (규칙, 원문). 못 받으면 null
  Future<(VoiceRules, String)?> fetch() async {
    (VoiceRules, String)? best;
    for (final u in urls) {
      try {
        final r = await _client.get(u).timeout(const Duration(seconds: 6));
        if (r.statusCode != 200) continue;
        final body = utf8.decode(r.bodyBytes);
        final rules = VoiceRules.parse(body);
        if (rules == null) continue;
        if (best == null || rules.version > best.$1.version) {
          best = (rules, body);
        }
      } catch (_) {}
    }
    return best;
  }
}
