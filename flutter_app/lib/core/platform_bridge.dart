import 'package:flutter/services.dart';

/// 안드로이드 쪽(홈 화면 위젯, 음성 팝업 창)과 주고받기.
/// 웹·테스트처럼 안드로이드가 아니면 조용히 아무것도 안 한다.
class PlatformBridge {
  static const _ch = MethodChannel('vn_currency/app');

  /// 안드로이드에서 오는 버튼 신호 받기 (음량 ↓ 누름/뗌, 음량 ↑)
  static void listen(void Function(String key) onKey) {
    _ch.setMethodCallHandler((call) async => onKey(call.method));
  }

  /// 음성 창이 떠 있는 동안만 음량 버튼을 무전기·지우기로 쓴다
  static Future<void> setVolumeKeys(bool on) =>
      _call('setVolumeKeys', {'on': on});

  /// 홈 화면 위젯에 보여줄 환율을 넘기고 위젯을 다시 그리게 한다
  static Future<void> updateWidget({
    required double rate,
    required DateTime time,
  }) => _call('updateWidget', {
    'rate': rate,
    'time': time.millisecondsSinceEpoch,
  });

  /// 음성 팝업 창에서 전체 앱 열기.
  /// 잠금 화면 위라면 잠금 해제를 먼저 물어보고, 풀리면 안드로이드가 앱을 열고 창을 닫는다
  /// → 그때는 false (창을 직접 닫지 말 것).
  static Future<bool> openMainApp() async {
    try {
      return await _ch.invokeMethod<bool>('openMainApp') ?? true;
    } catch (_) {
      return true;
    }
  }

  /// 음성 팝업 창 닫기
  static Future<void> closePopup() => _call('closePopup');

  static Future<void> _call(String m, [Object? args]) async {
    try {
      await _ch.invokeMethod<void>(m, args);
    } catch (_) {}
  }
}
