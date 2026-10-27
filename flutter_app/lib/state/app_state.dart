import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/money.dart';
import '../core/rate_service.dart';

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
    feePercent = (p.getDouble('fee') ?? 0).clamp(0, 10).toDouble();
    from = p.getString('from') == 'krw' ? Currency.krw : Currency.vnd;
    memo = p.getString('memo') ?? defaultMemo;
    try {
      final raw = jsonDecode(p.getString('notes') ?? '{}') as Map;
      noteCounts = raw.map((k, v) => MapEntry(int.parse(k as String), v as int));
    } catch (_) {
      noteCounts = {};
    }
    notifyListeners();
    if (autoUpdate || rate == null) refresh();
  }

  Future<void>? _inflight;

  /// 이미 불러오는 중이면 같은 작업을 기다린다 (중복 요청 방지)
  Future<void> refresh() => _inflight ??= _fetch().whenComplete(() => _inflight = null);

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
