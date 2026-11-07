import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/money.dart';
import '../core/rate_service.dart';
import '../core/voice.dart';

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

  Future<void> load() async {
    final p = _prefs ??= await SharedPreferences.getInstance();
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
    for (final t in options) {
      final step = applySpoken(expr, t, addMode: addMode);
      if (step.changed && step.message == null) return t;
    }
    for (final t in options) {
      if (applySpoken(expr, t, addMode: addMode).changed) return t;
    }
    return options.first;
  }

  void _updatePreview() {
    final best = _bestHeard();
    heard = best ?? '';
    final step = best == null
        ? null
        : applySpoken(expr, best, addMode: addMode);
    preview = (step != null && step.changed) ? step.headline : null;
  }

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
      notifyListeners();
    }

    late Future<String?> Function() listen;
    listen = () => voice.start(
      onReady: () {
        voiceReady = true;
        if (!wasReady) HapticFeedback.mediumImpact();
        wasReady = true;
        notifyListeners();
      },
      onText: (cands, isFinal) {
        _candidates = cands;
        _updatePreview();
        notifyListeners();
        if (isFinal && _released) finish();
      },
      onDone: () {
        if (_released || _applied) {
          finish();
          return;
        }
        // 아직 누르고 있는데 폰 음성인식이 혼자 끝남(잠깐 쉼) → 모아 두고 다시 듣기
        final cur = _candidates.isEmpty ? '' : _candidates.first;
        if (cur.isNotEmpty) _segments.add(cur);
        _candidates = const [];
        Future.delayed(const Duration(milliseconds: 150), () async {
          if (_released || _applied) return finish();
          final err = await listen();
          if (err != null) finish();
        });
      },
      onError: (m) {
        // 누르고 있는 중 "못 들음"은 다시 듣기로 넘기고, 나머지 오류만 알림
        if (!_released && m.startsWith('잘 안 들렸어요')) return;
        report(m);
        finish();
      },
    );

    _finish = finish;
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
      // 시작이 끝나기 전에 이미 손을 뗀 경우
      if (_released) await voice.stop();
    }
  }

  /// 손을 떼면 멈추고, 마지막 인식 결과를 기다렸다(최대 3초) 반영
  void releaseTalk() {
    if (!listening || _released) return;
    _released = true;
    _voice?.stop();
    _releaseTimer?.cancel();
    _releaseTimer = Timer(const Duration(seconds: 3), () => _finish?.call());
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
