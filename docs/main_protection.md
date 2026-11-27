# حماية الإصدار المنشور (Freeze) — فرع main

الهدف: **لا يصل أي تحديث للمستخدمين** قبل موافقة صريحة، حتى لو تغيّر كود فرع
التجربة أو `main` نفسه.

## 1) الحماية داخل الكود (مستقلة عن الفرع)

`UpdateService` فيه بوابتان معاً:

```dart
static const bool kUpdatesEnabled = false;                                  // مفتاح الميزة
static const bool kUpdatesBuildFlag = bool.fromEnvironment('AZKARI_ALLOW_UPDATES');
static bool get updatesActive => kUpdatesEnabled && kUpdatesBuildFlag;
```

أي بناء عادي (بما فيه بناء `main` وبناء فروع التجربة) لا يمرّر
`--dart-define=AZKARI_ALLOW_UPDATES=true`، لذلك:

* لا فحص إصدار، لا إشعار، لا تنزيل، لا تثبيت APK.
* لو أُعيد `kUpdatesEnabled = true` في أي فرع، يبقى النظام ميتاً بدون تعريف البناء.

## 2) الحماية داخل خطوط الأنابيب

| المسار | السلوك |
| --- | --- |
| `.github/workflows/build_apk.yml` | `permissions: contents: read` — لا يستطيع نشر Release. يرفع الـ APK كـ **Artifact فقط**. |
| `.github/workflows/release_guard.yml` | يفشل إذا ظهر `kUpdatesEnabled = true` أو أي أمر نشر إصدار أو رفع `version.json` بدون `docs/release_approval.md`. |

## 3) حماية فرع main على GitHub (تحتاج صلاحية Admin)

محاولة الضبط عبر API من بيئة الوكيل ترجع `403 Resource not accessible by integration`
(الصلاحية تخصّ مالك المستودع). لذلك تُضبط يدوياً مرة واحدة:

1. Settings → Rules → Rulesets → **New branch ruleset**.
2. Target: `main`.
3. فعّل: *Restrict deletions*، *Block force pushes*،
   *Require a pull request before merging* (1 approval)،
   *Require status checks*: `Freeze guard (no user-facing updates)` و`Analyze & Test`.
4. (اختياري) *Require review from Code Owners*.

بعد الضبط: أي تعديل على `version.json` أو `update_service.dart` أو خطوط النشر في
`main` يحتاج مراجعة + نجاح حرس التجميد قبل الدمج.

## 4) النشر ليس مجرد merge

حتى لو دُمج كود جديد في `main`، لا يصل شيء للمستخدمين لأن:

* `v1.0.0` Release ما زال **draft** ⇒ `releases/latest` يعيد 404.
* لا يوجد أي workflow ينشئ Release أو يرفع APK لـ APKPure.
* `version.json` على `main` يعلن 1.0.0/build 1 = نفس نسخة المستخدم الحالي ⇒ لا تحديث.

## 5) خطوات فك التجميد (عند الموافقة الصريحة فقط)

1. زيادة `version:` في `pubspec.yaml`.
2. ضبط `kUpdatesEnabled = true` **و** بناء APK بـ
   `--dart-define=AZKARI_ALLOW_UPDATES=true`.
3. تحديث `version.json` برابط APK مباشر.
4. إنشاء `docs/release_approval.md` يحتوي `approved: true` (يمرّ به حرس التجميد).
5. `gh release create vX.Y.Z ...` من حساب المالك (ليس من CI).
6. رفع الـ APK إلى APKPure.
