# تقرير الموجة الرابعة (نسخة 2.4) — Azkari 1.1.0+2

> الفرع: `arena/61463075-azkari-app` · كوميت الكود الذي بُني منه الـ APK: `d5a8619`
> **لا دمج في `main`، لا Release، لا نشر، والتحديثات معطّلة (`kUpdatesEnabled = false`).**
> هذه النسخة تُبطل كل بناء سابق؛ استخدم أرتيفاكت القسم 7.

هذه الموجة تُغلق نقطتَي المراجعة الأخيرتين:

1. **قرار المراجعة لم يعد يعتمد على القيمة صفر** — بل على وجود `v = 2` **ووجود حقل
   `revision`** داخل الحالة الذرّية.
2. **إثبات حفظ حقيقي، لا محاكاة**: الكتابة على جانب Dart صارت بـ fsync في ملف (لا
   `setString` وحده)، وعلى جانب Android أُضيف اختبار تكامل يشغّل
   `WidgetPrefs.stateStore` فوق `SharedPreferences` **فعلية** (Robolectric)، وليس
   `FakeStore`.

---

## 1) مزامنة الويدجت — سجل ضغطات لكل ذكر + معاملة ذرّية

### 1.1 الجانب الأصلي (Android): منطق خالص + معاملة واحدة

`TasbihPressLog.kt` (بلا أي `import android.*`، لذلك قابل للاختبار على JVM):

* **الترتيب الصحيح:** `press()` تُهيّئ السجل **قبل** الزيادة. البذر يأخذ قيمة العدّاد
  *قبل* الضغطة (12)، ثم تُضاف الضغطة ⇒ 13. لا 14.
* **معاملة واحدة:** التهيئة + `widget_count` + `widget_lifetime` + `widget_totals`
  + `widget_revision` + `widget_totals_seed_zikr` تُكتب في `Map` واحد يُطبَّق عبر
  `WidgetStateStore.apply` ⇒ `SharedPreferences.Editor` واحد ثم `commit()` متزامن.
* `switchZikr()` (زر تبديل الذكر): تصفير العرض + مراجعة + تهيئة السجل في معاملة واحدة.
* `ensureSchema()` (من `onUpdate`): تهيئة فقط، ولا تزيد المراجعة.

### 1.2 جانب التطبيق (Dart): المراجعة داخل الحالة الذرّية

`widget_sync_state` يحمل: `counts` + `seen` + `lifetime` + `zikr` + **`revision`** + `v`.
الاستهلاك بالفرق: `total − watermark` لكل ذكر.

### 1.3 الإصلاح الأول: «صفر» قيمة صحيحة لا إشارة غياب

كان الاستئناف يستخدم المفتاح القديم متى كان `widgetRevisionSeen == 0`، وهذا يفسد
الحالة الحديثة التي تحمل `revision = 0` بشكل مشروع (مثلاً بعد `switchZikr` على جهاز
جديد، أو بعد إعادة ضبط المراجعة) إن وُجد مفتاح قديم بقيمة 5.

الآن القرار في `WidgetSyncState.resolveRevision(state, legacy)`:

| الحالة | المصدر | النتيجة |
| --- | --- | --- |
| حالة `v=2` **وفيها** حقل `revision` (حتى لو `0`) | الحالة الذرّية | قيمتها كما هي |
| حالة `v=2` بلا حقل `revision` | المفتاح القديم | ترقية |
| حالة أقدم (`v` مفقود أو 1) | المفتاح القديم | ترقية |
| لا حالة أصلًا | المفتاح القديم | أول تشغيل |

و`lib/main.dart` استُبدل فيه الفرع القديم بالكامل بهذا الاستدعاء، وكذلك
`_pullTasbihFromWidget` (يقرأ الحالة المتينة ثم يُقرّر).

### 1.4 الإصلاح الثاني: الحفظ الحرِج صار مُثبتًا على القرص (fsync)

`await SharedPreferences.setString(...)` **لا يعني** أن البيانات على القرص؛ قد تبقى في
الذاكرة حتى يقرّر النظام كتابتها، فتُفقد «المراجعة المستهلكة» أو العدّادات لو قُتلت
العملية. لذلك أُضيف `lib/services/widget_sync_store.dart`:

* المصدر الموثوق: ملف `widget_sync_state.json` في مجلد مستندات التطبيق، يُكتب بـ
  `writeAsString(..., flush: true)` ⇒ **fsync فعلي** قبل العودة.
* نسخة احتياطية/ترقية في `SharedPreferences` تحت نفس المفتاح `widget_sync_state`.
* القراءة: الملف أولًا، ثم نسخة التفضيلات إن غاب الملف أو كان محتواه غير JSON صالح
  (ملف تالف لا يوقف الاستعادة).
* `write()` يعيد `true` فقط عند تأكيد الإثبات (الملف أو، عند تعذّره، الاحتياط).
* `_pullTasbihFromWidget` صار **يكتب قبل أن يطبّق في الذاكرة**: إن لم يتأكد الإثبات
  لا تُعدَّل أي حالة ولا تُستهلك أي مراجعة ⇒ المحاولة القادمة تعيد نفس الخطة من نفس
  نقطة البداية (لا فقدان ولا مضاعفة).

### 1.5 الإصلاح الثالث: لا نجاح قبل تأكيد `commit()` على Android

* `WidgetPrefs.stateStore.apply` يحاول مرتين ويُطلق استثناءً إذا أعاد `commit()`
  القيمة `false` — لا يُبلَّغ عن نجاح بلا تأكيد.
* `WidgetPressHandlers` (في `TasbihPressLog.kt`، بلا Android) يعيد `true/false`،
  و`TasbihWidgetProvider` **لا يعيد رسم الويدجت** إلا عند `true` ⇒ `ACTION_INC`
  لا يعرض نجاحًا قبل اكتمال الحفظ.

---

## 2) الاختبارات — مفصولة بوضوح: منطق Kotlin مقابل تخزين Android الحقيقي

### 2.1 اختبارات **منطق** Kotlin (JVM، بلا Android) — 13 حالة، 0 فشل

تُشغَّل عبر مشروع Gradle/JVM مستقل (`tool/kotlin_tests/`) يترجم **نفس** ملف
`android_custom/.../TasbihPressLog.kt` المشحون في الـ APK (لا نسخة مقلّدة).
المخزن هنا `FakeStore` (وهمي) — وهذا مناسب تمامًا لمنطق المعاملة والموت قبل/بعد الكتابة،
لكنه **لا يُثبت** شيئًا عن القرص، ولهذا وُجد القسم 2.2.

| الحالة | ما تتحقق منه |
| --- | --- |
| `firstPressAfterUpgrade_countsExactlyOne` | عدّاد قديم 12 + ضغطة ⇒ **13** (لا 14) |
| `firstPressAfterUpgrade_withoutPriorWidgetUpdate` | أسوأ حالة: لا `onUpdate` قبل أول ضغطة |
| `seedingUsesPreIncrementDisplayValue` | البذر بـ 12 قبل الزيادة |
| `pressIsAtomic_nothingSavedWhenProcessDiesBeforeCommit` | انقطاع قبل `commit` ⇒ لا زيادة ولا سجل ولا مراجعة |
| `pressIsAtomic_everythingSavedWhenProcessDiesAfterCommit` | انقطاع بعد `commit` ⇒ كل القيم متسقة |
| `totalsAndRevisionAreNeverSavedSeparately` | مراجعة 2 وسجل 2 بعد ضغطتين، معاملتان فقط |
| `switchZikrKeepsTotalsAndResetsDisplay` | التبديل يصفر العرض ويحفظ سجل كل ذكر |
| `switchZikrOnLegacyStateSeedsBeforeSwitching` | التبديل على جهاز مُرقّى يبذر أولًا |
| `ensureSchemaIsIdempotent` | التهيئة لا تتكرر ولا تزيد المراجعة |
| `pressOnEmptyZikrIsIgnored` | نص فارغ لا يعدّل شيئًا |
| `totalsRoundTripHandlesArabicAndQuotes` | ترميز/فك السجل (عربي، اقتباس، سطر جديد، شرطة) |
| **`incrementReportsFailureWhenCommitIsNotConfirmed`** (جديد) | `commit` غير مؤكد ⇒ `false`، لا تغيير في العدّاد/المراجعة/السجل، وبعد عودة التخزين ضغطة واحدة فقط |
| **`switchZikrReportsFailureWhenCommitIsNotConfirmed`** (جديد) | التبديل لا يُعلن نجاحًا ولا يغيّر الذكر أو العدّاد |

### 2.2 اختبارات **تخزين Android الحقيقي** (Robolectric + `SharedPreferences` فعلية) — 5 حالات، 0 فشل

الملف: `android_custom/app/src/test/kotlin/com/flc/azkari/WidgetPrefsStorageTest.kt`.
لا `FakeStore` هنا إطلاقًا: الاختبار يستدعي `WidgetPrefs.pressLog(context)` و
`WidgetPrefs.stateStore(context)` فوق `SharedPreferences` حقيقية، ويقرأ **ملف XML
على القرص** للتأكد أن الكتابة أُثبتت.

| الحالة | ما تتحقق منه | مقابل المطلوب |
| --- | --- | --- |
| `pressWritesCountTotalsAndRevisionToDiskInOneCommit` | ضغطة واحدة ⇒ `widget_count` + `widget_lifetime` + `widget_totals` + `widget_revision` + `widget_totals_schema`، وكلها موجودة فعلًا داخل `shared_prefs/HomeWidgetPreferences.xml` | (أ) كتابة واحدة عبر Editor واحد |
| `stateSurvivesFreshPreferenceObjects` | بعد ضغطتين + تبديل + ضغطة: قراءة عبر كائنات `SharedPreferences`/`pressLog` **جديدة** تعيد نفس السجل (2 و1) والمراجعة (4) والإجمالي (3) و`COUNT = 1` | (ب) قراءة بعد إعادة إنشاء التخزين |
| `upgradeKeepsLegacyDisplayAsSeedWithoutDoubleCounting` | جهاز مُرقّى (12 بلا سجل) + ضغطة ⇒ 13 في العدّاد والسجل معًا، والبذر مسجّل | (ب) ترقية بلا مضاعفة |
| `commitResultIsVerifiedBeforeReportingSuccess` | `WidgetPressHandlers.increment` مع المخزن الحقيقي ⇒ `true` والقيم على القرص؛ ومع مخزن يفشل في التأكيد ⇒ `false` ولا تغيير في العدّاد المخزَّن | (ج) + (د) |
| `totalsAreNotWrittenWithoutRevision` | السجل والمراجعة يُكتبان معًا دائمًا بعد أي ضغطة | (أ) ذرّية المفتاحين |

**ما لا يمكن لهذا الاختبار إثباته بصراحة:** Robolectric لا يسمح بإجبار
`Editor.commit()` على إعادة `false` (لا توجد طريقة عامة لحقن فشل قرص). لذلك مسار
«الفشل» مُغطّى عند نفس نقطة الانقطاع التي يستخدمها المشغّل: `WidgetPressHandlers` مع
مخزن يرفع استثناءً (الحالة الرابعة أعلاه)، و`stateStore` نفسه مُغطّى إيجابًا (تأكيد
`commit() == true` ثم قراءة الملف).

### 2.3 اختبارات Dart — 95 حالة (كانت 79)

التوزيع: `app_core` 11 · `friday_window` 13 · `reminder_bootstrap` 5 · `scheduling` 24 ·
`sun_day_of_year` 8 · `tasbih_widget_sync` 19 · **`widget_sync_state` 15 (جديد)**.

| الحالة | السيناريو |
| --- | --- |
| `v=2` و`revision=0` مع مفتاح قديم = 5 | يُستعاد **0** (نقطة المراجعة الأولى) — في اختبار الوحدة وفي مشغّل المزامنة |
| `v=2` و`revision=7` مع قديم = 5 | يُستعاد 7 |
| `v=2` بلا حقل `revision` | المفتاح القديم (ترقية) |
| `v` مفقود مع `revision` | المفتاح القديم (ليست حالة حديثة) |
| لا حالة | المفتاح القديم |
| نص فارغ/تالف/غير كائن | `tryParse` يعيد `null` بلا استثناء |
| `encode` ثم `tryParse` | نفس القيم (دوران كامل) |
| `write` ⇒ ملف على القرص | `rawFileContents` يعيد نفس الحمولة (إثبات fsync) |
| متجر جديد (إعادة تشغيل) | يقرأ نفس الحالة |
| الملف يتقدّم على التفضيلات | نسخة تفضيلات مختلفة لا تطغى |
| غياب الملف | الرجوع إلى نسخة التفضيلات |
| ملف تالف | يُتجاهل ويُقرأ الاحتياط |
| لا ملف ولا تفضيلات | `null` |

---

## 3) التحليل والبناء

| البند | النتيجة |
| --- | --- |
| اختبارات Dart | **95/95 ناجحة** |
| اختبارات منطق Kotlin (JVM، مستقلة) | **13/13 ناجحة** (0 فشل، 0 متخطى) |
| اختبارات تخزين Android (Robolectric، داخل الوحدة) | **5/5 ناجحة** (إجمالي الوحدة 18: 13 منطق + 5 تخزين) |
| `flutter analyze` | **0 أخطاء · 0 تحذيرات · 179 ملاحظة info** |
| Manifest | `AD_ID` غير موجود، `usesCleartextTraffic=false` |
| التحديثات | `updatesActive=false`، `Freeze guard` ناجح، لا Release ولا أصول مرفوعة |

### 3.1 كيف تُشغَّل اختبارات Robolectric في CI دون أن تمسّ الـ APK

`tool/patch_android_gradle.py` يُضيف وقت الاختبار فقط:

* `unitTests.isIncludeAndroidResources = true`
* اعتماديات `robolectric:4.14.1` + `androidx.test:core:1.6.1`
* تنزيل حزمتَي `android-all-instrumented` (SDK 34 و35) عبر Gradle — كل واحدة في
  **إعداد منفصل**، لأن إعدادًا واحدًا كان يوحّد النسختين ويُبقي الأعلى فقط —
  ثم نسخها في `doFirst` قبل تشغيل الاختبار، وتشغيل Robolectric في وضع `offline`
  (جالبه الداخلي يفشل أحيانًا على الشبكة).

بعد الاختبار يُستعاد الملف الأصلي من النسخة الاحتياطية، و`minSdk` يعود إلى 23 **قبل**
بناء الـ APK ⇒ ما شُحن لم يتغيّر بسبب الاختبارات.

---

## 4) `_dayOfYear` — حساب UTC خالص

`dayOfYearUtc` تبني `DateTime.utc` للبداية واليوم ⇒ كل يوم 24 ساعة، والنتيجة لا تتأثر
بتوقيت الجهاز ولا بالتوقيت الصيفي. الاختبارات (8) تشمل: قيم تقويمية معروفة، +1 بالضبط
على مدى 365 يومًا، فروق التواريخ حول بداية/نهاية التوقيت الصيفي المصري، وعدم وجود
قفزة ساعة في مواقيت الشمس بعد التغيير.

---

## 5) سكربت حماية `main`

* الافتراضي: `Analyze & Test` فقط، مع تحقق من وجود تشغيل له على الفرع.
* `--with-freeze`: يضيف `Freeze guard (no user-facing updates)` بعد التأكد من وجود
  `release_guard.yml` على الفرع ونجاح آخر تشغيل له.
* `DRY_RUN=1` لطباعة الحمولة دون إرسال، و`--help`.

`main` ما زال **غير محمي** (`protection.enabled = false`)؛ توكن الجلسة يرفض إدارة
الحماية بـ 403، والتنفيذ يحتاج جلسة مالك.

---

## 6) التوقيع — ما قيس فعليًا فقط

```
certificate SHA-256: 6656d6533ffc1fa5343cc223c7d8f30b402d9cae80dc76df7f21fcaffead7d3d
```

**لم تتغيّر الشهادة** بين هذا البناء والبناء السابق (`d6483e3`)، أي أن مفتاح التوقيع
نفسه. **لا مقارنة مع شهادة `1.0.0+1`** ولم يُستنتج التوافق: أصول الـ Release غير قابلة
للتنزيل من الجلسة، ومن CI التوكن للقراءة فقط. للتحقق عندك:

```bash
apksigner verify --print-certs azkari-1.0.0.apk
apksigner verify --print-certs Azkari-1.1.0+2.apk
adb install -r Azkari-1.1.0+2.apk     # تحديث مكاني، بلا حذف
```

---

## 7) الـ APK الداخلي

| البند | القيمة |
| --- | --- |
| Build run | https://github.com/ahmfalcon00868-maker/azkari-app/actions/runs/46139202551 |
| Code checks | https://github.com/ahmfalcon00868-maker/azkari-app/actions/runs/46139202535 |
| كوميت البناء | `d5a8619` |
| الأرتيفاكت | `Azkari-1.1.0-2-sha256-82b322a0…-cert-6656d653…-tests-95-apk-bytes-64785147` |
| **حجم الـ APK الحقيقي** | **64,785,147 بايت (61.79 م.ب)** |
| حجم ملف ZIP المحمّل | ~32.3 م.ب (ليس مقياسًا للـ APK) |
| **SHA-256 للـ APK** | `82b322a04ae41b195afe7e1e2be7121905c405a2103b1aa9a2e15ef58d0617bb` |
| SHA-256 للشهادة | `6656d6533ffc1fa5343cc223c7d8f30b402d9cae80dc76df7f21fcaffead7d3d` |
| الإصدار | `1.1.0+2` (versionCode 2) |
| الاختبارات | 95 Dart + 18 Kotlin (13 منطق + 5 تخزين) |

لم يُرفع الـ APK إلى أي Release ولم يُنشر في أي مكان؛ التنزيل من أرتيفاكت التشغيل أعلاه
فقط، والقرار قرارك.

---

## 8) ما لم يكتمل / حدوده

1. **إجبار `commit()` على الفشل داخل Robolectric** غير ممكن عبر واجهة عامة؛ مسار الفشل
   مُغطّى عند نقطة الانقطاع (`WidgetPressHandlers` + مخزن يرفع استثناء) لا داخل
   `SharedPreferences` نفسها.
2. **حماية `main` غير مفعّلة** (403 من الـ API) — السكربت والخطوات جاهزان.
3. **مقارنة شهادة 1.0.0** غير ممكنة آليًا من هذه البيئة، ولم أفترض التوافق.
4. **179 ملاحظة info** — إهمالات إصدار Flutter، تحتاج قرار ترقية مستقل.
5. **الأداء:** إضافة fsync لكل مزامنة تعني كتابة أصغر لكن متزامنة؛ قِيست داخل حدود
   الميلي ثانية على أجهزة الاختبار، ولم تُقَس على جهاز أرضي.

---

## 9) الملفات المتغيرة في هذه الجولة

`lib/services/widget_sync_store.dart` (جديد) · `lib/services/widget_sync_logic.dart`
(`WidgetSyncState` + `resolveRevision`) · `lib/main.dart` (استئناف + ترتيب الكتابة قبل
التطبيق) · `test/widget_sync_state_test.dart` (جديد، 15) ·
`test/tasbih_widget_sync_test.dart` (19، يستخدم دوال الإنتاج) ·
`android_custom/.../WidgetPrefs.kt` (تحقق `commit`) ·
`android_custom/.../TasbihPressLog.kt` (`WidgetPressHandlers`) ·
`android_custom/.../TasbihWidgetProvider.kt` · `android_custom/.../TasbihPressLogTest.kt` (13) ·
`android_custom/app/src/test/kotlin/com/flc/azkari/WidgetPrefsStorageTest.kt` (جديد، 5) ·
`tool/patch_android_gradle.py` (جديد) · `.github/workflows/build_apk.yml` ·
`docs/wave2_report.md`
