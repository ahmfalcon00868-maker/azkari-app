# أذكاري — واذكر ربك إذا نسيت

تطبيق **Flutter** عربي (RTL) للأذكار والقرآن الكريم والسبحة الإلكترونية، يعمل
**بدون إنترنت** وبدون إعلانات. القرآن والتفسير مضمّنان داخل التطبيق (Offline First).

- صفحة التحميل الرسمية: <https://apkpure.com/p/com.flc.azkari>
- المعرّف: `com.flc.azkari` · الإصدار الحالي في الكود: `1.1.0+2`

## الميزات

| الميزة | التفاصيل |
|---|---|
| الأذكار | 85 ذكرًا في 7 تصنيفات (صباح، مساء، نوم، استيقاظ، صلاة، أدعية، يومي) + عداد ذكي ومشاركة كبطاقة أو نص |
| القرآن الكريم | 114 سورة كاملة (رسم عثماني) + تفسير الميسر + بحث عربي يتجاهل التشكيل، مثبتة داخل التطبيق |
| التلاوة | مشغّل صوتي (just_audio) مع تحميل مؤقت وإشعار وسائط |
| الذكر العائم | نافذة فوق التطبيقات الأخرى (`flutter_overlay_window`) |
| السبحة الإلكترونية | عدّاد، أشكال (skins)، إنجازات وتحديات يومية |
| أذكاري PRO | اشتراك اختياري، أكواد برومو، تحقق من تحويلات Bybit، نسخ احتياطي سحابي |
| اللغات | عربي (افتراضي)، إنجليزي، تركي |

## البنية

```
lib/
  main.dart                     # الثيم، الـ shell بالتبويبات، الأذكار، السبحة، الإنجازات
  data/azkar_data.dart          # بيانات الأذكار + الترجمات (بدون أي تبعيات)
  screens/
    quran_screen.dart           # فهرس المصحف، القارئ، التفسير، التلاوة
    sha7nawy_payment_screen.dart# PRO، البرومو كود، Bybit، الولاء
    tools_screen.dart           # أدوات إسلامية
    explore_islamic_screen.dart # استكشاف
  services/
    update_service.dart         # التحديث الذاتي (موقوف حاليًا — انظر docs/update_freeze.md)
    notification_service.dart   # تذكيرات يومية مجدولة
    cloud_sync_service.dart     # مزامنة/نسخ احتياطي (Supabase)
assets/                         # القرآن والتفسير (5.2MB)، صوتيات، خطوط، أيقونات
docs/                           # supabase_setup.md · update_freeze.md
.github/workflows/              # build_apk.yml (APK) · ci_checks.yml (تحليل + اختبارات)
```

## البناء

المشروع **لا يحتوي** على مجلد `android/` أو `ios/`؛ يولدها الـ CI تلقائيًا:

```bash
flutter create --org com.flc --project-name azkari --platforms=android .
flutter pub get
flutter build apk --release --obfuscate --split-debug-info=build/debug-info
```

للعمل محليًا: ثبّت Flutter (stable) ثم نفّذ `flutter create` أعلاه ثم `flutter run`.

### الأسرار المطلوبة في GitHub Actions

`FB_APP_ID`, `FB_CLIENT_TOKEN`, `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`,
`KEY_ALIAS`, `KEY_PASSWORD` (توقيع الإصدار).

## الاختبارات

```bash
flutter analyze --no-fatal-warnings --no-fatal-infos
flutter test
```

تُشغَّل تلقائيًا عبر `ci_checks.yml` على كل فرع. الاختبارات تغطي: سلامة بيانات
الأذكار والترجمات، بناء مسارات المزامنة والنسخ الاحتياطي، وحماية التحديثات.

## ملاحظات مهمة

- **التحديثات مجمّدة حاليًا**: لا يصل أي تحديث للمستخدمين. التفاصيل وخطوات رفع
  التجميد في [docs/update_freeze.md](docs/update_freeze.md).
- **إعداد Supabase** (الجداول وسياسات RLS ودالة التحقق) في
  [docs/supabase_setup.md](docs/supabase_setup.md).
- `version.json` ما زال `1.0.0` عن قصد حتى لا يُطلب من أحد التحديث.
