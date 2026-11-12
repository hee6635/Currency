package org.myapp.vn_currency

import android.app.Activity
import android.content.Context
import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** Flutter ↔ 안드로이드: 위젯에 환율 넘기기, 팝업에서 앱 열기·팝업 닫기 */
object AppBridge {
    private const val CHANNEL = "vn_currency/app"
    const val PREFS = "vn_widget"

    fun register(engine: FlutterEngine, activity: Activity) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
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
}
