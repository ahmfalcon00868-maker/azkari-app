# تقرير الموجة الثانية — Azkari 1.1.0+2

> الفرع: `arena/61463075-azkari-app` · آخر commit: `a634bc1`
> **لم يُدمج شيء إلى `main`، ولم يُنشأ Release، ولم يُنشر APK، والتحديثات ما زالت معطّلة.**
> الاختبار النهائي هو أرتيفاكت Actions فقط، والقرار لك وحدك.

---

## 1) فقدان عدّاد التسبيح عند التبديل من الودجت (12 + 3 = 15)

**السبب الجذري:** كان الدمج يستخدم `max(appCount, widget.count)`، وعند تبديل الذكر يستعيد الودجت عدّاده من 0 فيبدو «أقل» من قيمة التطبيق، فتُحسب 12 بدل 15 أو تُهمَل نقرات الودجت.

**الإصلاح:** `lib/services/widget_sync_logic.dart` صار يدمج **فرق النقرات** لا القيمة المطلقة:

- الودجت يحمل `zikr` + `count` + `lifetime` (مجموع النقرات مدى الحياة) + `revision`.
- التطبيق يتذكّر ما رآه آخر مرة (`widget_revision_seen`, `widget_pushed_zikr`, `widget_pushed_count`).
- عند التبديل: العدّاد المعروض للذكر B يبدأ من صفر، لكن `lifetime` يستمر، فالفرق `lifetime_now - lastPushedCount` هو بالضبط عدد نقرات الودجت بعد فتح التطبيق ⇒ **12 + 3 = 15**.
- إعادة المزامنة مرتين بنفس `revision` لا تُضيف شيئًا (idempotent)، وعدّادات بقية الأذكار محفوظة، والإجمالي العام (total tasbih) يتحدث بنفس الفرق.
- الخطة الناتجة غير قابلة للتعديل: `TasbihSyncPlan` (immutable).

**الملفات:** `lib/services/widget_sync_logic.dart`, `lib/services/widget_service.dart`, `lib/main.dart`, `android_custom/.../TasbihWidgetProvider.kt`, `android_custom/.../WidgetPrefs.kt`

**الاختبارات:** `test/tasbih_widget_sync_test.dart` — 9 حالات: 12+3=15، التكرار لا يضاعف، التبديل بين عدة أذكار، تحديث الإجمالي، بقاء عدّادات الأذكار الأخرى، حالة الودجت الأقدم/الأحدث من التطبيق.

---

## 2) مواقيت ذكر الجمعة

| المطلوب | ما تم |
|---|---|
| ربط المواقيت بتوقيت **المدينة** لا توقيت الجهاز | `lib/services/city_clock.dart` (مبني على `package:timezone` + IANA tz). كل مدينة في `kQiblaCities` صار لها `timeZone`. كل الحسابات صارت UTC ثم تُعرض بتوقيت المدينة. |
| تحديث تلقائي للكارت عند فتح/إغلاق النافذة والشاشة مفتوحة | `MoreHubScreen` صار فيه `Timer` على الحدود (بداية/نهاية) + فحص كل دقيقة كشبكة أمان، ويُعاد البناء عند تغيّر بصمة الحالة (يوم الجمعة؟ + النافذة مفتوحة؟) — فالكارت يظهر ويختفي ويغيّر نصه دون إعادة فتح الشاشة. |
| إضافة **المنيا** | أُضيفت `المنيا، مصر` (28.1099, 30.7503, `Africa/Cairo`) وجاءت في المركز الثاني في القائمة، والقائمة كلها 15 مدينة بتوقيتاتها. |

**إضافات:** `lib/services/sun_times.dart` صار له جوهر UTC (`computeSunTimesUtc`, `fridaySunnahWindowUtc`) والدوال المحلية تفوّض إليه؛ ونافذة الجمعة = من مغرب الخميس إلى مغرب الجمعة (NOAA، بدون إنترنت).

**الاختبارات:** `test/friday_window_test.dart` — 13 حالة في 4 مجموعات: مدن بتوقيتات مختلفة (القاهرة صيفًا/شتاءً، الرياض، الدار البيضاء، لندن)، صحة بداية/نهاية النافذة ومدتها (~24 ساعة)، تسمية المدينة، وتطابق حساب UTC مع الحساب المحلي.

---

## 3) نقل ترحيل التذكيرات القديمة إلى بدء التشغيل

- خدمة جديدة `lib/services/reminder_bootstrap.dart` تُستدعى من `main.dart` داخل `_syncReminders()` وقت الإقلاع (قبل أي شاشة).
- تلغي المعرّفات القديمة `201/202` ثم تُعيد الجدولة **فقط** إذا كان التفضيل `sunna_fast_reminder` مفعّلًا ⇒ مفعّل = الاثنين/الخميس، معطّل = لا شيء.
- مفتاح إصدار الترحيل `sunna_reminders_migration = 2` يمنع التكرار عبر عمليات التشغيل المتعددة (لا تذكيرات مزدوجة).
- أُزيلت الجدولة من `initState` في شاشة متابعة القضاء (كانت تُنشئ تذكيرات كل مرة تُفتح الشاشة)، وصُحّح النص القديم الذي كان يتكلم عن «تذكير يومي» إلى النص الصحيح: أسبوعي (الاثنين/الخميس) + أن الإمساك تقريبي.

**الملفات:** `lib/services/reminder_bootstrap.dart` (جديد), `lib/main.dart`, `lib/screens/more_screen.dart`
**الاختبارات:** `test/reminder_bootstrap_test.dart` — 5 حالات: مفعّل يُجدول، معطّل يلغي فقط، لا تكرار عبر تشغيلين، إلغاء المعرّفات القديمة، الإصدار القديم يُرحّل مرة واحدة.

---

## 4) حماية `main` — **غير مفعّلة، ولم أفعّلها**

الحقيقة كما هي:

- `GET /repos/.../branches/main` ⇒ `protection.enabled = false` (لا توجد حماية).
- محاولة قراءة/تعديل rulesets من داخل الجلسة ⇒ `403 Resource not accessible by integration`.
- أسماء الفحوص الحقيقية على `main` (مقروءة من `check-runs`): **`Analyze & Test`** و**`Build Azkari v1.1.0+2 APK`** (كان اسمها القديم يشير إلى 1.0.0)، وأُضيف حرس التجميد باسم **`Freeze guard (no user-facing updates)`**.

لم أستطع تفعيلها لأن التوكن المتاح لا يملك صلاحية إدارة الحماية، **ولن أدّعي أنها مفعّلة**. الجهوزية كاملة من ناحيتي:

```bash
# يتطلب توكن مالك (repo admin) — الملف جاهز بالفحوص الصحيحة
OWNER_TOKEN=... ./tool/setup_main_protection.sh
```

أو من الواجهة: `Settings → Rules` (أو Branches) → New branch ruleset → استهدف `main` → فعّل:
1. `Require a pull request before merging` مع `Require approvals = 1`.
2. `Require status checks to pass before merging` → أضف: `Analyze & Test`, `Freeze guard (no user-facing updates)`.
3. `Block force pushes` و`Restrict deletions`.

التفاصيل الكاملة في `docs/main_protection.md`.

---

## 5) توقيع الـ APK الجديد مقابل نسخة 1.0.0 المثبّتة — **لم أستطع التحقق من القديم، وهذا مصرّح به**

**ما تحقّقت منه فعليًا (هذا البناء):**

```
apksigner verify --print-certs app-release.apk
certificate SHA-256: 6656d6533ffc1fa5343cc223c7d8f30b402d9cae80dc76df7f21fcaffead7d3d
```

وهو **نفس بصمة الشهادة** في بناء الموجة الأولى (`46052757744`). أي أن مفاتيح البناء الحالية ثابتة ومتسقة.

**ما لم أستطع التحقق منه:** شهادة نسخة `1.0.0+1` نفسها. الأسباب التقنية (مثبتة):
- تنزيل أصول الـ Release من الـ sandbox محجوب (`release-assets.githubusercontent.com` غير مسموح).
- من داخل CI: التوكن للقراءة فقط، و`gh api /releases` أعاد `[]` (المسودة غير مرئية له) ⇒ `release not found`، وapksigner لم يجد ملفًا ليفحصه.

**لذلك لا أستنتج التوافق.** الأدلة غير المباشرة (ليست إثباتًا):
- خطوة التوقيع في `build_apk.yml` لم تتغير إطلاقًا منذ الـ commit `de5fd51` (نفس `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_PASSWORD`, `KEY_ALIAS`, ونفس `android/key.properties`).
- شهادة الموجة الأولى والثانية متطابقتان.

**كيف تتحقق أنت في دقيقة (بدون حذف أي شيء):**

```bash
# 1) بصمة المثبّت حاليًا (أي جهاز/محاكي عليه 1.0.0)
adb shell pm dump com.flc.azkari | grep -A2 "signatures"   # أو:
apksigner verify --print-certs /path/to/azkari-1.0.0.apk
# 2) بصمة الجديد
apksigner verify --print-certs Azkari-1.1.0-2.apk
# 3) التثبيت فوق القديم (يحافظ على البيانات)
adb install -r Azkari-1.1.0-2.apk
```

إن تطابقت البصمتان (`6656d653…`) فالتحديث مكاني آمن. وإن اختلفت، سيرفض أندرويد التثبيت بنفسه — **لا تحذف التطبيق ولا بياناته**؛ أبلغني وأنا أعالج الأمر (مثلًا إعادة البناء بالمفتاح الصحيح).

---

## 6) المراجعة النهائية

### الاختبارات — 62/62 ناجحة (كانت 35 في الموجة الأولى)

| الملف | العدد |
|---|---|
| `test/app_core_test.dart` | 11 |
| `test/friday_window_test.dart` | 13 |
| `test/reminder_bootstrap_test.dart` | 5 |
| `test/scheduling_test.dart` | 24 |
| `test/tasbih_widget_sync_test.dart` | 9 |
| **الإجمالي** | **62** |

`flutter test` ⇒ `All tests passed` (العدد 62 ظاهر في اسم أرتيفاكت البناء).

### `flutter analyze` — مفصول بدقة

```
errors   = 0
warnings = 0   (كانت 8، أُصلحت كلها: كود ميت، استيراد غير مستخدم، ?. زائد)
infos    = 179 (كلها إهمالات إصدار: withOpacity، وواجهات Flutter 3.47 المهجورة)
```

التحليل **خالٍ من الأخطاء والتحذيرات**، لكنه ليس «نظيفًا تمامًا» بسبب 179 ملاحظة إهمال قائمة مسبقًا (لا تمنع البناء).

### الـ Manifest والصلاحيات

- `AD_ID`: غير مصرّح به في manifest التطبيق، وفحص البناء `Verify shipped APK manifest (no cleartext HTTP, no AD_ID)` ناجح على الـ APK المُجمَّع (يقرأ manifest المدمج لا المصدر).
- مصدره الأصلي (موثّق من الموجة الأولى): `com.facebook.android:facebook-core:18.1.3` عبر `flutter_facebook_auth`.
- `usesCleartextTraffic=false`، ولا صلاحيات إعلانية زائدة في المصدر.

### التحديثات

- `kUpdatesEnabled = false` و`kUpdatesBuildFlag = false` ⇒ `updatesActive == false`.
- `tool/release_guard.py` يمر في CI، و`Release guard` ليس جزءًا من `main` (لا يحجب الدمج)، واسم الفحص `Freeze guard (no user-facing updates)`.
- لا Release جديد، ولا رفع للأصول، ووسم `v1.0.0` كما هو.

### اسم الـ Workflow

`Build Azkari v1.1.0+2 APK` (كان `v1.0.0`) — تعديل تنظيمي فقط، لا يغيّر سلوك البناء.

---

## 7) الـ APK للاختبار الداخلي

| البند | القيمة |
|---|---|
| التشغيل | https://github.com/ahmfalcon00868-maker/azkari-app/actions/runs/46064581991 |
| الأرتيفاكت | `Azkari-1.1.0-2-sha256-93f0b866…-cert-6656d653…-tests-62` |
| SHA-256 للـ APK | `93f0b86628f986bae314811bd8fb085bef2b93b50b7fc7c4bd44ff3d72f53762` |
| SHA-256 للشهادة | `6656d6533ffc1fa5343cc223c7d8f30b402d9cae80dc76df7f21fcaffead7d3d` |
| الإصدار | `1.1.0+2` (versionCode 2) |
| الحجم | 32,272,012 بايت (~30.8 م.ب) |
| الاختبارات | 62/62 |

التحميل: Actions → التشغيل أعلاه → Artifacts → الأرتيفاكت أعلاه.

---

## 8) ما لم يكتمل (بصراحة)

1. **حماية `main` غير مفعّلة** — صلاحية API مرفوضة (403)؛ أُعدّت السكربتات والخطوات وتحقّقت من أسماء الفحوص الحقيقية. التنفيذ يحتاج جلسة مالك.
2. **مقارنة شهادة 1.0.0** — الأرتيفاكت القديم غير قابل للوصول من الجلسة ولا من CI (مسودة + صلاحية قراءة فقط). بصمة البناء الحالي موثّقة أعلاه، وطريقة التحقق البديلة موضّحة، ولم أفترض التوافق.
3. **179 ملاحظة `info`** في التحليل — إهمالات إصدار Flutter 3.47 (`withOpacity`, `material_ui`)، لم ألمسها لأنها تحتاج قرار ترقية لا إصلاحًا سطحيًا.

---

## 9) الملفات المتغيرة في الموجة الثانية

**جديدة:** `lib/services/reminder_bootstrap.dart` · `lib/services/city_clock.dart` · `lib/services/sun_times.dart` · `lib/services/widget_sync_logic.dart` · `lib/services/widget_service.dart` · `lib/services/reminder_schedule.dart` · `lib/services/sunna_reminders.dart` · `lib/services/volume_button_service.dart` · `lib/screens/more_screen.dart` · `lib/widgets/tasbih_skins.dart` · `test/tasbih_widget_sync_test.dart` · `test/friday_window_test.dart` · `test/reminder_bootstrap_test.dart` · `test/scheduling_test.dart` · `test/app_core_test.dart` · `tool/analyze_summary.py` · `tool/test_stats.py` · `tool/release_guard.py` · `tool/setup_main_protection.sh` · `.github/workflows/ci_checks.yml` · `.github/workflows/release_guard.yml` · `docs/main_protection.md` · `docs/update_freeze.md` · `docs/supabase_setup.md`

**معدّلة:** `lib/main.dart` · `lib/screens/tools_screen.dart` · `lib/screens/quran_screen.dart` · `lib/screens/explore_islamic_screen.dart` · `lib/screens/sha7nawy_payment_screen.dart` · `lib/services/notification_service.dart` · `lib/services/cloud_sync_service.dart` · `lib/services/update_service.dart` · `lib/services/khushu_service.dart` · `pubspec.yaml` · `.github/workflows/build_apk.yml` · `README.md`

**محذوف:** `test/widget_test.dart` (القالب الافتراضي الذي كان يُسقط `flutter test`).
