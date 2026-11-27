# حالة تجميد التحديثات (Update Freeze)

> ⚠️ **الوضع الحالي: التحديثات مجمّدة بالكامل.** لا يصل أي تحديث أو إشعار تحديث
> للمستخدمين مهما حدث، إلى أن يُرفع التجميد يدويًا.

## ما الذي تم عمله

| الطبقة | الإجراء | الأثر |
|---|---|---|
| داخل التطبيق | `UpdateService.kUpdatesEnabled = false` | لا فحص، لا إشعار، لا تنزيل، لا تثبيت APK. أي فحص يدوي يعرض «التحديثات متوقفة مؤقتًا» |
| منطق المقارنة | `UpdateService.isNewerVersion` | لا يُعرض إصدار مساوٍ أو أقدم كتحديث (كان مستخدم 1.1.0 يُطلب منه «التحديث» إلى 1.0.0) |
| `version.json` | لم يُعدّل (1.0.0 / build 1) | لا يدفع أي مستخدم للتحديث |
| GitHub Releases | تحويل `Azkari v1.0.0` إلى **draft** | `GET /releases/latest` يعيد **404** للزوار غير المسجلين ⇒ تطبيق النسخ القديمة (1.0.0 و 1.1.0) لا يجد أي تحديث مطلقًا |
| CI | لا توجد أي خطوة نشر تلقائي للـ Release | البناء يرفع APK كـ Artifact فقط |

### الأثر الجانبي المقصود
روابط التحميل العامة تعمل الآن **404**:
- `…/releases/latest/download/app-release.apk`
- `…/releases/download/v1.0.0/app-release.apk`

ملف الـ APK القديم ما زال موجودًا داخل الـ draft، وتاجات git (`v1.0.0`, `v2.3.0`)
كما هي. للتنزيل المؤقت استخدم Artifact من آخر تشغيل ناجح في تبويب Actions.

## كيف تُنهي التجميد عند جهوزية النسخة

1. **ارفع رقم الإصدار** في `pubspec.yaml` (مثال: `1.2.0+3`) — لا تعِد استخدام رقم
   إصدار قديم، وإلا اعتبرته الأجهزة القديمة «ليس تحديثًا».
2. **فعّل النظام**: `static const bool kUpdatesEnabled = true;` **وأضف**
   `--dart-define=AZKARI_ALLOW_UPDATES=true` إلى أمر البناء (بدونه يبقى النظام
   معطّلاً حتى لو فُتح المفتاح) في
   `lib/services/update_service.dart` (اختبار `app_core_test` سيفشل عن قصد حتى تفعل ذلك).
3. **حدّث `version.json`** في `main`:
   ```json
   { "version": "1.2.0", "build_number": 3, "apk_url": "…/releases/latest/download/app-release.apk", "notes": "…" }
   ```
4. **انشر الـ Release** بالـ APK الجديد. مهم: `apk_url` في `version.json` يجب أن
   يكون **رابط ملف APK مباشر** (التطبيق ينزّل البايتات ويثبّتها عبر `open_filex`)،
   ولا يصلح أن يكون صفحة متجر مثل `https://apkpure.com/p/com.flc.azkari`؛ رابط
   المتجر مخصّص للمشاركة فقط (`kAppDownloadLink` في `lib/main.dart`). مثلًا:
   ```bash
   # الإصدار القديم ما زال draft باسم مؤقت untagged-…؛ أعِد تسميته ونشره
   gh release edit '<untagged-tag>' --tag v1.0.0 --draft=false
   # أو أنشئ إصدارًا جديدًا (الأفضل)
   gh release create v1.2.0 build/app/outputs/flutter-apk/app-release.apk \
     --title "Azkari v1.2.0" --notes-file CHANGELOG.md
   ```
   > `GET /releases/latest` يعيد أحدث Release **غير** draft وغير prerelease.

## ملاحظات
- الـ draft الحالي رقمه `450321210` وتاجه تغيّر عند التحويل إلى
  `untagged-d0c3baf4a1baf355a635`. لإرجاعه كما كان:
  ```bash
  gh api -X PATCH repos/ahmfalcon00868-maker/azkari-app/releases/450321210 \
    -f draft=false -f tag_name=v1.0.0
  ```
- لا تعِد نشر إصدار قديم بينما نسخة أحدث مثبتة عند المستخدمين؛ المقارنة الآن آمنة
  لكن الأفضل نشر نسخة أحدث فقط.
