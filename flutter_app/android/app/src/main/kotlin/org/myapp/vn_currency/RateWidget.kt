package org.myapp.vn_currency

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import java.text.DecimalFormat
import java.util.Calendar
import kotlin.math.roundToLong

/** 긴 위젯 (4×1): 환율 + 1만동·10만동 원화 + 마이크 */
class RateWidgetWide : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        RateWidget.render(context, manager, ids, R.layout.widget_wide)
    }
}

/** 정사각 위젯 (2×2): 환율 + 큰 마이크 */
class RateWidgetSquare : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        RateWidget.render(context, manager, ids, R.layout.widget_square)
    }
}

object RateWidget {
    private val comma = DecimalFormat("#,###")

    fun updateAll(context: Context) {
        val m = AppWidgetManager.getInstance(context)
        render(context, m, m.getAppWidgetIds(ComponentName(context, RateWidgetWide::class.java)), R.layout.widget_wide)
        render(context, m, m.getAppWidgetIds(ComponentName(context, RateWidgetSquare::class.java)), R.layout.widget_square)
    }

    fun render(context: Context, manager: AppWidgetManager, ids: IntArray, layout: Int) {
        if (ids.isEmpty()) return
        val p = context.getSharedPreferences(AppBridge.PREFS, Context.MODE_PRIVATE)
        val rate = p.getString("rate", null)?.toDoubleOrNull()
        val time = p.getLong("time", 0L)

        // 누르면 음성 입력 창
        val open = Intent(context, VoicePopupActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
        val pending = PendingIntent.getActivity(
            context, 0, open,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        for (id in ids) {
            val v = RemoteViews(context.packageName, layout)
            if (rate == null) {
                v.setTextViewText(R.id.rate, "앱을 한 번 열어 주세요")
                v.setTextViewText(R.id.sub, "환율을 받으면 여기에 보여요")
            } else {
                v.setTextViewText(R.id.rate, "1원 = " + String.format(java.util.Locale.US, "%.2f", rate) + "동")
                val a = comma.format((10000 / rate).roundToLong())
                val b = comma.format((100000 / rate).roundToLong())
                v.setTextViewText(R.id.sub, "1만동 ≈ ${a}원 · 10만동 ≈ ${b}원")
            }
            v.setTextViewText(R.id.time, if (time > 0) timeLabel(time) else "")
            v.setOnClickPendingIntent(R.id.root, pending)
            manager.updateAppWidget(id, v)
        }
    }

    private fun timeLabel(ms: Long): String {
        val t = Calendar.getInstance().apply { timeInMillis = ms }
        val now = Calendar.getInstance()
        val h = t.get(Calendar.HOUR_OF_DAY)
        val hm = (if (h < 12) "오전 " else "오후 ") +
            (if (h % 12 == 0) 12 else h % 12) + ":" + String.format(java.util.Locale.US, "%02d", t.get(Calendar.MINUTE))
        val sameDay = t.get(Calendar.YEAR) == now.get(Calendar.YEAR) &&
            t.get(Calendar.DAY_OF_YEAR) == now.get(Calendar.DAY_OF_YEAR)
        return if (sameDay) "$hm 갱신" else "${t.get(Calendar.MONTH) + 1}/${t.get(Calendar.DAY_OF_MONTH)} 갱신"
    }
}
