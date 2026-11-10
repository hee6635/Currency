import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vn_currency/core/calc_history.dart';
import 'package:vn_currency/core/rate_service.dart';
import 'package:vn_currency/state/app_state.dart';

const _body =
    '{"result":"success","time_last_update_unix":1792800000,"rates":{"KRW":1,"VND":18.5}}';

Future<AppState> makeState([Map<String, Object> saved = const {}]) async {
  SharedPreferences.setMockInitialValues(saved);
  final s = AppState(
    service: RateService(
      client: MockClient((_) async => http.Response(_body, 200)),
    ),
    prefs: await SharedPreferences.getInstance(),
  );
  await s.load();
  return s;
}

void main() {
  test('C로 지우면 최근 계산에 남고, 최근 5개까지만', () async {
    final s = await makeState();
    for (var i = 1; i <= 7; i++) {
      s.expr = '${i}000+500';
      s.press('C');
    }
    expect(s.expr, '');
    expect(s.history.length, 5);
    expect(s.history.first.expr, '7000+500');
    expect(s.history.last.expr, '3000+500');
  });

  test('빈 식이나 0만 있는 식은 남기지 않음', () async {
    final s = await makeState();
    s.press('C');
    s.expr = '0';
    s.archiveExpr();
    expect(s.history, isEmpty);
  });

  test('불러온 식을 고쳐서 다시 지우면 새로 늘지 않고 그 칸이 바뀌어 맨 위로', () async {
    final s = await makeState();
    s.expr = '50000';
    s.press('C');
    s.expr = '30000';
    s.press('C');
    expect(s.history.map((e) => e.expr), ['30000', '50000']);

    s.loadHistory(s.history[1]); // 50000 불러오기
    expect(s.expr, '50000');
    s.press('+');
    s.press('1');
    s.press('000');
    expect(s.expr, '50000+1000');
    s.press('C');
    expect(s.history.map((e) => e.expr), ['50000+1000', '30000']);
  });

  test('입력 중에 다른 걸 불러오면 입력 중이던 식도 남음', () async {
    final s = await makeState();
    s.expr = '50000';
    s.press('C');
    s.expr = '70000+2000';
    s.loadHistory(s.history.first);
    expect(s.expr, '50000');
    expect(s.history.map((e) => e.expr), ['70000+2000', '50000']);
  });

  test('말로 "다 지워", 전체 지우기 버튼도 남기고, 되돌리면 칸이 늘지 않음', () async {
    final s = await makeState();
    s.expr = '50000+30000';
    s.applyHeard('다 지워');
    expect(s.expr, '');
    expect(s.history.first.expr, '50000+30000');

    s.expr = '20000';
    final before = s.voiceClearAll();
    expect(s.history.first.expr, '20000');
    s.restoreExpr(before);
    s.press('+');
    s.press('5');
    s.press('C');
    expect(s.history.map((e) => e.expr), ['20000+5', '50000+30000']);
  });

  test('앱을 닫을 때 하던 식도 남고, 다시 켜면 입력창은 비고 목록은 그대로', () async {
    final s = await makeState();
    s.expr = '150000+30000';
    s.archiveExpr(); // 앱이 백그라운드로 갈 때
    final saved = (await SharedPreferences.getInstance()).getString('history')!;

    final again = await makeState({'history': saved});
    expect(again.expr, '');
    expect(again.history.single.expr, '150000+30000');
  });

  test('저장 형식이 깨져도 앱이 멈추지 않음', () {
    expect(CalcHistory.decode('망가진 값'), isEmpty);
    expect(CalcHistory.decode(null), isEmpty);
  });
}
