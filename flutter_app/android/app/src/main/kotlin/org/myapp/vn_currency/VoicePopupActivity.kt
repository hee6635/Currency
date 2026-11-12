package org.myapp.vn_currency

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import io.flutter.embedding.engine.FlutterEngine

/**
 * 홈 화면 위젯 · 측면 버튼(말로 환율) · 아이콘 길게 누르기로 여는 음성 입력 창.
 * 홈 화면 위에 투명하게 떠서, 앱 안의 음성 창만 보여준다 (Flutter 쪽 경로 "/voice").
 */
class VoicePopupActivity : FlutterActivity() {
    override fun getInitialRoute(): String = "/voice"

    override fun getBackgroundMode(): BackgroundMode = BackgroundMode.transparent

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        AppBridge.register(flutterEngine, this)
    }
}
