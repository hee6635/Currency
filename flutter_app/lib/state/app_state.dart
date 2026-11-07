import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/money.dart';
import '../core/rate_service.dart';
import '../core/voice.dart';
import '../core/voice_log.dart';
import '../core/voice_rules.dart';

enum RateSource { none, api, manual }

const defaultMemo = '여행 메모\n\n- 야시장 가기\n- 반미 먹기\n';

/// 앱 전체 상태. 바뀔 때마다 저장하고 화면에 알린다.
class AppState extends ChangeNotifier {
  AppState({RateService? service, SharedPreferences? prefs})
    : _service = service ?? RateService() {
    _prefs = prefs;
  }

  final RateService _service;
  SharedPreferences? _prefs;
  Timer? _memoTimer;

  // 환율
  double? rate; // 1원 = rate동
  DateTime? rateTime;
  RateSource source = RateSource.none;
  bool fetching = false;
  String? fetchError;
  bool autoUpdate = true;
  bool addMode = true; // 말로 숫자만 연달아 말하면 더하기
  double feePercent = 0; // 환전 수수료 보정 (%)

  // 환산
  String expr = '';
  Currency from = Currency.vnd;

  // 그 밖의 탭
  Currency tableFrom = Currency.vnd;
  Map<int, int> noteCounts = {};
  String memo = defaultMemo;

  /// 음성 기록 (말할 때마다, 실패도 포함)
  final voiceLog = VoiceLog();

  /// 인터넷에서 받아온 음성 보정 규칙 (재설치 없이 갱신)
  VoiceRules rules = const VoiceRules();

  /// 내 폰에서 가르친 말: 들린 말(띄어쓰기 없이) → 원래 숫자
  Map<String, String> learned = {};

  void _applyRules() {
    spokenExtraFixes = rules.fixes;
    spokenPhrases = {...rules.phrases, ...learned};
  }

  /// 앱 켤 때: 저장해 둔 규칙을 먼저 쓰고, 인터넷에서 더 새 규칙이 있으면 바꾼다
  Future<void> _loadRules(SharedPreferences p) async {
    final cached = p.getString('voiceRules');
    if (cached != null) rules = VoiceRules.parse(cached) ?? rules;
    try {
      final m = jsonDecode(p.getString('learned') ?? '{}') as Map;
      learned = m.map((k, v) => MapEntry(k as String, v as String));
    } catch (_) {
      learned = {};
    }
    _applyRules();
    final got = await VoiceRulesService().fetch();
    if (got != null && got.$1.version > rules.version) {
      rules = got.$1;
      p.setString('voiceRules', got.$2);
      _applyRules();
      notifyListeners();
    }
  }

  /// 마지막 말을 반영하기 전의 식, 마지막으로 들린 말 (고쳐서 기억하기용)
  String? exprBeforeVoice;
  String lastHeardRaw = '';

  /// 들린 말을 원래 숫자로 기억한다. [apply]면 마지막 말 반영을 되돌리고
  /// 고친 숫자로 다시 반영, 기록에도 "틀림" 표시.
  void teach(String heardText, String number, {bool apply = true}) {
    final key = VoiceRules.compact(heardText);
    if (key.isEmpty || number.isEmpty) return;
    learned = {...learned, key: number};
    _prefs?.setString('learned', jsonEncode(learned));
    _applyRules();
    if (apply) {
      voiceProblem = null;
      if (exprBeforeVoice != null) expr = exprBeforeVoice!;
      applyHeard(number);
      final last = voiceLog.entries.isEmpty ? null : voiceLog.entries.last;
      if (last != null && !last.wrong) voiceLog.toggleWrong(last);
    }
    notifyListeners();
  }

  void forgetLearned() {
    learned = {};
    _prefs?.setString('learned', '{}');
    _applyRules();
    notifyListeners();
  }

  Future<void> load() async {
    voiceLog.load();
    final p = _prefs ??= await SharedPreferences.getInstance();
    _loadRules(p);
    final r = p.getDouble('rate');
    rate = (r != null && r > 0) ? r : null;
    final t = p.getInt('rateTime');
    rateTime = t == null ? null : DateTime.fromMillisecondsSinceEpoch(t);
    source = RateSource.values[(p.getInt('source') ?? 0).clamp(0, 2)];
    if (rate == null) source = RateSource.none;
    autoUpdate = p.getBool('autoUpdate') ?? true;
    addMode = p.getBool('addMode') ?? true;
    feePercent = (p.getDouble('fee') ?? 0).clamp(0, 10).toDouble();
    from = p.getString('from') == 'krw' ? Currency.krw : Currency.vnd;
    memo = p.getString('memo') ?? defaultMemo;
    try {
      final raw = jsonDecode(p.getString('notes') ?? '{}') as Map;
      noteCounts = raw.map(
        (k, v) => MapEntry(int.parse(k as String), v as int),
      );
    } catch (_) {
      noteCounts = {};
    }
    notifyListeners();
    if (autoUpdate || rate == null) refresh();
  }

  Future<void>? _inflight;

  /// 이미 불러오는 중이면 같은 작업을 기다린다 (중복 요청 방지)
  Future<void> refresh() =>
      _inflight ??= _fetch().whenComplete(() => _inflight = null);

  Future<void> _fetch() async {
    fetching = true;
    fetchError = null;
    notifyListeners();
    try {
      final info = await _service.fetch();
      rate = info.vndPerKrw;
      rateTime = info.updatedAt;
      source = RateSource.api;
      _saveRate();
    } on RateException catch (e) {
      fetchError = e.message;
    } finally {
      fetching = false;
      notifyListeners();
    }
  }

  void setManualRate(double value) {
    rate = value;
    rateTime = DateTime.now();
    source = RateSource.manual;
    fetchError = null;
    _saveRate();
    notifyListeners();
  }

  void _saveRate() {
    final p = _prefs;
    if (p == null || rate == null) return;
    p.setDouble('rate', rate!);
    p.setInt('rateTime', rateTime!.millisecondsSinceEpoch);
    p.setInt('source', source.index);
  }

  void setAutoUpdate(bool v) {
    autoUpdate = v;
    _prefs?.setBool('autoUpdate', v);
    notifyListeners();
  }

  void setAddMode(bool v) {
    addMode = v;
    _prefs?.setBool('addMode', v);
    notifyListeners();
  }

  void setFee(double v) {
    feePercent = v;
    _prefs?.setDouble('fee', v);
    notifyListeners();
  }

  // ---- 환산 ----

  void press(String key) {
    final next = applyKey(expr, key);
    if (next == expr) return;
    expr = next;
    notifyListeners();
  }

  bool pasteAmount(String text) {
    final digits = parsePasted(text);
    if (digits == null) return false;
    expr = digits;
    notifyListeners();
    return true;
  }

  // ---- 음성 입력 ----

  VoiceInput? _voice;

  /// 음성 모드(네모 창)가 열려 있는지
  bool voiceMode = false;

  /// 버튼을 누르고 있는 동안 true
  bool listening = false;

  /// 음성인식이 실제로 듣기 시작했는지 (이때 진동, "말하세요")
  bool voiceReady = false;

  /// 음성 창에 보여줄 문제 안내 (권한, 못 들음 등). 없으면 null
  String? voiceProblem;
  String heard = '';
  bool _released = false;
  bool _applied = false;
  Timer? _releaseTimer;
  void Function()? _finish;

  void openVoice() {
    voiceMode = true;
    notice = null;
    notifyListeners();
  }

  void closeVoice() {
    if (listening) releaseTalk();
    voiceMode = false;
    notifyListeners();
  }

  /// 듣는 중에 미리 보여줄 결과 ("2,000", "+ 2,000"). 해석 못 하면 null
  String? preview;

  /// 누르고 있는 동안 음성인식이 스스로 끝나서 모아 둔 말
  final List<String> _segments = [];
  List<String> _candidates = const [];

  /// 모아 둔 말 + 지금 후보들 중에서 숫자로 해석되는 가장 좋은 문장
  String? _bestHeard() {
    final prefix = _segments.join(' ');
    final options = [
      for (final c in _candidates.isEmpty ? const [''] : _candidates)
        '$prefix $c'.trim(),
    ].where((t) => t.isNotEmpty).toList();
    if (options.isEmpty) return null;
    // 점수가 가장 높은 후보 (같으면 폰이 준 순서). 숫자로 안 읽히면 제외.
    String? best;
    var bestScore = -1 << 30;
    for (final t in options) {
      final step = applySpoken(expr, t, addMode: addMode);
      if (!step.changed) continue;
      var score = 0;
      if (step.message != null) score -= 50;
      // "우만"처럼 만·천 앞에 이상한 글자 → 감점
      score -= 20 * spokenSuspicion(t);
      // 동은 보통 1,000동 이상: 곱하기·나누기 뒤가 아닌데 1,000 미만이면 감점 ("7" vs "7만")
      final m = RegExp(r'(\d+)$').firstMatch(step.expr);
      final before = m == null ? '' : step.expr.substring(0, m.start);
      final afterMulDiv = before.endsWith(opMul) || before.endsWith(opDiv);
      if (m != null && !afterMulDiv && !step.headline.startsWith('=')) {
        final v = int.parse(m.group(1)!);
        if (from == Currency.vnd && v < 1000) score -= 10;
        if (from == Currency.krw && v < 10) score -= 10;
      }
      if (score > bestScore) {
        bestScore = score;
        best = t;
      }
    }
    return best ?? options.first;
  }

  void _updatePreview() {
    final best = _bestHeard();
    heard = best ?? '';
    final step = best == null
        ? null
        : applySpoken(expr, best, addMode: addMode);
    preview = (step != null && step.changed) ? step.headline : null;
  }

  final List<String> _events = [];
  final Stopwatch _clock = Stopwatch();
  void _ev(String name) => _events.add(
    '$name ${(_clock.elapsedMilliseconds / 1000).toStringAsFixed(1)}',
  );
  bool _restarting = false;

  /// 지난번에 음성인식이 "바쁨"으로 꼬였는지 (다음 누를 때 먼저 정리)
  bool _busyBefore = false;
  int _busyRetries = 0;

  /// 무전기 방식: 누르는 순간 듣기 시작
  Future<void> pressTalk(void Function(String) onMessage) async {
    if (listening) return;
    final voice = _voice ??= VoiceInput();
    listening = true;
    voiceReady = false;
    voiceProblem = null;
    heard = '';
    preview = null;
    _segments.clear();
    _candidates = const [];
    _released = false;
    _applied = false;
    _restarting = false;
    _events.clear();
    _clock
      ..reset()
      ..start();
    _ev('누름');
    notifyListeners();

    // 알려줄 말은 음성 창 안에도 보이게
    void report(String m) {
      voiceProblem = m;
      onMessage(m);
    }

    var wasReady = false;
    void finish() {
      if (_applied) return;
      _applied = true;
      _releaseTimer?.cancel();
      listening = false;
      voiceReady = false;
      final best = _bestHeard();
      preview = null;
      final before = notice?.id;
      exprBeforeVoice = expr;
      lastHeardRaw = best ?? '';
      if (best != null && best.isNotEmpty) {
        heard = best;
        final msg = applyHeard(best);
        if (msg != null) report('"$best"(으)로 들렸어요. $msg');
      } else if (voiceProblem == null) {
        report(
          wasReady
              ? '아무 말도 못 들었어요. 진동이 온 뒤 말하고, 다 말한 다음 손을 떼 주세요'
              // 듣기가 시작되기 전에 손을 뗌 (처음엔 마이크 권한 창 때문일 수 있음)
              : '버튼을 누른 채로 진동이 올 때까지 기다린 뒤 말해 주세요',
        );
      }
      // 기록 남기기 (실패도)
      _ev('끝');
      final prefix = _segments.join(' ');
      voiceLog.add(
        VoiceLogEntry(
          at: DateTime.now(),
          currency: from.unit,
          heard: [
            for (final c in _candidates) '$prefix $c'.trim(),
            if (_candidates.isEmpty && prefix.isNotEmpty) prefix,
          ],
          chosen: best,
          result: notice != null && notice!.id != before
              ? notice!.headline
              : '',
          problem: voiceProblem,
          events: List.of(_events),
        ),
      );
      notifyListeners();
    }

    late Future<String?> Function() listen;
    listen = () => voice.start(
      listenMode: rules.listenMode,
      onEvent: (e) {
        if (e.contains('listening') && !e.contains('notListening')) return;
        _ev(e);
      },
      onReady: () {
        voiceReady = true;
        if (!wasReady) HapticFeedback.mediumImpact();
        wasReady = true;
        notifyListeners();
      },
      onText: (cands, isFinal) {
        if (_candidates.isEmpty && !isFinal) _ev('부분 결과');
        // 마지막에 빈 결과가 와도 앞서 들은 걸 지운다 (덮어쓰지 않음)
        if (cands.every((c) => c.trim().isEmpty)) {
          if (_candidates.isNotEmpty) {
            if (isFinal && _released) finish();
            return;
          }
        }
        _candidates = cands;
        _updatePreview();
        if (isFinal) _ev('결과');
        notifyListeners();
        if (isFinal && _released) finish();
      },
      onDone: () {
        if (_released || _applied) {
          finish();
          return;
        }
        // 아직 누르고 있는데 폰 음성인식이 혼자 끝남(잠깐 쉼, 말 시작 전 조용함, 못 알아들음)
        // → 들은 건 모아 두고 바로 다시 듣기. 손을 뗄 때까지 계속 듣는다.
        if (_restarting) return;
        _restarting = true;
        final cur = _candidates.isEmpty ? '' : _candidates.first;
        if (cur.isNotEmpty) _segments.add(cur);
        _candidates = const [];
        Future.delayed(Duration(milliseconds: rules.relistenDelayMs), () async {
          if (_released || _applied) {
            _restarting = false;
            return finish();
          }
          if (_busyBefore) {
            _busyBefore = false;
            await voice.cancel();
            await Future<void>.delayed(const Duration(milliseconds: 400));
            if (_released || _applied) {
              _restarting = false;
              return finish();
            }
          }
          _ev('다시듣기');
          final err = await listen();
          _restarting = false;
          if (err != null) finish();
        });
      },
      onError: (m) {
        // 누르고 있는 중 "못 들음"은 다시 듣기로 넘기고, 나머지 오류만 알림
        if (!_released && m.startsWith('잘 안 들렸어요')) return;
        // "바쁨"(error_client): 정리하고 잠깐 쉬었다가 최대 2번 다시 시도
        if (m.startsWith('음성인식이 바빠요')) {
          _busyBefore = true;
          // 이미 다시 듣기가 예약돼 있으면 그쪽에서 정리 후 시작
          if (!_released && _restarting) return;
          if (!_released && _busyRetries < 2) {
            _busyRetries++;
            _restarting = true;
            Future(() async {
              await voice.cancel();
              await Future<void>.delayed(const Duration(milliseconds: 700));
              _restarting = false;
              if (_released || _applied) return finish();
              _ev('다시시도');
              final err = await listen();
              if (err != null) finish();
            });
            return;
          }
        }
        report(m);
        finish();
      },
    );

    _finish = finish;
    _busyRetries = 0;
    if (_busyBefore) {
      // 지난번에 꼬였으면 정리하고 잠깐 쉬었다가 시작
      _busyBefore = false;
      _ev('정리');
      await voice.cancel();
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    final err = await listen();
    if (err != null) {
      listening = false;
      _applied = true;
      report(err);
      notifyListeners();
    } else {
      if (voice.noKorean) {
        report('폰에 한국어 음성인식이 없어요. 구글 앱 → 설정 → 음성에서 한국어를 받아 주세요');
      }
      // 시작이 끝나기 전에 이미 손을 뗐어도 바로 멈추지 않는다 (releaseTalk의 타이머가 멈춤)
    }
  }

  /// 손을 떼도 바로 멈추지 않고 1.2초 더 듣는다 (폰이 마지막 말을 처리할 시간).
  /// 그다음 멈추고, 최종 결과를 최대 3.5초 기다렸다 반영.
  void releaseTalk() {
    if (!listening || _released) return;
    _released = true;
    _ev('뗌');
    _releaseTimer?.cancel();
    _releaseTimer = Timer(Duration(milliseconds: rules.releaseDelayMs), () {
      if (_applied) return;
      _ev('멈춤');
      _voice?.stop();
      _releaseTimer = Timer(
        Duration(milliseconds: rules.finalWaitMs),
        () => _finish?.call(),
      );
    });
  }

  /// 말로 한 문장을 금액으로 넣기. 금액이 없으면 false.
  /// 말 한 번을 규칙대로 반영하고, 크게 보여줄 확인 화면을 띄운다.
  /// 반영한 게 없으면 알려줄 말을 돌려준다.
  String? applyHeard(String text) {
    final step = applySpoken(expr, text, addMode: addMode);
    if (!step.changed) return step.message ?? '"$text"을(를) 알아듣지 못했어요';
    expr = step.expr;
    _showNotice(step.headline);
    notifyListeners();
    return step.message;
  }

  // ---- 음성 모드 창에 크게 보여줄 마지막 내용 ----

  VoiceNotice? notice;
  int _noticeId = 0;

  void _showNotice(String headline) {
    notice = VoiceNotice(++_noticeId, headline);
  }

  void dismissNotice() {
    if (notice == null) return;
    notice = null;
    notifyListeners();
  }

  void swap() {
    from = from.other;
    _prefs?.setString('from', from == Currency.krw ? 'krw' : 'vnd');
    notifyListeners();
  }

  /// 입력 금액 (수식 계산 결과). 0으로 나누면 null.
  double? get inputValue => evaluate(expr);

  /// 결과 금액. 환율이 없거나 계산 불가면 null.
  double? get resultValue {
    final v = inputValue;
    if (v == null || rate == null) return null;
    return convert(v, from);
  }

  double convert(num amount, Currency src) =>
      src == Currency.vnd ? amount / rate! : amount * rate!;

  /// 수수료를 뗀 뒤 실제로 받는 금액에 가까운 값
  double withFee(double v) => v * (1 - feePercent / 100);

  // ---- 환산표 / 지폐 / 메모 ----

  void setTableFrom(Currency c) {
    tableFrom = c;
    notifyListeners();
  }

  void changeNote(int value, int delta) {
    final n = ((noteCounts[value] ?? 0) + delta).clamp(0, 999);
    noteCounts = {...noteCounts, value: n};
    _saveNotes();
    notifyListeners();
  }

  void resetNotes() {
    noteCounts = {};
    _saveNotes();
    notifyListeners();
  }

  void _saveNotes() {
    _prefs?.setString(
      'notes',
      jsonEncode(noteCounts.map((k, v) => MapEntry(k.toString(), v))),
    );
  }

  int get notesTotal =>
      noteCounts.entries.fold(0, (sum, e) => sum + e.key * e.value);

  void setMemo(String text) {
    memo = text;
    _memoTimer?.cancel();
    _memoTimer = Timer(const Duration(milliseconds: 400), saveMemoNow);
  }

  void saveMemoNow() {
    _memoTimer?.cancel();
    _prefs?.setString('memo', memo);
  }

  @override
  void dispose() {
    saveMemoNow();
    super.dispose();
  }
}

/// 크게 보여줄 확인 내용
class VoiceNotice {
  const VoiceNotice(this.id, this.headline);
  final int id;
  final String headline;
}
