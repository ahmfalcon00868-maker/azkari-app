package com.flc.azkari

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

/**
 * مخزن وهمي يحاكي SharedPreferences مع خاصية المعاملة الواحدة:
 * إمّا أن تُكتب كل القيم أو لا يُكتب أي منها (كما يفعل `commit()` عند موت
 * العملية قبل وصول البيانات للقرص).
 */
private class FakeStore(initial: Map<String, Any> = emptyMap()) : WidgetStateStore {
    val values: MutableMap<String, Any> = LinkedHashMap(initial)
    var applies = 0
    var crashBeforeWrite = false
    var crashAfterWrite = false

    override fun getString(key: String, fallback: String): String =
        (values[key] as? String) ?: fallback

    override fun getInt(key: String, fallback: Int): Int = when (val value = values[key]) {
        is Int -> value
        is String -> value.toIntOrNull() ?: fallback
        else -> fallback
    }

    override fun apply(writes: Map<String, Any>) {
        if (crashBeforeWrite) {
            crashBeforeWrite = false
            // انقطاع العملية قبل الكتابة: لا تتغيّر أي قيمة.
            throw IllegalStateException("simulated process death before commit")
        }
        applies += 1
        values.putAll(writes) // كتابة ذرّية لكل المفاتيح معًا
        if (crashAfterWrite) {
            crashAfterWrite = false
            throw IllegalStateException("simulated process death after commit")
        }
    }
}

private const val A = "سبحان الله"
private const val B = "أستغفر الله"

class TasbihPressLogTest {

    @Test
    fun firstPressAfterUpgrade_countsExactlyOne() {
        // جهاز مُرقّى: عدّاد قديم 12، ولا سجل ضغطات (schema مفقود).
        val store = FakeStore(
            mapOf(
                TasbihKeys.ZIKR to A,
                TasbihKeys.COUNT to 12,
                TasbihKeys.LIFETIME to 12,
            )
        )
        val log = TasbihPressLog(store)

        val result = log.press(A)

        assertTrue(result is PressResult.Applied)
        result as PressResult.Applied
        assertEquals("الضغطة الأولى بعد الترقية تُحسب مرة واحدة فقط", 13, result.count)
        assertEquals(13, store.getInt(TasbihKeys.LIFETIME))
        assertEquals(13, log.readTotals()[A])
        assertEquals(TasbihKeys.SCHEMA_V1, store.getString(TasbihKeys.TOTALS_SCHEMA))
        assertEquals(A, store.getString(TasbihKeys.TOTALS_SEED_ZIKR))
        assertEquals(1, result.revision)

        // وضغطة ثانية تزيد واحدًا فقط.
        val second = log.press(A) as PressResult.Applied
        assertEquals(14, second.count)
        assertEquals(14, log.readTotals()[A])
        assertEquals(2, second.revision)
    }

    @Test
    fun firstPressAfterUpgrade_withoutPriorWidgetUpdate() {
        // أسوأ حالة: لم يُستدعَ onUpdate إطلاقًا قبل أول ضغطة.
        val store = FakeStore(
            mapOf(
                TasbihKeys.ZIKR to A,
                TasbihKeys.COUNT to 7,
                TasbihKeys.LIFETIME to 7,
            )
        )
        val log = TasbihPressLog(store)
        log.press(A)

        assertEquals(8, store.getInt(TasbihKeys.COUNT))
        assertEquals(8, log.readTotals()[A])
        assertEquals(1, store.getInt(TasbihKeys.TOTALS_SCHEMA))
    }

    @Test
    fun seedingUsesPreIncrementDisplayValue() {
        // البذر يستخدم قيمة العدّاد قبل الزيادة (12) لا بعدها (13).
        val store = FakeStore(
            mapOf(
                TasbihKeys.ZIKR to A,
                TasbihKeys.COUNT to 12,
            )
        )
        val log = TasbihPressLog(store)
        log.ensureSchema()
        assertEquals(12, decodeTotals(store.getString(TasbihKeys.TOTALS))[A])

        log.press(A)
        assertEquals(13, log.readTotals()[A])
    }

    @Test
    fun pressIsAtomic_nothingSavedWhenProcessDiesBeforeCommit() {
        val store = FakeStore(
            mapOf(
                TasbihKeys.ZIKR to A,
                TasbihKeys.COUNT to 3,
                TasbihKeys.LIFETIME to 3,
            )
        )
        val log = TasbihPressLog(store)
        store.crashBeforeWrite = true

        try {
            log.press(A)
            fail("كان يجب أن يفشل بسبب انقطاع العملية")
        } catch (_: IllegalStateException) {
            // متوقع
        }

        // لا زيادة، ولا سجل، ولا مراجعة، ولا schema جزئي.
        assertEquals(3, store.getInt(TasbihKeys.COUNT))
        assertEquals(3, store.getInt(TasbihKeys.LIFETIME))
        assertEquals(0, store.getInt(TasbihKeys.REVISION))
        assertEquals("", store.getString(TasbihKeys.TOTALS))
        assertEquals("", store.getString(TasbihKeys.TOTALS_SCHEMA))

        // إعادة المحاولة بعد «إعادة التشغيل» تُحسب مرة واحدة.
        val retry = log.press(A) as PressResult.Applied
        assertEquals(4, retry.count)
        assertEquals(4, log.readTotals()[A])
    }

    @Test
    fun pressIsAtomic_everythingSavedWhenProcessDiesAfterCommit() {
        val store = FakeStore(
            mapOf(
                TasbihKeys.ZIKR to A,
                TasbihKeys.COUNT to 5,
            )
        )
        val log = TasbihPressLog(store)
        store.crashAfterWrite = true

        try {
            log.press(A)
            fail("كان يجب أن يفشل بعد الكتابة")
        } catch (_: IllegalStateException) {
            // متوقع
        }

        // القيم محفوظة كاملة ومتسقة معًا.
        assertEquals(6, store.getInt(TasbihKeys.COUNT))
        assertEquals(1, store.getInt(TasbihKeys.REVISION))
        assertEquals(6, log.readTotals()[A])
        assertEquals(TasbihKeys.SCHEMA_V1, store.getString(TasbihKeys.TOTALS_SCHEMA))
    }

    @Test
    fun totalsAndRevisionAreNeverSavedSeparately() {
        val store = FakeStore(mapOf(TasbihKeys.ZIKR to A, TasbihKeys.COUNT to 0))
        val log = TasbihPressLog(store)
        log.press(A)
        log.press(A)

        // بعد ضغطتين: المراجعة 2 والسجل 2 — لا يمكن أن يوجد أحدهما دون الآخر.
        assertEquals(2, store.getInt(TasbihKeys.REVISION))
        assertEquals(2, log.readTotals()[A])

        // كل ضغطة كتبت معاملة واحدة فقط (بدون كتابات منفصلة للمفاتيح).
        assertEquals(2, store.applies)
    }

    @Test
    fun switchZikrKeepsTotalsAndResetsDisplay() {
        val store = FakeStore(mapOf(TasbihKeys.ZIKR to A, TasbihKeys.COUNT to 0))
        val log = TasbihPressLog(store)
        log.press(A)
        log.press(A)
        log.press(A)

        log.switchZikr(B)

        assertEquals(B, store.getString(TasbihKeys.ZIKR))
        assertEquals(0, store.getInt(TasbihKeys.COUNT))
        // سجل الذكر السابق يبقى كما هو بعد التبديل
        assertEquals(3, log.readTotals()[A])
        assertEquals(4, store.getInt(TasbihKeys.REVISION))

        // ضغطتان على B ثم العودة إلى A: كل سجل مستقل.
        log.press(B)
        log.press(B)
        log.switchZikr(A)
        log.press(A)

        assertEquals(4, log.readTotals()[A])
        assertEquals(2, log.readTotals()[B])
    }

    @Test
    fun switchZikrOnLegacyStateSeedsBeforeSwitching() {
        val store = FakeStore(
            mapOf(
                TasbihKeys.ZIKR to A,
                TasbihKeys.COUNT to 9,
                TasbihKeys.LIFETIME to 9,
            )
        )
        val log = TasbihPressLog(store)
        log.switchZikr(B)

        // الرصيد القديم للذكر A محفوظ كبذر، والعرض صفر للذكر الجديد.
        assertEquals(9, log.readTotals()[A])
        assertEquals(0, log.readTotals()[B] ?: 0)
        assertEquals(0, store.getInt(TasbihKeys.COUNT))
        assertEquals(B, store.getString(TasbihKeys.ZIKR))
        assertEquals(A, store.getString(TasbihKeys.TOTALS_SEED_ZIKR))
    }

    @Test
    fun ensureSchemaIsIdempotent() {
        val store = FakeStore(mapOf(TasbihKeys.ZIKR to A, TasbihKeys.COUNT to 4))
        val log = TasbihPressLog(store)

        log.ensureSchema()
        val appliesAfterFirst = store.applies
        val totalsAfterFirst = log.readTotals()

        log.ensureSchema()
        log.ensureSchema()

        assertEquals(appliesAfterFirst, store.applies)
        assertEquals(totalsAfterFirst, log.readTotals())
        assertEquals(4, log.readTotals()[A])
        // التهيئة لا تزيد المراجعة
        assertEquals(0, store.getInt(TasbihKeys.REVISION))
    }

    @Test
    fun pressOnEmptyZikrIsIgnored() {
        val store = FakeStore(mapOf(TasbihKeys.COUNT to 2))
        val result = TasbihPressLog(store).press("   ")
        assertTrue(result is PressResult.Ignored)
        assertEquals(2, store.getInt(TasbihKeys.COUNT))
    }

    @Test
    fun totalsRoundTripHandlesArabicAndQuotes() {
        val totals = linkedMapOf(
            A to 5,
            "ذكر \"مقتبس\"" to 3,
            "سطر\nجديد" to 1,
            "مسار\\خلفي" to 2,
        )
        val encoded = encodeTotals(totals)
        val decoded = decodeTotals(encoded)
        assertEquals(totals, decoded)
        assertNull(decoded["غير موجود"])
        assertFalse(encoded.contains("\n"))
    }
}
