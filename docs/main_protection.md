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

## 3) حماية فرع main على GitHub

### الوضع الفعلي (تحقّق آلي)

```
gh api repos/OWNER/REPO/branches/main -q '.protection.enabled'
# => false            (الحماية غير مفعّلة)
gh api repos/OWNER/REPO/branches/main/protection
# => 403 Resource not accessible by integration
```

أي أن الفرع `main` **غير محمي** حالياً، وتوكن الوكيل لا يملك صلاحية
Administration لتغيير ذلك. لم يتم تفعيل الحماية من قِبَل الوكيل، ولا يُدّعى غير ذلك.

### أسماء فحوصات الحالة الفعلية (تحقّق من الـ API)

| الاسم (context) | مصدره | موجود الآن على main؟ |
| --- | --- | --- |
| `Analyze & Test` | `.github/workflows/ci_checks.yml` | نعم |
| `Freeze guard (no user-facing updates)` | `.github/workflows/release_guard.yml` | **لا** (الملف على فرع التطوير فقط) |
| `Build Azkari v1.1.0+2 APK` | `.github/workflows/build_apk.yml` | لا (يوجد الاسم القديم v1.0.0) |

> تحقّق الأسماء: `gh api repos/OWNER/REPO/commits/main/check-runs -q '.check_runs[].name'`

### خطوات التفعيل (يدوياً — تحتاج مالك المستودع)

1. Settings → Rules → **Rulesets** → *New branch ruleset*.
2. الاسم: `main-freeze`، Target branches: `main`، Enforcement: **Active**.
3. فعّل:
   * Restrict deletions
   * Block force pushes
   * Require a pull request before merging (1 approval، Dismiss stale approvals)
   * Require status checks to pass — أضف **`Analyze & Test`** فقط في البداية.
   * Require conversation resolution
4. **بعد** دمج `release_guard.yml` في `main` (بموافقتك)، أضف الشرط
   `Freeze guard (no user-facing updates)` إلى نفس القواعد.

بديل سطري (بتوكن المالك، صلاحية Administration):

```bash
GH_TOKEN=<owner-token> ./tool/setup_main_protection.sh
```

بعد الضبط: أي تعديل على `version.json` أو `update_service.dart` أو خطوط النشر في
`main` يحتاج مراجعة + نجاح الفحوصات قبل الدمج.

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
