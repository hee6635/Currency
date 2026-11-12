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

Future<AppState> makeState({
  Map<String, Object> saved = const {},
  bool fail = false,
}) async {
  SharedPreferences.setMockInitialValues(saved);
  final s = AppState(
    service: fakeService(fail: fail),
    prefs: await SharedPreferences.getInstance(),
  );
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
    final s = await makeState(
      saved: {'rate': 18.2, 'rateTime': 0, 'source': 1},
      fail: true,
    );
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

  test('음성 창 지우기 버튼: 하나 / 전체 / 되돌리기', () async {
    final s = await makeState();
    s.expr = '50000+30000';
    s.voiceDeleteOne();
    expect(s.expr, '50000+');
    s.voiceDeleteOne();
    expect(s.expr, '50000');
    final before = s.voiceClearAll();
    expect(s.expr, '');
    s.restoreExpr(before);
    expect(s.expr, '50000');
  });

  test('입력창에서 중간 금액을 골라 고치기', () async {
    final s = await makeState();
    s.expr = '50000+30000+20000';
    s.selectPart(1);
    expect(s.editPart, 1);
    s.press('back');
    s.press('back');
    expect(s.expr, '50000+300+20000');
    s.press('00');
    expect(s.expr, '50000+30000+20000');
    // +는 맨 끝에 새 금액
    s.press('+');
    expect(s.editPart, isNull);
    expect(s.expr, '50000+30000+20000+');
    // 마지막 금액을 고르면 그냥 맨 끝
    s.selectPart(3);
    expect(s.editPart, isNull);
    // 중간 금액을 다 지우면 빠짐
    s.expr = '50000+3+20000';
    s.selectPart(1);
    s.press('back');
    expect(s.expr, '50000+20000');
    expect(s.editPart, 0); // 바로 앞 금액(50,000)으로 커서가 감
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
    // 결과 카드(크게) + 입력창의 185,000 바로 아래 원화
    expect(find.text('10,000원'), findsOneWidget);
    expect(find.text('10,000'), findsWidgets); // 입력창 (+ 숨은 음성 창)

    // 더하면 입력창 아래에 금액마다 원화가 나온다
    await tester.tap(find.text('+').first);
    await tester.tap(find.text('3').first);
    await tester.tap(find.text('7').first);
    await tester.tap(find.text('000').first);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('37,000'), findsWidgets);
    expect(find.text('2,000'), findsWidgets); // 37,000 바로 아래
    expect(find.text('12,000원'), findsOneWidget);

    // 탭 이동
    await tester.tap(find.text('보여주기'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Không đá'), findsOneWidget);
    await tester.tap(find.text('메모'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('메모: 저장된 메모를 다 읽기 전에 화면이 떠도 사라지지 않음 (업데이트 뒤 버그)', (tester) async {
    SharedPreferences.setMockInitialValues({'memo': '야시장 가기'});
    final prefs = await SharedPreferences.getInstance();
    // 아직 load() 전 (실제 앱처럼 화면이 먼저 뜸)
    final s = AppState(service: fakeService(), prefs: prefs);
    await tester.pumpWidget(VnCurrencyApp(state: s));
    await tester.pump(const Duration(milliseconds: 300));

    // 읽기 전에 저장이 불려도 저장된 메모를 덮어쓰지 않음
    s.setMemo('기본 메모');
    s.saveMemoNow();
    expect(prefs.getString('memo'), '야시장 가기');

    await s.load();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('메모'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('야시장 가기'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '야시장 가기\n쌀국수');
    s.saveMemoNow();
    expect(prefs.getString('memo'), '야시장 가기\n쌀국수');
  });

  testWidgets('아주 작은 화면에서도 키패드가 오류 없이 그려짐', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final s = await makeState();
    await tester.pumpWidget(VnCurrencyApp(state: s));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });
}
