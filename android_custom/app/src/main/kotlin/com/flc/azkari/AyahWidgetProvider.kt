package com.flc.azkari

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/** ويدجت «آية اليوم وورد الأذكار»: آية + حالة أذكار الصباح/المساء. */
class AyahWidgetProvider : AppWidgetProvider() {

    companion object {
        const val KEY_AYAH = "widget_ayah"
        const val KEY_REF = "widget_ayah_ref"
        const val KEY_MORNING = "widget_morning_done"
        const val KEY_EVENING = "widget_evening_done"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        appWidgetIds.forEach { id -> render(context, appWidgetManager, id) }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(
            ComponentName(context, AyahWidgetProvider::class.java)
        )
        ids.forEach { id -> render(context, manager, id) }
    }

    private fun render(
        context: Context,
        manager: AppWidgetManager,
        widgetId: Int
    ) {
        val ayah = WidgetPrefs.readString(
            context, KEY_AYAH,
            "﴿أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ﴾"
        )
        val ref = WidgetPrefs.readString(context, KEY_REF, "الرعد ٢٨")
        val morning = WidgetPrefs.readBool(context, KEY_MORNING)
        val evening = WidgetPrefs.readBool(context, KEY_EVENING)

        val views = RemoteViews(context.packageName, R.layout.widget_ayah)
        views.setTextViewText(R.id.widget_ayah_text, ayah)
        views.setTextViewText(R.id.widget_ayah_ref, ref)
        views.setTextViewText(
            R.id.widget_morning_state,
            if (morning) "الصباح: تم" else "الصباح: لم يتم"
        )
        views.setTextViewText(
            R.id.widget_evening_state,
            if (evening) "المساء: تم" else "المساء: لم يتم"
        )

        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("open_tab", "azkar")
        }
        val openPending = PendingIntent.getActivity(
            context,
            widgetId * 10 + 7,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_root, openPending)

        manager.updateAppWidget(widgetId, views)
    }
}
