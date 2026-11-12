import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vn_currency/core/rate_service.dart';
import 'package:vn_currency/state/app_state.dart';
import 'package:vn_currency/ui/voice_popup.dart';

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
  testWidgets('홈 화면 음성 창: 음성 창과 "앱으로 이동"이 보임', (tester) async {
    final s = await makeState();
    s.openVoice();
    await tester.pumpWidget(VoicePopupApp(state: s));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('앱으로 이동'), findsOneWidget);
    expect(find.text('버튼을 누른 채로 말하세요'), findsOneWidget);
    expect(find.text('전체 지우기'), findsOneWidget);
  });

  test('팝업에서 "앱으로 이동": 앱이 그 식을 이어받고 최근 계산에도 남음', () async {
    final popup = await makeState();
    popup.expr = '50000+30000';
    popup.archiveExpr();
    await popup.handOffToApp();

    // 같은 저장소를 쓰는 앱 (실제로는 다른 화면)
    final prefs = await SharedPreferences.getInstance();
    final app = AppState(
      service: RateService(
        client: MockClient((_) async => http.Response(_body, 200)),
      ),
      prefs: prefs,
    );
    await app.load();
    app.expr = '7000';
    await app.syncFromPopup();
    expect(app.expr, '50000+30000');
    expect(prefs.getString('handoff'), isNull);
    // 앱에서 입력 중이던 7000도 최근 계산에 남음
    expect(
      app.history.map((e) => e.expr),
      containsAll(['50000+30000', '7000']),
    );
    // 이어받은 식을 고쳐서 지워도 칸이 늘지 않음
    final before = app.history.length;
    app.press('+');
    app.press('1');
    app.press('C');
    expect(app.history.length, before);
  });
}
