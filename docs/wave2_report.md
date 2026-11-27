# تقرير الموجة الثانية (نسخة 2.2) — Azkari 1.1.0+2

> الفرع: `arena/61463075-azkari-app` · كوميت الكود الذي بُني منه الـ APK: `d6483e3`
> **لا دمج في `main`، لا Release، لا نشر، والتحديثات معطّلة (`kUpdatesEnabled = false`).**
> هذه النسخة تُبطل كل بناء سابق؛ استخدم أرتيفاكت القسم 7.

---

## 1) مزامنة الويدجت — سجل ضغطات لكل ذكر + معاملة ذرّية

### 1.1 الجانب الأصلي (Android): منطق خالص + معاملة واحدة

ملف جديد `TasbihPressLog.kt` (بلا أي `import android.*`، لذلك قابل للاختبار على JVM):

* **الترتيب الصحيح:** `press()` تُهيّئ السجل **قبل** الزيادة. البذر يأخذ قيمة العدّاد
  *قبل* الضغطة (12)، ثم تُضاف الضغطة ⇒ 13. لا 14.
* **معاملة واحدة:** التهيئة + `widget_count` + `widget_lifetime` + `widget_totals`
  + `widget_revision` + `widget_totals_seed_zikr` تُكتب في `Map` واحد يُطبَّق عبر
  `WidgetStateStore.apply` ⇒ `SharedPreferences.Editor` واحد ثم `commit()` متزامن.
  لا يمكن أن يُحفظ السجل دون مراجعة أو العكس.
* `switchZikr()` (زر تبديل الذكر): تصفير العرض + مراجعة + تهيئة السجل في معاملة واحدة،
  والسجل السابق لا يُمسّ.
* `ensureSchema()` (من `onUpdate`): تهيئة فقط، ولا تزيد المراجعة، وتتوقف إن كانت مهيّأة.
* `TasbihWidgetProvider` صار يفوّض كل شيء لـ `WidgetPrefs.pressLog(context)` بدل
  الكتابات المتفرقة (`bumpRevision`, `recordPress`, `ensureTotalsSchema` حُذفت).

### 1.2 جانب التطبيق (Dart): المراجعة داخل الحالة الذرّية

* `widget_sync_state` صار يحمل: `counts` + `seen` (العلامات المائية) + `lifetime`
  + `zikr` + **`revision`** + `v`.
* المراجعة **لم تعد تُكتب في مفتاح منفصل** قبل الحالة؛ تُثبَّت معها في كتابة واحدة.
  ولو انقطعت العملية قبلها فلا شيء استُهلك (لا عدّاد ولا مراجعة) ⇒ إعادة المحاولة تُنتج
  نفس النتيجة تمامًا.
* عند الإقلاع: المراجعة تُقرأ من الحالة الذرّية **أولًا**، والمفتاح القديم
  `widget_revision_seen` يُستخدم فقط كاحتياطي للترقية.
* الاستهلاك ما زال بالفرق: `total − watermark` لكل ذكر.

### 1.3 الاختبارات

**أ) اختبار فعلي للكود الأصلي: `TasbihPressLogTest.kt` — 11 حالة، 0 فشل**

يُشغَّل عبر مشروع Gradle/JVM مستقل (`tool/kotlin_tests/`) يترجم **نفس** ملف
`android_custom/.../TasbihPressLog.kt` المشحون في الـ APK (لا نسخة مقلّدة):

| الحالة | ما تتحقق منه |
| --- | --- |
| `firstPressAfterUpgrade_countsExactlyOne` | عدّاد قديم 12 + ضغطة واحدة ⇒ **13** (لا 14)، والضغطة الثانية ⇒ 14 |
| `firstPressAfterUpgrade_withoutPriorWidgetUpdate` | أسوأ حالة: لا `onUpdate` قبل أول ضغطة |
| `seedingUsesPreIncrementDisplayValue` | البذر بـ 12 قبل الزيادة، والسجل يصبح 13 |
| `pressIsAtomic_nothingSavedWhenProcessDiesBeforeCommit` | انقطاع قبل `commit` ⇒ لا زيادة ولا سجل ولا مراجعة، ثم إعادة المحاولة = مرة واحدة |
| `pressIsAtomic_everythingSavedWhenProcessDiesAfterCommit` | انقطاع بعد `commit` ⇒ القيم كلها محفوظة ومتسقة |
| `totalsAndRevisionAreNeverSavedSeparately` | بعد ضغطتين: مراجعة 2 وسجل 2، وعدد المعاملات = 2 فقط |
| `switchZikrKeepsTotalsAndResetsDisplay` | التبديل يصفر العرض ويحفظ سجل كل ذكر |
| `switchZikrOnLegacyStateSeedsBeforeSwitching` | التبديل على جهاز مُرقّى يبذر أولاً |
| `ensureSchemaIsIdempotent` | التهيئة لا تتكرر ولا تزيد المراجعة |
| `pressOnEmptyZikrIsIgnored` | نص فارغ لا يعدّل شيئًا |
| `totalsRoundTripHandlesArabicAndQuotes` | ترميز/فك سجل الضغطات (عربي، اقتباس، سطر جديد، شرطة مائلة) |

المخزن الوهمي في الاختبار ينفّذ «معاملة واحدة» ويستطيع محاكاة الموت قبل/بعد الكتابة.

**ب) اختبارات Dart: 79 حالة (كانت 74)، منها 18 في `tasbih_widget_sync_test.dart`**

الخمس الجديدة:

| الحالة | السيناريو |
| --- | --- |
| انقطاع بعد قراءة السجل وقبل الحفظ | إعادة التشغيل تستعيد 3 ضغطات دون فقد |
| انقطاع بعد الحفظ | إعادة التشغيل لا تعيد استهلاكها (صفر إضافة) |
| المراجعة تُستعاد من الحالة الذرّية | مفتاح قديم = 5 لا يطغى على المراجعة الذرّية = 7 |
| إعادة تشغيل مرتين مع ضغطات بينهما | لا فقد ولا مضاعفة، والإجمالي صحيح |
| حالة محفوظة من إصدار أقدم (بلا revision) | تُرقّى بأمان وتُكمل العدّ |

---

## 2) `_dayOfYear` — حساب UTC خالص

`dayOfYearUtc` تبني `DateTime.utc` للبداية واليوم ⇒ كل يوم 24 ساعة، والنتيجة لا تتأثر
بتوقيت الجهاز ولا بالتوقيت الصيفي. الاختبارات (8) تشمل: قيم تقويمية معروفة، +1 بالضبط
على مدى 365 يومًا، فروق التواريخ حول بداية/نهاية التوقيت الصيفي المصري، وعدم وجود
قفزة ساعة في مواقيت الشمس بعد التغيير.

---

## 3) سكربت حماية `main`

* الافتراضي: `Analyze & Test` فقط، مع تحقق من وجود تشغيل له على الفرع.
* `--with-freeze`: يضيف `Freeze guard (no user-facing updates)` **بعد** التأكد من وجود
  `release_guard.yml` على الفرع ونجاح آخر تشغيل له.
* `DRY_RUN=1` لطباعة الحمولة دون إرسال، و`--help`.

`main` ما زال **غير محمي** (`protection.enabled = false`)؛ توكن الجلسة يرفض إدارة
الحماية بـ 403، والتنفيذ يحتاج جلسة مالك.

---

## 4) الاختبارات والتحليل

| البند | النتيجة |
| --- | --- |
| اختبارات Dart | **79/79 ناجحة** |
| اختبارات Kotlin الأصلية | **11/11 ناجحة** (0 فشل، 0 متخطى) |
| `flutter analyze` | **0 أخطاء · 0 تحذيرات · 179 ملاحظة info** |

التوزيع: `app_core` 11 · `friday_window` 13 · `reminder_bootstrap` 5 · `scheduling` 24 ·
`sun_day_of_year` 8 · `tasbih_widget_sync` 18.

**Manifest:** `AD_ID` غير موجود في الـ APK المدمج، `usesCleartextTraffic=false`،
وفحصا البناء ناجحان. **التحديثات:** `updatesActive=false`، `Freeze guard` يعمل،
ولا Release ولا أصول مرفوعة. **اسم الـ workflow:** `Build Azkari v1.1.0+2 APK`.

---

## 5) التوقيع — ما قيس فعليًا فقط

```
certificate SHA-256: 6656d6533ffc1fa5343cc223c7d8f30b402d9cae80dc76df7f21fcaffead7d3d
```

**لا مقارنة مع شهادة `1.0.0+1`** ولم يُستنتج التوافق: أصول الـ Release غير قابلة للتنزيل
من الجلسة، ومن CI التوكن للقراءة فقط (`/releases` → `[]`). للتحقق عندك:

```bash
apksigner verify --print-certs azkari-1.0.0.apk
apksigner verify --print-certs Azkari-1.1.0+2.apk
adb install -r Azkari-1.1.0+2.apk     # تحديث مكاني، بلا حذف
```

---

## 6) مسار اختبار Kotlin في CI

`.github/workflows/build_apk.yml` → خطوة `Run native widget logic tests (Kotlin/JVM)`:

```bash
cd android && ./gradlew -p ../tool/kotlin_tests test --no-daemon
python3 tool/android_test_stats.py tool/kotlin_tests/build/test-results/test
```

تُطبع النتيجة أيضًا كتعليق قابل للقراءة على التشغيل
(`native unit tests: 11 run, 0 failed, 0 skipped`). سبب اختيار مشروع مستقل: مصدر
اختبارات وحدة AGP 9 (built-in Kotlin) لم يستطع رؤية `src/test/kotlin` في هذا المشروع
المولَّد، والمشروع المستقل يترجم نفس الملف المشحون بلا أي محاكاة.

---

## 7) الـ APK الداخلي

| البند | القيمة |
| --- | --- |
| Build run | https://github.com/ahmfalcon00868-maker/azkari-app/actions/runs/46083848726 |
| Code checks | https://github.com/ahmfalcon00868-maker/azkari-app/actions/runs/46083849021 |
| كوميت البناء | `d6483e3` |
| الأرتيفاكت | `Azkari-1.1.0-2-sha256-f321e06c…-cert-6656d653…-tests-79-apk-bytes-64768763` |
| **حجم الـ APK الحقيقي** | **64,768,763 بايت (61.76 م.ب)** |
| حجم ملف ZIP المحمّل | ~32.3 م.ب (ليس مقياسًا للـ APK) |
| **SHA-256 للـ APK** | `f321e06c9810bb13a8063eda570564f9761f14eec3f274d1c1f14178123b537d` |
| SHA-256 للشهادة | `6656d6533ffc1fa5343cc223c7d8f30b402d9cae80dc76df7f21fcaffead7d3d` |
| الإصدار | `1.1.0+2` (versionCode 2) |
| الاختبارات | 79 Dart + 11 Kotlin |

---

## 8) ما لم يكتمل

1. **حماية `main` غير مفعّلة** (403 من الـ API) — السكربت والخطوات جاهزان.
2. **مقارنة شهادة 1.0.0** غير ممكنة آليًا من هذه البيئة، ولم أفترض التوافق.
3. **179 ملاحظة info** — إهمالات إصدار Flutter، تحتاج قرار ترقية مستقل.

---

## 9) الملفات المتغيرة في هذه الجولة

`android_custom/app/src/main/kotlin/com/flc/azkari/TasbihPressLog.kt` (جديد) ·
`android_custom/app/src/main/kotlin/com/flc/azkari/WidgetPrefs.kt` ·
`android_custom/app/src/main/kotlin/com/flc/azkari/TasbihWidgetProvider.kt` ·
`android_custom/app/src/test/kotlin/com/flc/azkari/TasbihPressLogTest.kt` (جديد) ·
`tool/kotlin_tests/{settings,build}.gradle.kts` (جديد) · `tool/android_test_stats.py` (جديد) ·
`tool/gradle_failure_summary.py` (جديد) · `lib/main.dart` · `test/tasbih_widget_sync_test.dart` ·
`.github/workflows/build_apk.yml` · `docs/wave2_report.md`
