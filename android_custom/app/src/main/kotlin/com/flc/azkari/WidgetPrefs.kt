package com.flc.azkari

import android.content.Context
import android.content.SharedPreferences

/** وصول موحّد لبيانات الويدجت التي يكتبها home_widget. */
object WidgetPrefs {
    const val FILE = "HomeWidgetPreferences"

    fun of(context: Context): SharedPreferences =
        context.getSharedPreferences(FILE, Context.MODE_PRIVATE)

    fun readInt(context: Context, key: String, fallback: Int): Int {
        val prefs = of(context)
        return try {
            if (prefs.contains(key)) prefs.getInt(key, fallback)
            else prefs.getString(key, null)?.toIntOrNull() ?: fallback
        } catch (_: Exception) {
            try {
                prefs.getString(key, null)?.toIntOrNull() ?: fallback
            } catch (_: Exception) {
                fallback
            }
        }
    }

    fun readBool(context: Context, key: String): Boolean {
        val prefs = of(context)
        return try {
            if (prefs.contains(key)) prefs.getBoolean(key, false)
            else prefs.getString(key, null)?.toBoolean() ?: false
        } catch (_: Exception) {
            false
        }
    }

    fun readString(context: Context, key: String, fallback: String): String {
        val prefs = of(context)
        return try {
            prefs.getString(key, null) ?: fallback
        } catch (_: Exception) {
            fallback
        }
    }

    fun writeInt(context: Context, key: String, value: Int) {
        of(context).edit().putInt(key, value).apply()
    }

    fun writeString(context: Context, key: String, value: String) {
        of(context).edit().putString(key, value).apply()
    }

    /**
     * يزيد «مراجعة» الويدجت: التطبيق يقارنها بآخر مراجعة رآها ليتبنّى ما فعله
     * المستخدم من الويدجت (ذكر جديد / عدّاد) بدل الكتابة فوقه.
     */
    fun bumpRevision(context: Context): Int {
        val next = (readRevision(context) + 1)
        writeString(context, KEY_REVISION, next.toString())
        return next
    }

    fun readRevision(context: Context): Int {
        val raw = readString(context, KEY_REVISION, "0").trim()
        return raw.toLongOrNull()?.toInt() ?: 0
    }

    const val KEY_REVISION = "widget_revision"
}
}
