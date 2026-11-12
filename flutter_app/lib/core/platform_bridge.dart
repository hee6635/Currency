import 'package:flutter/services.dart';

/// 안드로이드 쪽(홈 화면 위젯, 음성 팝업 창)과 주고받기.
/// 웹·테스트처럼 안드로이드가 아니면 조용히 아무것도 안 한다.
class PlatformBridge {
  static const _ch = MethodChannel('vn_currency/app');

  /// 홈 화면 위젯에 보여줄 환율을 넘기고 위젯을 다시 그리게 한다
  static Future<void> updateWidget({
    required double rate,
    required DateTime time,
  }) => _call('updateWidget', {
    'rate': rate,
    'time': time.millisecondsSinceEpoch,
  });

  /// 음성 팝업 창에서 전체 앱 열기
  static Future<void> openMainApp() => _call('openMainApp');

  /// 음성 팝업 창 닫기
  static Future<void> closePopup() => _call('closePopup');

  static Future<void> _call(String m, [Object? args]) async {
    try {
      await _ch.invokeMethod<void>(m, args);
    } catch (_) {}
  }
}
