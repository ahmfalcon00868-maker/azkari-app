package com.flc.azkari

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.widget.RemoteViews

import es.antonborri.home_widget.HomeWidgetLaunchIntent

/** ويدجت «السبحة والذكر السريع»: ذكر متجدد + عداد يزيد من الشاشة الرئيسية. */
class TasbihWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_INC = "com.flc.azkari.TASBIH_WIDGET_INC"
        const val ACTION_NEXT = "com.flc.azkari.TASBIH_WIDGET_NEXT"
        const val KEY_ZIKR = "widget_zikr"
        const val KEY_COUNT = "widget_count"
        const val KEY_LIFETIME = "widget_lifetime"

        private val ZIKR_POOL = arrayOf(
            "سبحان الله وبحمده",
            "سبحان الله العظيم",
            "أستغفر الله العظيم وأتوب إليه",
            "الحمد لله رب العالمين",
            "لا إله إلا الله وحده لا شريك له",
            "الله أكبر كبيرا والحمد لله كثيرا",
            "لا حول ولا قوة إلا بالله",
            "اللهم صل وسلم على نبينا محمد"
        )
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
        when (intent.action) {
            ACTION_INC -> {
                val count = WidgetPrefs.readInt(context, KEY_COUNT, 0) + 1
                val lifetime = WidgetPrefs.readInt(context, KEY_LIFETIME, 0) + 1
                WidgetPrefs.writeInt(context, KEY_COUNT, count)
                WidgetPrefs.writeInt(context, KEY_LIFETIME, lifetime)
                WidgetPrefs.bumpRevision(context)
                refreshAll(context)
            }
            ACTION_NEXT -> {
                val current = WidgetPrefs.readString(context, KEY_ZIKR, "")
                val idx = ZIKR_POOL.indexOf(current)
                val next = ZIKR_POOL[(idx + 1) % ZIKR_POOL.size]
                WidgetPrefs.writeString(context, KEY_ZIKR, next)
                // ذكر جديد => عدّاد جديد (التطبيق سيضيف رصيده المحفوظ لهذا الذكر)
                WidgetPrefs.writeInt(context, KEY_COUNT, 0)
                WidgetPrefs.bumpRevision(context)
                refreshAll(context)
            }
            else -> refreshAll(context)
        }
    }

    private fun refreshAll(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val ids = manager.getAppWidgetIds(
            ComponentName(context, TasbihWidgetProvider::class.java)
        )
        ids.forEach { id -> render(context, manager, id) }
    }

    private fun render(
        context: Context,
        manager: AppWidgetManager,
        widgetId: Int
    ) {
        val count = WidgetPrefs.readInt(context, KEY_COUNT, 0)
        val zikr = WidgetPrefs.readString(context, KEY_ZIKR, "سبحان الله وبحمده")

        val views = RemoteViews(context.packageName, R.layout.widget_tasbih)
        views.setTextViewText(R.id.widget_zikr_text, zikr)
        views.setTextViewText(R.id.widget_count_text, count.toString())

        val incIntent = Intent(context, TasbihWidgetProvider::class.java).apply {
            action = ACTION_INC
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
        }
        val incPending = PendingIntent.getBroadcast(
            context,
            widgetId * 10 + 1,
            incIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_count_text, incPending)
        views.setOnClickPendingIntent(R.id.widget_count_ring, incPending)

        val nextIntent = Intent(context, TasbihWidgetProvider::class.java).apply {
            action = ACTION_NEXT
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
        }
        val nextPending = PendingIntent.getBroadcast(
            context,
            widgetId * 10 + 2,
            nextIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_zikr_text, nextPending)

        val openPending = HomeWidgetLaunchIntent.getActivity(
            context,
            MainActivity::class.java,
            Uri.parse("azkari://tasbih")
        )
        views.setOnClickPendingIntent(R.id.widget_title, openPending)
        views.setOnClickPendingIntent(R.id.widget_root, openPending)

        manager.updateAppWidget(widgetId, views)
    }
}
