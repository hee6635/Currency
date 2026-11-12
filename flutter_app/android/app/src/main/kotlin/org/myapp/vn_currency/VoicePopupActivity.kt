package org.myapp.vn_currency

import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import io.flutter.embedding.engine.FlutterEngine

/**
 * 홈 화면 위젯 · 아이콘 길게 누르기 · 루틴의 "말로 입력" 앱 동작으로 여는 음성 입력 창.
 * 홈 화면 위에 투명하게 떠서, 앱 안의 음성 창만 보여준다 (Flutter 쪽 경로 "/voice").
 * 음량 ↓ 를 누르고 있는 동안 듣고, 음량 ↑ 는 하나 지우기.
 */
class VoicePopupActivity : FlutterActivity() {
    private var bridge: AppBridge? = null

    override fun getInitialRoute(): String = "/voice"

    override fun getBackgroundMode(): BackgroundMode = BackgroundMode.transparent

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        bridge = AppBridge(flutterEngine, this)
    }

    // Flutter 화면보다 먼저 음량 버튼을 받는다 (음성 창이 떠 있을 때만 가로챔)
    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        val b = bridge
        if (b != null) {
            val handled = when (event.action) {
                KeyEvent.ACTION_DOWN -> b.onKeyDown(event.keyCode, event)
                KeyEvent.ACTION_UP -> b.onKeyUp(event.keyCode)
                else -> false
            }
            if (handled) return true
        }
        return super.dispatchKeyEvent(event)
    }
}
