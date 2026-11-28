package com.flc.azkari

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import java.io.File

/**
 * اختبار تكامل لتخزين Android **الحقيقي**: `WidgetPrefs.stateStore` فوق
 * `SharedPreferences` الفعلية (Robolectric)، لا مخزن وهمي.
 *
 * يتحقق من:
 * 1. أن العداد والسجل والمراجعة تُكتب في `Editor` واحد ثم `commit()`.
 * 2. أن البيانات موجودة في ملف التفضيلات على القرص (XML) — أي أنها أُثبتت، وليست
 *    في الذاكرة فقط.
 * 3. أن قراءة جديدة (كائن `pressLog` جديد / `SharedPreferences` جديدة) تعيد نفس
 *    القيم، بما يحاكي إعادة تشغيل العملية.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class WidgetPrefsStorageTest {

    private val context: Context get() = ApplicationProvider.getApplicationContext()

    private fun prefsFile(): File =
        File(File(context.applicationInfo.dataDir, "shared_prefs"), "${WidgetPrefs.FILE}.xml")

    @Test
    fun pressWritesCountTotalsAndRevisionToDiskInOneCommit() {
        val log = WidgetPrefs.pressLog(context)
        val result = log.press("سبحان الله")
        assertTrue(result is PressResult.Applied)
        result as PressResult.Applied

        // (1) القيم عبر التخزين الحقيقي.
        assertEquals(1, WidgetPrefs.readInt(context, TasbihKeys.COUNT, 0))
        assertEquals(1, WidgetPrefs.readInt(context, TasbihKeys.LIFETIME, 0))
        assertEquals(1, WidgetPrefs.readInt(context, TasbihKeys.REVISION, 0))
        assertEquals(1, WidgetPrefs.pressLog(context).readTotals()["سبحان الله"])

        // (2) على القرص فعليًا.
        val file = prefsFile()
        assertTrue("ملف التفضيلات يجب أن يكون موجودًا على القرص", file.exists())
        val xml = file.readText()
        assertTrue(xml.contains("widget_count"))
        assertTrue(xml.contains("widget_lifetime"))
        assertTrue(xml.contains("widget_totals"))
        assertTrue(xml.contains("widget_revision"))
        assertTrue(xml.contains("widget_totals_schema"))
    }

    @Test
    fun stateSurvivesFreshPreferenceObjects() {
        WidgetPrefs.pressLog(context).press("سبحان الله")
        WidgetPrefs.pressLog(context).press("سبحان الله")
        WidgetPrefs.pressLog(context).switchZikr("أستغفر الله")
        WidgetPrefs.pressLog(context).press("أستغفر الله")

        // كائنات SharedPreferences جديدة تُبنى من نفس الملف (كأن العملية أُعيد تشغيلها).
        val fresh = context.getSharedPreferences(WidgetPrefs.FILE, Context.MODE_PRIVATE)
        val store = WidgetPrefs.stateStore(context)
        val counts = TasbihPressLog(store).readTotals()

        assertEquals(2, counts["سبحان الله"])
        assertEquals(1, counts["أستغفر الله"])
        assertEquals(0, fresh.getInt(TasbihKeys.COUNT, -1))
        assertEquals("أستغفر الله", fresh.getString(TasbihKeys.ZIKR, null))
        assertEquals(4, WidgetPrefs.readInt(context, TasbihKeys.REVISION, 0))
        assertEquals(3, WidgetPrefs.readInt(context, TasbihKeys.LIFETIME, 0))
    }

    @Test
    fun upgradeKeepsLegacyDisplayAsSeedWithoutDoubleCounting() {
        // محاكاة جهاز مُرقّى: عدّاد قديم 12 بلا سجل ولا schema.
        context.getSharedPreferences(WidgetPrefs.FILE, Context.MODE_PRIVATE)
            .edit()
            .putString(TasbihKeys.ZIKR, "سبحان الله")
            .putInt(TasbihKeys.COUNT, 12)
            .putInt(TasbihKeys.LIFETIME, 12)
            .commit()

        WidgetPrefs.pressLog(context).press("سبحان الله")

        assertEquals(13, WidgetPrefs.readInt(context, TasbihKeys.COUNT, 0))
        assertEquals(13, WidgetPrefs.pressLog(context).readTotals()["سبحان الله"])
        assertEquals(
            "سبحان الله",
            WidgetPrefs.readString(context, TasbihKeys.TOTALS_SEED_ZIKR, "")
        )
        assertEquals(1, WidgetPrefs.readInt(context, TasbihKeys.REVISION, 0))
    }

    @Test
    fun commitResultIsVerifiedBeforeReportingSuccess() {
        // لا نستطيع إجبار commit() على الفشل داخل Robolectric، لكن نتحقق من
        // السلوك الإيجابي: بعد كل ضغطة تأكيد، القيم مقروءة من الملف مباشرة.
        assertTrue(WidgetPressHandlers.increment(WidgetPrefs.stateStore(context), "سبحان الله"))
        val xml = prefsFile().readText()
        assertTrue(xml.contains("widget_revision"))
        assertNotNull(WidgetPrefs.readString(context, TasbihKeys.TOTALS, null))

        // وبعد فشل التخزين (مخزن يفشل في التأكيد) لا يُعلن النجاح ولا يتغيّر شيء.
        val failing = object : WidgetStateStore {
            override fun getString(key: String, fallback: String) = fallback
            override fun getInt(key: String, fallback: Int) = fallback
            override fun apply(writes: Map<String, Any>) = throw IllegalStateException("commit failed")
        }
        val countBefore = WidgetPrefs.readInt(context, TasbihKeys.COUNT, 0)
        assertEquals(false, WidgetPressHandlers.increment(failing, "سبحان الله"))
        assertEquals(countBefore, WidgetPrefs.readInt(context, TasbihKeys.COUNT, 0))
    }

    @Test
    fun totalsAreNotWrittenWithoutRevision() {
        WidgetPrefs.pressLog(context).press("سبحان الله")
        val fresh = context.getSharedPreferences(WidgetPrefs.FILE, Context.MODE_PRIVATE)
        // المفتاحان موجودان معًا دائمًا بعد أي ضغطة.
        assertTrue(fresh.contains(TasbihKeys.TOTALS))
        assertTrue(fresh.contains(TasbihKeys.REVISION))
    }
}
