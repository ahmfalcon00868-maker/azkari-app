# CRITICAL: تشخيص عطل بدء التشغيل / الشاشة البيضاء — Azkari 1.1.0+2

> الفرع: `arena/61463075-azkari-app` · نقطة البداية: `d5a8619` · تاريخ التشخيص: 2026-11-28
> **حالة المرحلة 1: جارية.** هذه الورقة تسجّل ما أُثبت من الكود، وما يحتاج سجل جهاز
> (Logcat) قبل أي إصلاح بنيوي. لم يُغيَّر أي كود تشغيلي في هذه المرحلة.

---

## 0) الخلاصة في سطرين

1. لا أستطيع الآن تقديم «الاستثناء الأول» لأنه **لا يوجد أي جهاز ولا محاكٍ يعمل في
   بيئة العمل الحالية**، والأهم: الأخطاء نفسها **مبتلعة في الكود**، فالشاشة البيضاء
   لا تترك أثرًا في Logcat أصلًا.
2. ست نقاط مثبتة بالكود أدناه تجعل العطل **غير قابل للتشخيص**، وواحدة منها قادرة
   وحدها على إنتاج شاشة بيضاء دائمة بلا أي رسالة: انتظار `main()` لـ
   `SharedPreferences.getInstance()` **قبل** `runApp` وبدون `try/catch`.

---

## 1) ما أُثبت بالكود (مع الموضع الدقيق)

### 1.1 ابتلاع كل الأخطاء غير المعالجة — `lib/main.dart:561-563`

```dart
ui.PlatformDispatcher.instance.onError = (error, stack) {
  return true;   // ← يُعلن الخطأ «معالجًا» ولا يسجّل شيئًا
};
```

* `return true` يعني للمحرك: «تمّت المعالجة»، فلا يُطبع الخطأ ولا يُرفع.
* لا يوجد في المشروع كله أي `runZonedGuarded` (بحث في `lib/`: **صفر نتائج**).
* النتيجة: أي فشل داخل نداءات `initState` غير المنتظرة (السطور 806-810:
  `_pullTasbihFromWidget`، `syncAyahWidget`، `_syncReminders`،
  `_syncFloatingTimer`، `_playStartupAyahAudio`) يختفي تمامًا. أي `MissingPluginException`
  أو `PlatformException` أو `LateInitializationError` يموت بلا أثر.
* `FlutterError.onError` (558-560) يستدعي `presentError` فقط، بلا تسجيل إلى ملف ولا
  إلى قناة يمكن قراءتها لاحقًا.

**الأثر العملي:** «الشاشة البيضاء» عندنا ليست عطلًا واحدًا؛ هي **غياب دليل**. لا يمكن
لأحد — ولا لي — أن يعرف السبب من الجهاز لأن التطبيق لا يكتبه.

### 1.2 `main()` ينتظر عمليتين حسّاستين قبل `runApp` بدون حماية — `lib/main.dart:574-578`

```dart
await SystemChrome.setPreferredOrientations([...]);   // 574-577  بلا try/catch
final prefs = await SharedPreferences.getInstance();  // 578      بلا try/catch
runApp(AzkariApp(prefs: prefs));                      // 582
```

* باقي الخدمات ملفوفة فعلًا: `JustAudioBackground.init` (564-573) و
  `NotificationService.init` (579-581) داخل `try/catch` ⇒ فشلها **لا يمنع** الفتح.
* لكن العمليتين **الضروريتين** هما الوحيدتان بلا حماية. أي استثناء فيهما ⇒ لا
  `runApp` أبدًا ⇒ تبقى شاشة النظام (بيضاء/داكنة) بلا أي واجهة Flutter، وبلا أي
  سجل من كودنا.
* هذا بالضبط شكل العَرَض الموصوف: «أضغط الأيقونة، لا يظهر محتوى، لا شاشة بيضاء
  متحركة، لا خروج».

### 1.3 الواجهة كلها خلف سباش 3 ثوانٍ — `lib/main.dart:1499` و`1536`

`home: SplashWrapperScreen(appState: this)` ثم `Timer(Duration(seconds: 3))` للانتقال
إلى الهيكل الرئيسي. أي عطل في `SplashWrapperScreen` أو في بناء الهيكل بعدها يظهر
كـ«شاشة بيضاء صامتة»، لأن `ErrorWidget` في نسخة **release** يرسم سطحًا فارغًا بلا
نص (لا شريط أحمر كما في debug). هذا يفسّر لماذا يبدو العطل «تصميميًا» وهو ليس كذلك.

### 1.4 النشاط المشغِّل ليس `MainActivity` ⇒ قناة الصوت ميتة ومخفية — `.github/workflows/build_apk.yml:99`

```python
m = m.replace('android:name=".MainActivity"',
              'android:name="com.ryanheise.audioservice.AudioServiceActivity"', 1)
```

* `MainActivity` هي التي تسجّل قناة `com.flc.azkari/volume`
  (`android_custom/app/src/main/kotlin/com/flc/azkari/MainActivity.kt:15-33`)، وبما
  أنها لم تعد النشاط المشغِّل، فإن `configureFlutterEngine` الخاص بها **لا يُنفَّذ
  أبدًا** في النسخة المشحونة.
* و`VolumeButtonService.setCapture` (السطور 41-50) تبتلع الفشل بصمت ⇒ ميزة أزرار
  الصوت معطّلة في النسخة المشحونة، ولا أحد يعلم. هذا **دليل ثانٍ مستقل** على أن
  أعطال القنوات تُبتلع بدل أن تُسجَّل.

### 1.5 `minSdk` مخالف للمطلوب، و`targetSdk` غير مثبّت — `.github/workflows/build_apk.yml:139`

```python
g = re.sub(r"minSdk\s*=\s*flutter\.minSdkVersion", "minSdk = 23", g)
```

* المطلوب في هذه المهمة: **API 24 حدًّا أدنى**. المشحون الآن 23.
* `compileSdk`/`targetSdk` **لا يُثبَّتان** في المستودع؛ يتبعان افتراضي Flutter في
  وقت البناء. أي تغيير في إصدار Flutter يتغيّر معه سلوك Android 16 (API 36) بلا
  أثر في المستودع — وهذا يخالف شرط «مراجعة إعدادات Android الناتجة فعليًا».
* ملاحظة مهمة: سكربت التشخيص في CI كان يرفعها مؤقتًا إلى 24 لتشغيل اختبارات
  Robolectric ثم يُعيدها 23 (السطر 190) ⇒ ما شُحن ما زال 23.

### 1.6 كل تهيئة الإقلاع في مُنشئ واحد بلا فصل «ضروري/اختياري» — `lib/main.dart:779-810`

`initState` تشغّل 11 عملية متتابعة في نفس الدالة، منها ما يلمس الشبكة
(`AzkariProManager.syncServerSubscription`, 792) والودجت والإشعارات، بمزيج من
`await` و«أطلق وانسَ». لا يوجد أي حدّ يفصل ما يجب أن ينجح لفتح التطبيق عمّا يجوز
أن يفشل — وهذا أصل المشكلة البنيوية التي طلبت إصلاحها في المرحلة 2.

---

## 2) ما لم أستطع إثباته بعد — وبصراحة

**لا أقدّم سببًا نهائيًا بدون سجل.** إليك القيود الفعلية:

1. **لا جهاز فعلي ولا محاكٍ متاح في بيئتي.** حاولت تشغيل نسخة Release على محاكيات
   داخل CI: أضفت مهمة اختيارية `startup-diagnosis` في نفس الـ workflow تثبّت
   **نفس** الـ APK المشحون وتفتحه ثلاث مرات (أول تشغيل، إعادة تشغيل بعد
   `force-stop`، وتشغيل بلا إنترنت) وتلتقط `logcat` + صورة شاشة لكل إصدار.
2. المحاكي في هذه الرانرات **لا يصل إلى `sys.boot_completed`** خلال 12.5 دقيقة.
   الدليل من التشغيل `46148284131` (تعليق CI حرفيًا):
   `failure: emulator api=24 did not boot`. أي أن المشكلة الآن في **البنية التحتية
   للمحاكي**، لا في التطبيق.
3. تنزيل أرتيفاكت الـ APK من هذه البيئة محجوب (النطاق المسموح لا يشمل تخزين
   الأرتيفاكت)، فلا أستطيع فحص موارد الـ APK المشحون محليًا.

بالتالي: **الخطوة الحاسمة هي سجل من جهاز واحد** (جهازك أو أي جهاز يعيد إنتاج
العَرَض). الأوامر جاهزة في القسم 4.

---

## 3) الفرضيات المرتبة (كل واحدة مع بصمتها في Logcat)

| # | الفرضية | لماذا مرجّحة | البصمة المتوقعة في Logcat |
| --- | --- | --- | --- |
| H1 | فشل `SharedPreferences.getInstance()` أو `setPreferredOrientations` قبل `runApp` | الموضعان الوحيدان بلا حماية في مسار الإقلاع (1.2) | `E/flutter: Unhandled Exception` **بعد** سطر `flutter: ...` وقبل أي `Displayed com.flc.azkari`؛ أو لا شيء إطلاقًا |
| H2 | فشل بناء الهيكل الرئيسي بعد السباش (مثلاً `LateInitializationError` أو `PlatformException` من مشغّل صوت أُنشئ وقت البناء) | الواجهة لا تظهر بعد 3 ثوانٍ فقط، والشاشة تبقى فارغة بلا نص في release (1.3) | `E/flutter` أو `FlutterError` بعد `Displayed com.flc.azkari/...` بثلاث ثوانٍ |
| H3 | انهيار أصلي (Java/Kotlin) قبل تشغيل Dart — مثلاً تهيئة Facebook SDK عند غياب `facebook_app_id` أو مورد ناقص | المعرّف يُحقن من `secrets.FB_APP_ID` بلا تحقق من أنه غير فارغ (السطر 236-238)؛ والـ SDK يهيّئ نفسه عبر Provider عند بدء العملية | `FATAL EXCEPTION` + `java.lang.RuntimeException/FacebookException` + `beginning of crash` |
| H4 | `NoClassDefFoundError`/`ClassNotFoundException` في نسخة release بسبب R8 لعنصر مُعلن في المانيفست | يظهر فقط في release+obfuscate (وهي النسخة التي تجربها) | `FATAL EXCEPTION ... ClassNotFoundException: com.ryanheise...` أو `flutter.overlay...` |
| H5 | سلوك خاص بـ Android 16 (API 36) مثل قيود `foregroundServiceType` أو رفض صلاحية التنبيهات الدقيقة | الجهاز قد يكون حديثًا، و`targetSdk` غير مثبّت (1.5) | `SecurityException`/`ForegroundServiceStartNotAllowedException` |
| H6 | فشل خدمة اختيارية يمنع الإقلاع لأنها تُنتظر | `initState` تنتظر الشبكة (792) قبل `setState` رغم أن الواجهة لا تعتمد عليها | `SocketException`/`TimeoutException` ثم توقف الظهور |

**ترتيبي:** H1 ثم H2 ثم H3. كلها تُختبر بسجل واحد.

---

## 4) كيف نحصل على السجل (دقيقتان على جهازك)

```bash
# 1) نظّف السجل ثم افتح التطبيق يدويًا من الأيقونة
adb logcat -c
# (افتح التطبيق وانتظر 20 ثانية)
adb logcat -d -v threadtime > azkari-launch.txt

# 2) أهم السطور فقط
grep -E "FATAL|AndroidRuntime|E/flutter|Unhandled Exception|MissingPluginException|\
PlatformException|LateInitializationError|NoSuchMethodError|ClassNotFound|\
NoClassDefFound|beginning of crash|FacebookException" azkari-launch.txt

# 3) هل وصلت الواجهة إلى النظام؟
adb shell dumpsys activity activities | grep -E "topResumedActivity|ResumedActivity"
adb shell pidof com.flc.azkari
```

المطلوب لصق مخرجات (2) و(3)، مع: **إصدار Android، نوع الجهاز، وهل العَرَض شاشة
بيضاء دائمة أم خروج فوري أم تعليق على السباش**.

---

## 5) خطة المرحلة 2 (جاهزة للتنفيذ، ولا تلمس بيانات المستخدم)

1. **بديل `main()` آمن:** لفّ الإقلاع في `runZonedGuarded` + `FlutterError.onError`
   يسجّل **إلى Logcat وملف** `startup_error.log`، وإزالة `onError => true`.
2. **فصل ضروري/اختياري:** `bootstrapEssential()` (prefs + إعدادات العرض فقط) ثم
   `bootstrapOptional()` (صوت، إشعارات، ودجت، مزامنة سحابية، Facebook) في الخلفية
   بلا `await` على المسار الحرج، وكل واحدة تفشل وحدها بلا أثر على الفتح.
3. **`StartupGate`:** إن فشل الضروري ⇒ شاشة خطأ عربية مفهومة + زر «إعادة المحاولة»
   (لا شاشة بيضاء، لا خروج). وإن نجح ⇒ التطبيق يعمل **Offline-First** بلا أي شرط
   شبكة.
4. **إصلاح قناة أزرار الصوت:** نقل تسجيل القناة إلى النشاط الفعلي
   (`AudioServiceActivity` عبر `MainActivity` كـ subclass) أو إزالة الميزة صراحة —
   لا نتركها صامتة.
5. **Android:** `minSdk = 24` (بعد التحقق من كل مكتبة)، وتثبيت
   `compileSdk`/`targetSdk` صراحةً، ومراجعة `foregroundServiceType` والصلاحيات.
6. **الاختبارات:** اختبارات Dart لمسار الإقلاع (بوابة الخطأ/إعادة المحاولة/عدم
   ابتلاع الاستثناء) + مصفوفة المحاكيات API 24..36، مع تمييز صريح بين
   Emulator والجهاز الفعلي.

---

## 6) أسئلة تمنع التخمين

1. على جهازك: هل العَرَض **شاشة بيضاء دائمة**، أم **خروج فوري**، أم توقف على شعار
   البداية؟ وما إصدار Android ونوع الجهاز؟
2. هل يمكنك لصق مخرجات القسم 4؟ (أسرع طريق لإثبات السبب)
3. هل أبدأ تنفيذ المرحلة 2 الآن (تسجيل الأخطاء + فصل التهيئة + شاشة الخطأ/إعادة
   المحاولة) قبل اكتمال السجل، أم أنتظر السجل أولًا؟

---

## 7) ما لم يتغيّر

* لا دمج في `main`، لا Release، لا نشر، `kUpdatesEnabled = false` كما هو.
* لا حذف بيانات، ولا إعادة ضبط، ولا تغيير في إصلاحات المزامنة/التخزين السابقة
  (`d5a8619` كما هو).
* الـ APK الحالي لم يُبنَ مرة أخرى في هذه المرحلة؛ آخر أرتيفاكت موثّق هو
  `82b322a0…` (64,785,147 بايت) من التشغيل `46139202551`.
