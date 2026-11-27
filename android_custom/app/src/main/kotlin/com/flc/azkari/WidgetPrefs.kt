package com.flc.azkari

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONObject

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

    // ---------------------------------------------------------------------
    // سجل الضغطات لكل ذكر (المصدر الموثوق لضغطات الودجت).
    //
    // السبب: عدّاد الويدجت المعروض يُصفَّر عند تبديل الذكر، فلو اعتمد التطبيق
    // على العدّاد وحده لضاعت ضغطات الأذكار السابقة عند التبديل (A → B → A).
    // لذلك يحتفظ الجانب الأصلي بمجموع الضغطات مدى الحياة **لكل ذكر**، والتطبيق
    // يحفظ «علامة مائية» (ما استهلكه فعلاً) ويستهلك الفرق فقط.
    //
    // الخصائص: المجاميع لا تتناقص أبداً، والقراءة لا تستهلكها (الاستهلاك عند
    // التطبيق)، ولذلك إغلاق التطبيق أو تكرار المزامنة لا يفقد ولا يضاعف شيئاً.
    // ---------------------------------------------------------------------
    const val KEY_TOTALS = "widget_totals"
    const val KEY_TOTALS_SCHEMA = "widget_totals_schema"

    /**
     * الذكر الذي بُذر رصيده من العدّاد المعروض لحظة الترقية.
     *
     * التطبيق يستخدمه ليبدأ علامته المائية من عدّاده المحفوظ لهذا الذكر فقط
     * (لأن الرصيد المزروع يمثّل ضغطات سابقة استوعبها التطبيق أصلاً)، بينما تبدأ
     * بقية الأذكار من صفر لأن ضغطاتها جديدة بالكامل.
     */
    const val KEY_TOTALS_SEED_ZIKR = "widget_totals_seed_zikr"
    const val TOTALS_SCHEMA_V1 = "1"

    fun readTotals(context: Context): MutableMap<String, Int> {
        val out = linkedMapOf<String, Int>()
        val raw = readString(context, KEY_TOTALS, "")
        if (raw.isBlank()) return out
        try {
            val obj = JSONObject(raw)
            for (key in obj.keys()) out[key] = obj.optInt(key, 0)
        } catch (_: Exception) {
            // بيانات تالفة: نبدأ من سجل فارغ بدل إسقاط العملية.
        }
        return out
    }

    fun writeTotals(context: Context, totals: Map<String, Int>) {
        val obj = JSONObject()
        totals.forEach { (key, value) -> obj.put(key, value) }
        writeString(context, KEY_TOTALS, obj.toString())
    }

    /**
     * تهيئة السجل مرة واحدة عند الترقية من إصدار قديم: نعتبر العدّاد المعروض
     * للذكر الحالي رصيداً سابقاً (الخط الأساس) حتى لا يُضاف مرتين.
     */
    fun ensureTotalsSchema(context: Context) {
        if (readString(context, KEY_TOTALS_SCHEMA, "") == TOTALS_SCHEMA_V1) return
        val totals = readTotals(context)
        val current = readString(context, "widget_zikr", "").trim()
        val display = readInt(context, "widget_count", 0)
        if (current.isNotEmpty() && display > 0 && !totals.containsKey(current)) {
            totals[current] = display
            writeString(context, KEY_TOTALS_SEED_ZIKR, current)
        }
        writeTotals(context, totals)
        writeString(context, KEY_TOTALS_SCHEMA, TOTALS_SCHEMA_V1)
    }

    /** يسجّل ضغطة واحدة على الذكر المعطى (داخل سجل الضغطات الدائم). */
    fun recordPress(context: Context, zikr: String) {
        ensureTotalsSchema(context)
        val phrase = zikr.trim()
        if (phrase.isEmpty()) return
        val totals = readTotals(context)
        totals[phrase] = (totals[phrase] ?: 0) + 1
        writeTotals(context, totals)
    }
}
