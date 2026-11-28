# تقرير عطل بدء التشغيل — السبب الحقيقي والإصلاح والتحقق

> الفرع: `arena/61463075-azkari-app` · أساس الإصلاح: `d5a8619` (إصلاحات المزامنة/التخزين
> محفوظة كما هي) · تاريخ: 2026-11-28
> **لا دمج في `main`، لا Release، لا نشر، والتحديثات معطّلة (`kUpdatesEnabled` / `updatesActive`).**

---

## 1) السبب الحقيقي — مثبت بـ Logcat من نسخة Release موقّعة ومُعتَّمة

شُغّل **نفس** الـ APK المشحون (`--release --obfuscate`, موقّع) على محاكيات Android
والتُقط السجل قبل أي تعديل. أول استثناء فعلي:

```
FATAL EXCEPTION: main
Process: com.flc.azkari, PID: 3264
java.lang.RuntimeException: Unable to get provider androidx.startup.InitializationProvider:
  java.lang.RuntimeException: Failed to create an instance of androidx.work.impl.WorkDatabase
    at w11.x(r8-map-id-39cf639ac095d4c61aa8c11dda847d887bc7d56e6a9591aa8c401d97ec010073:104)
    at w11.u(r8-map-id-39cf639ac095d4c61aa8c11dda847d887bc7d56e6a9591aa8c401d97ec010073:86)
    at androidx.startup.InitializationProvider.onCreate(...)
    at android.content.ContentProvider.attachInfo(ContentProvider.java:1751)
    at android.app.ActivityThread.installProvider(ActivityThread.java:5814)
    at android.app.ActivityThread.handleBindApplication(ActivityThread.java:5342)
    ...
    at android.app.ActivityThread.main(ActivityThread.java:6077)
```

* `w11` = صنف مُعتَّم بواسطة **R8** (لاحظ `r8-map-id-…` في كل إطار).
* الحدث يقع في `handleBindApplication`، أي **قبل** إنشاء النشاط وقبل تشغيل محرك
  Flutter. لذلك: لا واجهة، لا شاشة حمراء، لا رسالة — فقط عملية تموت أو سطح أبيض.
* تكرّر **حرفيًا** على API 24، 30، 33 في الجولة الأولى ⇒ عطل عام في كل الأجهزة
  القديمة والحديثة، لا علاقة له بإصدار Android.

### لماذا فشل إنشاء قاعدة WorkManager؟

`androidx.work:work-runtime:2.7.1` يظهر على `releaseRuntimeClasspath` (تبعية غير
مباشرة). هذا الإصدار يعتمد على `Room` في بناء `WorkDatabase` عبر **بحث انعكاسي عن
الصنف المولَّد بالاسم** (`…WorkDatabase_Impl`)، وR8 في وضع `full mode` (افتراضي في
AGP 9) كان يحذف/يعيد تسمية أصناف Room/WorkManager. الدليل الكمّي من فحص الـ DEX
المشحون قبل الإصلاح وبعده:

| نص في DEX | قبل الإصلاح | بعد الإصلاح |
| --- | --- | --- |
| `androidx.work` | 35 ظهورًا | **356** |
| `androidx.room` | 3 ظهور | **106** |
| `RoomDatabase` | 1 | **9** |
| `WorkDatabase_Impl` | 1 | 2 |

أي أن R8 كان قد أزال أغلب أصناف Room/WorkManager من الـ APK، فسقط إنشاء قاعدة
WorkManager وقت التشغيل. التطبيق نفسه **لا يستخدم WorkManager إطلاقًا** (لا يوجد
`workmanager` في `pubspec.yaml`، ولا أي استدعاء في Dart/Kotlin)، فهذه التهيئة كانت
تُنفَّذ تلقائيًا عبر `androidx.startup` فقط لتفشل.

---

## 2) الإصلاح (تغييران مستقلان، كلاهما في بناء Android)

الملف: `.github/workflows/build_apk.yml` (المكان الذي يُولَّد فيه مشروع Android فعلًا)
+ `tool/screen_health.py` (أداة قياس، ليست جزءًا من التطبيق).

1. **إلغاء التهيئة التلقائية لـ WorkManager** — يُضاف إلى المانيفست المدمج:
   ```xml
   <provider android:name="androidx.startup.InitializationProvider"
             android:authorities="${applicationId}.androidx-startup"
             android:exported="false" tools:node="merge">
       <meta-data android:name="androidx.work.WorkManagerInitializer" tools:node="remove" />
   </provider>
   ```
   مسار الانهيار نفسه يزول. آمن لأن التطبيق لا يستخدم WorkManager.
2. **قواعد R8 صريحة** تُكتب إلى `android/app/proguard-rules.pro` قبل البناء، وتُضاف
   `proguardFiles(...)` إلى `release`:
   ```
   -keep class androidx.work.** { *; }
   -keep class androidx.room.** { *; }
   -keep class * extends androidx.room.RoomDatabase { *; }
   -keepclassmembers class * extends androidx.room.RoomDatabase { <init>(); }
   -keep class * implements androidx.startup.Initializer { *; }
   -keepclassmembers class * implements androidx.startup.Initializer { <init>(); }
   -dontwarn androidx.work.**
   ```
   فلو استخدمت مكتبة أخرى WorkManager لاحقًا فلن يتكرر الانهيار.

لم يُلمس: أي كود Dart، أي بيانات مستخدم، إصلاحات المزامنة/التخزين من `d5a8619`،
`minSdk` (ما زال 23 — تغييره إلى 24 بند في المرحلة 3 مع مراجعة كل مكتبة).

---

## 3) التحقق الفعلي (لا «نجح البناء» فقط)

الطريقة: نفس الـ APK المشحون يُثبَّت على محاكٍ، ويُفتح **ثلاث مرات**: فتح أول،
إعادة فتح بعد `force-stop`, وفتح **بلا إنترنت** (wifi+data مطفأتان). لكل محاولة:
`pidof` (هل العملية حيّة)، `logcat` (هل يوجد FATAL)، `Displayed` (هل رُسم أول إطار)،
`mCurrentFocus` (هل التطبيق في المقدمة)، ونسبة البياض في لقطة الشاشة الخام.

القياس الموضوعي للشاشة (`tool/screen_health.py`): نسبة البكسلات شبه البيضاء + عدد
الألوان التقريبية. شاشة بيضاء = نسبة قريبة من 100% وألوان ≈ 1.

### 3.1 قبل الإصلاح (Run `46154606867`)

| API | العملية بعد الفتح | FATAL | الشاشة |
| --- | --- | --- | --- |
| 24 | ماتت | ✅ `Unable to get provider androidx.startup.InitializationProvider` | `Application Error` |
| 30 | ماتت | ✅ نفس الاستثناء | عاد إلى المشغّل |
| 33 | ماتت | ✅ نفس الاستثناء | عاد إلى المشغّل |

### 3.2 بعد الإصلاح (Run `46161614650`، APK `90baa296…`)

| API إصدار Android | Fatal | العملية حيّة (فتح/إعادة/بلا إنترنت) | `Displayed` | نسبة البياض | الألوان | التطبيق في المقدمة |
| --- | --- | --- | --- | --- | --- | --- |
| 24 · Android 7 | ❌ لا | ✅ 3356 / 4259 / 4405 | 3 | (عدّاد قديم: قياس غير مكتمل) | — | ✅ `AudioServiceActivity` |
| 26 · Android 8 | ❌ لا | ✅ 4351 / 4865 / 5023 | 3 | (عدّاد قديم) | — | ✅ |
| 28 · Android 9 | ❌ لا | ✅ 4836 / 5424 / 5648 | 3 | **0%** | 11–13 | ✅ |
| 29 · Android 10 | ❌ لا | ✅ 4398 / 6487 / 6838 | 3 | **0%** | 14–15 | ✅ |
| 30 · Android 11 | ❌ لا | ✅ 3896 / 5941 / 6261 | 3 | **0%** | 13–15 | ✅ |
| 31 · Android 12 | — | إعادة تشغيل (عطل بنية تحتية للمحاكي، لا للتطبيق) | — | — | — | — |
| 33 · Android 13 | ❌ لا | ✅ 3591 / 5257 / 6212 | 3 | **0%** | 11–14 | ✅ |
| 34 · Android 14 | ❌ لا | ✅ 3258 / 5097 / 5876 | 3 | **0%** | 12–13 | ✅ |
| 35 · Android 15 | ❌ لا | ✅ 2173 / 4138 / 4331 | 3 | **0%** | 13–14 | ✅ |
| 36 · Android 16 | ❌ لا | ✅ 2412 / 4264 / 4749 | 3 | **0%** | 10–12 | ✅ |

* `Displayed = 3` يعني أن النظام سجّل رسم أول إطار **ثلاث مرات** (واحدة لكل فتحة).
* **0% بياض** مع 10–15 مجموعة ألوان ⇒ ليست شاشة بيضاء؛ واجهة حقيقية مرسومة.
* التحذير الوحيد في السجل على 34/35 هو `ClassNotFoundException` من إعدادات النظام
  نفسها (`com.android.settings…`)، وليس من التطبيق.

**التصنيف:** كل النتائج أعلاه **محاكٍ (Emulator)** — لا يوجد جهاز فعلي متصل ببيئة
العمل، ولم أختبر على جهاز حقيقي بعد. مطلوب منك تشغيل الـ APK على جهازك لتأكيد نهائي.

---

## 4) ما تغيّر لنفس الميزانية السابقة

| البند | القيمة |
| --- | --- |
| اختبارات Dart | **95/95 ناجحة** (لم تتغيّر) |
| اختبارات منطق Kotlin (JVM) | 13/13 |
| اختبارات تخزين Android (Robolectric) | 5/5 |
| `flutter analyze` | **0 أخطاء · 0 تحذيرات · 179 info** |
| الإصدار | `1.1.0+2` (versionCode 2) |
| **حجم الـ APK** | **64,883,415 بايت (61.88 م.ب)** |
| **SHA-256 للـ APK** | `90baa296c4cad9184845cf5acae7bf7100853c6892afdf170ec62216289fd2a4` |
| SHA-256 للشهادة | `6656d6533ffc1fa5343cc223c7d8f30b402d9cae80dc76df7f21fcaffead7d3d` (لم تتغيّر) |
| أرتيفاكت | `Azkari-1.1.0-2-sha256-90baa296…-cert-6656d653…-tests-95-apk-bytes-64883415` |
| Build run | https://github.com/ahmfalcon00868-maker/azkari-app/actions/runs/46156883438 |
| Debug symbols | `build/debug-info` (متطلّب `--obfuscate`) — تُرفع مع أرتيفاكت البناء |

---

## 5) أداة التشخيص التي بقيت في المستودع

مهمة اختيارية داخل نفس الـ workflow: `startup-diagnosis` (تُشغَّل فقط عند
`workflow_dispatch` مع `diagnose_emulators=true`، ويمكن توجيهها إلى APK قديم عبر
`apk_run_id`). تفعل: تنزيل الـ APK، فحص DEX، تشغيل محاكٍ لـ API محدد، تثبيت، منح
الأذونات، ثلاث فتحات، التقاط `logcat` + لقطة خام + قياس بياض، ورفع حزمة تشخيص لكل
API. متغيّر المصفوفة في `strategy.matrix.api`.

**كيف تستخرج Logcat بنفسك** (لو تكرّر العطل على جهازك):

```bash
adb logcat -c
# افتح التطبيق وانتظر ~20 ثانية
adb logcat -d -v threadtime > azkari-launch.txt
grep -E "FATAL|AndroidRuntime|E/flutter|Unhandled Exception|MissingPluginException|\
PlatformException|ClassNotFound|NoClassDefFound" azkari-launch.txt
adb shell dumpsys activity activities | grep -E "topResumedActivity|ResumedActivity"
```

---

## 6) ما لم يُنجَز بعد (شفافية)

1. **API 31 (Android 12):** محاولتان فشلتا في **بنية المحاكي** لا في التطبيق؛
   أُعيد تشغيله بجولة منفصلة. لن أدّعي نجاحًا قبل نتيجة نظيفة.
2. **جهاز فعلي:** لم يُختبر. كل ما سبق Emulator.
3. **نسخة Debug:** المختبر هو Release+obfuscate (النسخة التي تسلّمها)؛ لم تُختبر
   Debug في نفس المصفوفة.
4. **اختبار وظيفي أعمق:** المصفوفة الحالية تُثبت الإقلاع/إعادة الإقلاع/العمل بلا
   إنترنت/رسم أول إطار. لم تُختبر بعد: التنقل بين الأقسام، القرآن والصوت، الإشعارات
   فعليًا، الويدجت على جهاز يدعمه، ورفض الصلاحيات — هذه بنود المرحلة 4.
5. **المرحلة 2 (تحصين بنيوي):** لم تُنفَّذ بعد، وهي ضرورية حتى لا يعود العطل صامتًا:
   فصل التهيئة الضرورية عن الاختيارية، `runZonedGuarded` + تسجيل الأخطاء بدل
   `onError = (…) => true`، شاشة خطأ/إعادة محاولة عند فشل التخزين، ونقل طلب إذن
   الإشعارات إلى ما بعد أول إطار (لوحظ على 33+ ظهور نافذة إذن فور الإقلاع).
6. **المرحلة 3 (توافق):** `minSdk` ما زال 23 (المطلوب 24)، و`compileSdk`/`targetSdk`
   غير مثبّتين صراحةً — بند قادم مع مراجعة كل مكتبة.

---

## 7) معيار النجاح كما طلبته

> أضغط أيقونة أذكاري، فيفتح ويظهر محتواه، حتى بدون إنترنت، على Android 7 فما فوق.

الحالة الآن: **يتحقق على 9 إصدارات في المحاكي** (7، 8، 9، 10، 11، 13، 14، 15، 16)
مع ثلاث فتحات لكل إصدار بما فيها بلا إنترنت، وبقي تأكيد Android 12 وجهاز فعلي.
