package org.myapp.vn_currency

import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var bridge: AppBridge? = null

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
