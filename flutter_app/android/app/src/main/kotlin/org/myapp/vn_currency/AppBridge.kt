package org.myapp.vn_currency

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.view.KeyEvent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter ↔ 안드로이드: 위젯에 환율 넘기기, 팝업에서 앱 열기·팝업 닫기,
 * 음성 창이 떠 있는 동안 음량 버튼을 무전기(↓ 누르고 있기)·하나 지우기(↑)로 쓰기.
 * 화면(액티비티)마다 하나씩 만든다.
 */
class AppBridge(engine: FlutterEngine, private val activity: Activity) {
    private val channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)

    /** 음성 창이 떠 있을 때만 true (평소에는 음량 버튼이 원래대로 소리 조절) */
    private var volumeKeys = false
    private var talking = false

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidget" -> {
                    val rate = call.argument<Number>("rate")?.toDouble()
                    val time = call.argument<Number>("time")?.toLong() ?: System.currentTimeMillis()
                    if (rate != null && rate > 0) {
                        activity.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                            .putString("rate", rate.toString())
                            .putLong("time", time)
                            .apply()
                        RateWidget.updateAll(activity)
                    }
                    result.success(null)
                }
                "setVolumeKeys" -> {
                    volumeKeys = call.argument<Boolean>("on") == true
                    if (!volumeKeys) talking = false
                    result.success(null)
                }
                "openMainApp" -> {
                    // 런처에서 누른 것처럼: 앱이 이미 떠 있으면 그 화면을 앞으로
                    val i = Intent(activity, MainActivity::class.java)
                        .setAction(Intent.ACTION_MAIN)
                        .addCategory(Intent.CATEGORY_LAUNCHER)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED)
                    activity.startActivity(i)
                    result.success(null)
                }
                "closePopup" -> {
                    result.success(null)
                    if (activity is VoicePopupActivity) activity.finish()
                }
                else -> result.notImplemented()
            }
        }
    }

    /** 처리했으면 true (그 버튼은 소리 조절에 쓰지 않음) */
    fun onKeyDown(keyCode: Int, event: KeyEvent): Boolean {
        if (!volumeKeys) return false
        return when (keyCode) {
            KeyEvent.KEYCODE_VOLUME_DOWN -> {
                if (event.repeatCount == 0 && !talking) {
                    talking = true
                    channel.invokeMethod("talkDown", null)
                }
                true
            }
            KeyEvent.KEYCODE_VOLUME_UP -> {
                if (event.repeatCount == 0) channel.invokeMethod("deleteOne", null)
                true
            }
            else -> false
        }
    }

    fun onKeyUp(keyCode: Int): Boolean {
        if (!volumeKeys) return false
        return when (keyCode) {
            KeyEvent.KEYCODE_VOLUME_DOWN -> {
                if (talking) {
                    talking = false
                    channel.invokeMethod("talkUp", null)
                }
                true
            }
            KeyEvent.KEYCODE_VOLUME_UP -> true
            else -> false
        }
    }

    companion object {
        private const val CHANNEL = "vn_currency/app"
        const val PREFS = "vn_widget"
    }
}
