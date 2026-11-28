package com.flc.azkari

/**
 * مخزن قيم بسيط يُنفَّذ فوق `SharedPreferences` في التطبيق، وفوق خريطة في الذاكرة
 * في الاختبارات. العقد الوحيد المهم: [apply] **معاملة واحدة** — إمّا أن تُكتب كل
 * القيم أو لا يُكتب أي منها، حتى لو ماتت العملية في المنتصف.
 */
interface WidgetStateStore {
    fun getString(key: String, fallback: String = ""): String

    /** يقرأ عددًا صحيحًا حتى لو كان المخزَّن نصًا (توافق مع الإصدارات السابقة). */
    fun getInt(key: String, fallback: Int = 0): Int

    fun apply(writes: Map<String, Any>)
}

object TasbihKeys {
    const val ZIKR = "widget_zikr"
    const val COUNT = "widget_count"
    const val LIFETIME = "widget_lifetime"
    const val REVISION = "widget_revision"
    const val TOTALS = "widget_totals"
    const val TOTALS_SCHEMA = "widget_totals_schema"
    const val TOTALS_SEED_ZIKR = "widget_totals_seed_zikr"
    const val SCHEMA_V1 = "1"
}

sealed class PressResult {
    data class Applied(
        val count: Int,
        val lifetime: Int,
        val revision: Int,
        val totals: Map<String, Int>
    ) : PressResult()

    data class Ignored(val reason: String) : PressResult()
}

/**
 * سجل ضغطات ويدجت السبحة، منطق خالص بلا أي اعتماد على Android.
 *
 * القواعد التي تحمي الضغطات:
 * 1. **التهيئة قبل الزيادة**: عند الترقية يُبذر سجل الذكر برصيده *قبل* إضافة
 *    الضغطة، وإلا حُسبت الضغطة الأولى مرتين (12 → تزرع 13 → +1 = 14).
 * 2. **معاملة واحدة**: العداد والإجمالي والسجل والمراجعة والتهيئة تُكتب في
 *    [WidgetStateStore.apply] واحد، فلا يوجد وقت يكون فيه السجل محدَّثًا
 *    والمراجعة قديمة أو العكس.
 * 3. **المراجعة نص**: يحفظها التطبيق (home_widget) كنص، فنبقيها نصًا للتوافق.
 */
class TasbihPressLog(private val store: WidgetStateStore) {

    /** يسجّل ضغطة واحدة على الذكر المعطى داخل معاملة واحدة. */
    fun press(zikr: String): PressResult {
        val phrase = zikr.trim()
        if (phrase.isEmpty()) return PressResult.Ignored("empty-zikr")

        val writes = linkedMapOf<String, Any>()
        val totals = readTotals()
        val display = store.getInt(TasbihKeys.COUNT, 0)

        // (1) التهيئة أولاً — برصيد العدّاد الحالي وقبل أي زيادة.
        seedSchemaIfNeeded(writes, totals, phrase, display)

        // (2) ثم الضغطة نفسها.
        val count = display + 1
        val lifetime = store.getInt(TasbihKeys.LIFETIME, 0) + 1
        val revision = store.getInt(TasbihKeys.REVISION, 0) + 1
        totals[phrase] = (totals[phrase] ?: 0) + 1

        writes[TasbihKeys.COUNT] = count
        writes[TasbihKeys.LIFETIME] = lifetime
        writes[TasbihKeys.REVISION] = revision.toString()
        writes[TasbihKeys.TOTALS] = encodeTotals(totals)

        store.apply(writes)
        return PressResult.Applied(count, lifetime, revision, totals)
    }

    /** يبدّل الذكر المعروض: تصفير العرض فقط + مراجعة، في معاملة واحدة. */
    fun switchZikr(next: String): PressResult {
        val phrase = next.trim()
        if (phrase.isEmpty()) return PressResult.Ignored("empty-zikr")

        val writes = linkedMapOf<String, Any>()
        val totals = readTotals()
        seedSchemaIfNeeded(
            writes,
            totals,
            store.getString(TasbihKeys.ZIKR),
            store.getInt(TasbihKeys.COUNT, 0)
        )

        val revision = store.getInt(TasbihKeys.REVISION, 0) + 1
        val lifetime = store.getInt(TasbihKeys.LIFETIME, 0)
        writes[TasbihKeys.ZIKR] = phrase
        writes[TasbihKeys.COUNT] = 0
        writes[TasbihKeys.REVISION] = revision.toString()

        store.apply(writes)
        return PressResult.Applied(
            count = 0,
            lifetime = lifetime,
            revision = revision,
            totals = totals
        )
    }

    /** يهيّئ بنية السجل فقط (يُستدعى من onUpdate) في معاملة واحدة. */
    fun ensureSchema() {
        val writes = linkedMapOf<String, Any>()
        val totals = readTotals()
        seedSchemaIfNeeded(writes, totals, store.getString(TasbihKeys.ZIKR), store.getInt(TasbihKeys.COUNT, 0))
        if (writes.isEmpty()) return
        writes[TasbihKeys.TOTALS] = encodeTotals(totals)
        store.apply(writes)
    }

    fun readTotals(): MutableMap<String, Int> = decodeTotals(store.getString(TasbihKeys.TOTALS))

    /**
     * يضيف كتابات التهيئة إلى [writes] مرة واحدة فقط:
     * - schema = 1
     * - بذر سجل الذكر الحالي برصيد العدّاد المعروض (ضغطات سابقة استوعبها التطبيق)
     */
    private fun seedSchemaIfNeeded(
        writes: MutableMap<String, Any>,
        totals: MutableMap<String, Int>,
        currentZikr: String,
        display: Int
    ) {
        if (store.getString(TasbihKeys.TOTALS_SCHEMA) == TasbihKeys.SCHEMA_V1) return
        val phrase = currentZikr.trim()
        if (phrase.isNotEmpty() && display > 0 && !totals.containsKey(phrase)) {
            totals[phrase] = display
            writes[TasbihKeys.TOTALS_SEED_ZIKR] = phrase
        }
        writes[TasbihKeys.TOTALS_SCHEMA] = TasbihKeys.SCHEMA_V1
        writes[TasbihKeys.TOTALS] = encodeTotals(totals)
    }
}

internal fun encodeTotals(totals: Map<String, Int>): String =
    totals.entries.joinToString(prefix = "{", postfix = "}", separator = ",") { (key, value) ->
        "\"" + escapeJson(key) + "\":" + value
    }

internal fun decodeTotals(raw: String): MutableMap<String, Int> {
    val out = linkedMapOf<String, Int>()
    if (raw.isBlank()) return out
    val pattern = Regex("\"((?:[^\"\\\\]|\\\\.)*)\"\\s*:\\s*(-?\\d+)")
    pattern.findAll(raw).forEach { match ->
        val key = unescapeJson(match.groupValues[1]).trim()
        val value = match.groupValues[2].toIntOrNull() ?: 0
        if (key.isNotEmpty()) out[key] = value
    }
    return out
}

private fun escapeJson(value: String): String {
    val sb = StringBuilder(value.length + 8)
    value.forEach { c ->
        when (c) {
            '\\' -> sb.append("\\\\")
            '"' -> sb.append("\\\"")
            '\n' -> sb.append("\\n")
            '\r' -> sb.append("\\r")
            '\t' -> sb.append("\\t")
            else -> sb.append(c)
        }
    }
    return sb.toString()
}

private fun unescapeJson(value: String): String {
    val sb = StringBuilder(value.length)
    var i = 0
    while (i < value.length) {
        val c = value[i]
        if (c == '\\' && i + 1 < value.length) {
            when (val next = value[i + 1]) {
                'n' -> sb.append('\n')
                'r' -> sb.append('\r')
                't' -> sb.append('\t')
                else -> sb.append(next)
            }
            i += 2
        } else {
            sb.append(c)
            i += 1
        }
    }
    return sb.toString()
}

/**
 * نقاط دخول الويدجت: تفصل «هل تمّ الحفظ فعلاً؟» عن تحديث العرض.
 *
 * `ACTION_INC` و`ACTION_NEXT` لا يعيدان رسم الويدجت إلا إذا أعادت هذه الدالة
 * `true`، أي بعد تأكيد كتابة المعاملة على التخزين.
 */
object WidgetPressHandlers {
    fun increment(store: WidgetStateStore, zikr: String): Boolean =
        try {
            TasbihPressLog(store).press(zikr)
            true
        } catch (_: Exception) {
            false
        }

    fun switchZikr(store: WidgetStateStore, next: String): Boolean =
        try {
            TasbihPressLog(store).switchZikr(next)
            true
        } catch (_: Exception) {
            false
        }
}
