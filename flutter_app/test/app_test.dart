import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vn_currency/core/money.dart';
import 'package:vn_currency/core/rate_service.dart';
import 'package:vn_currency/main.dart';
import 'package:vn_currency/state/app_state.dart';

const _body =
    '{"result":"success","time_last_update_unix":1792800000,"rates":{"KRW":1,"VND":18.5}}';

RateService fakeService({bool fail = false}) => RateService(
  client: MockClient((_) async {
    if (fail) throw http.ClientException('offline');
    return http.Response(_body, 200);
  }),
);

Future<AppState> makeState({Map<String, Object> saved = const {}, bool fail = false}) async {
  SharedPreferences.setMockInitialValues(saved);
  final s = AppState(service: fakeService(fail: fail), prefs: await SharedPreferences.getInstance());
  await s.load();
  await s.refresh();
  return s;
}

void main() {
  test('API 값과 기준 시각을 받아 저장', () async {
    final s = await makeState();
    expect(s.rate, 18.5);
    expect(s.source, RateSource.api);
    expect(s.rateTime, DateTime.fromMillisecondsSinceEpoch(1792800000 * 1000));
    final p = await SharedPreferences.getInstance();
    expect(p.getDouble('rate'), 18.5);
  });

  test('인터넷이 안 되면 저장된 환율을 그대로 쓰고 오류만 표시', () async {
    final s = await makeState(saved: {'rate': 18.2, 'rateTime': 0, 'source': 1}, fail: true);
    expect(s.rate, 18.2);
    expect(s.fetchError, isNotNull);
  });

  test('환산: 동 → 원, 원 → 동, 반올림', () async {
    final s = await makeState();
    for (final k in ['1', '8', '5', '000']) {
      s.press(k);
    }
    expect(s.inputValue, 185000);
    expect(s.resultValue, 10000);
    s.swap();
    expect(s.from, Currency.krw);
    expect(s.resultValue, 185000 * 18.5);
  });

  test('지폐 합계', () async {
    final s = await makeState();
    s.changeNote(500000, 2);
    s.changeNote(20000, 1);
    s.changeNote(20000, -5);
    expect(s.notesTotal, 1000000);
  });

  testWidgets('키패드로 입력하면 결과 카드에 원화가 뜬다', (tester) async {
    final s = await makeState();
    await tester.pumpWidget(VnCurrencyApp(state: s));
    // 커서가 계속 깜빡여서 pumpAndSettle 대신 시간만큼 진행
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('1').first);
    await tester.tap(find.text('8').first);
    await tester.tap(find.text('5').first);
    await tester.tap(find.text('000').first);
    await tester.pump(const Duration(milliseconds: 500));

    expect(s.expr, '185000');
    expect(find.text('10,000원'), findsOneWidget);
    expect(find.text('18만 5,000동'), findsOneWidget);

    // 탭 이동
    await tester.tap(find.text('보여주기'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Không đá'), findsOneWidget);
    await tester.tap(find.text('메모'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(TextField), findsOneWidget);
  });
}
