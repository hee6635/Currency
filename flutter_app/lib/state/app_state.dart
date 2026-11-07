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

  /// 무전기 방식: 누르는 순간 듣기 시작
  Future<void> pressTalk(void Function(String) onMessage) async {
    if (listening) return;
    final voice = _voice ??= VoiceInput();
    listening = true;
    voiceReady = false;
    heard = '';
    _released = false;
    _applied = false;
    notifyListeners();

    void finish() {
      if (_applied) return;
      _applied = true;
      _releaseTimer?.cancel();
      listening = false;
      voiceReady = false;
      if (heard.isNotEmpty) {
        final msg = applyHeard(heard);
        if (msg != null) onMessage(msg);
      }
      notifyListeners();
    }

    _finish = finish;
    final err = await voice.start(
      onReady: () {
        voiceReady = true;
        HapticFeedback.mediumImpact();
        notifyListeners();
      },
      onText: (text, isFinal) {
        heard = text;
        notifyListeners();
        if (isFinal && _released) finish();
      },
      // 손을 떼기 전에 음성인식이 스스로 끝나면(오래 조용함) 그때까지 들은 것 반영
      onDone: finish,
      onError: (m) {
        onMessage(m);
        finish();
      },
    );
    if (err != null) {
      listening = false;
      _applied = true;
      notifyListeners();
      onMessage(err);
    } else if (_released) {
      // 시작이 끝나기 전에 이미 손을 뗀 경우
      await voice.stop();
    }
  }

  /// 손을 떼면 멈추고, 마지막 인식 결과를 잠깐(최대 1.2초) 기다렸다 반영
  void releaseTalk() {
    if (!listening || _released) return;
    _released = true;
    _voice?.stop();
    _releaseTimer?.cancel();
    _releaseTimer = Timer(
      const Duration(milliseconds: 1200),
      () => _finish?.call(),
    );
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
