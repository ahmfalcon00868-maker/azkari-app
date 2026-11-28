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

    const val KEY_REVISION = TasbihKeys.REVISION

    fun readRevision(context: Context): Int =
        readInt(context, KEY_REVISION, 0)

    /**
     * تنفيذ [WidgetStateStore] فوق SharedPreferences بمعاملة واحدة (`commit`).
     *
     * `commit()` متزامن عن قصد: نضمن أن ما كتبناه (الضغطة + المراجعة + السجل +
     * التهيئة) صار على القرص قبل عرض الويدجت وقبل أن يقرأه التطبيق.
     */
    fun stateStore(context: Context): WidgetStateStore = object : WidgetStateStore {
        override fun getString(key: String, fallback: String): String =
            readString(context, key, fallback)

        override fun getInt(key: String, fallback: Int): Int =
            readInt(context, key, fallback)

        override fun apply(writes: Map<String, Any>) {
            // محاولتان: الكتابة الأولى قد تفشل (قرص ممتلئ/خطأ I/O)، ولا نعتبر
            // العملية ناجحة أبدًا دون `commit() == true`.
            repeat(2) { attempt ->
                val editor = of(context).edit()
                writes.forEach { (key, value) ->
                    when (value) {
                        is Int -> editor.putInt(key, value)
                        is Boolean -> editor.putBoolean(key, value)
                        else -> editor.putString(key, value.toString())
                    }
                }
                if (editor.commit()) return
                if (attempt == 1) {
                    throw IllegalStateException("SharedPreferences commit failed")
                }
            }
        }
    }

    /** سجل الضغطات الذرّي (المصدر الوحيد لتعديل عدّاد الويدجت). */
    fun pressLog(context: Context): TasbihPressLog = TasbihPressLog(stateStore(context))
}
