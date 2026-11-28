import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// تخزين **متين** لحالة مزامنة الويدجت (`counts` + `seen` + `lifetime` + `zikr`
/// + `revision`).
///
/// السبب: `SharedPreferences.setString` لا يضمن أن البيانات صارت على القرص؛ قد
/// تبقى في الذاكرة حتى يقرر النظام كتابتها، فإذا قُتلت العملية قبل ذلك تُفقد
/// «المراجعة المستهلكة» أو العدّادات. لذلك:
///
/// 1. نكتب الملف بأنفسنا مع `flush: true` (fsync فعلي) — هذه هي النسخة الموثوقة.
/// 2. نحتفظ بنسخة في SharedPreferences كاحتياط للقراءة فقط (وللترقية).
/// 3. الكتابة ترجع `true` فقط إذا تأكّد إثبات الملف على القرص (أو نجح الاحتياط
///    عند تعذّر الملف)، وعلى المتصل ألا يعتبر العملية ناجحة قبل ذلك.
class WidgetSyncStore {
  WidgetSyncStore({
    required SharedPreferences prefs,
    this.prefsKey = 'widget_sync_state',
    this.fileName = 'widget_sync_state.json',
    Future<Directory> Function()? directoryProvider,
  })  : _prefs = prefs,
        _directoryProvider = directoryProvider ?? getApplicationDocumentsDirectory;

  final SharedPreferences _prefs;
  final String prefsKey;
  final String fileName;
  final Future<Directory> Function() _directoryProvider;

  Future<File> _file() async {
    final Directory dir = await _directoryProvider();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File('${dir.path}/$fileName');
  }

  /// يكتب الحالة ويعيد `true` فقط عند تأكيد الإثبات على القرص.
  Future<bool> write(String payload) async {
    final bool durable = await _writeFile(payload);
    final bool mirror = await _writePrefs(payload);
    return durable || mirror;
  }

  /// الملف أولًا (المصدر الموثوق)، ثم نسخة التفضيلات (ترقية/احتياط).
  ///
  /// أي محتوى لا يُفكّ كـ JSON يُتجاهل، فلا يوقف ملف تالف استعادة الحالة.
  Future<String?> read() async {
    final String? fromFile = await _readFile();
    if (fromFile != null && isValidPayload(fromFile)) return fromFile;
    try {
      final String? fromPrefs = _prefs.getString(prefsKey);
      if (fromPrefs != null && isValidPayload(fromPrefs)) return fromPrefs;
    } catch (_) {}
    return null;
  }

  Future<bool> _writeFile(String payload) async {
    try {
      final File file = await _file();
      // flush: true = fsync، فلا تعود العملية قبل وصول البيانات للقرص.
      await file.writeAsString(payload, flush: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _writePrefs(String payload) async {
    try {
      await _prefs.setString(prefsKey, payload);
      return _prefs.getString(prefsKey) == payload;
    } catch (_) {
      return false;
    }
  }

  Future<String?> _readFile() async {
    try {
      final File file = await _file();
      if (!await file.exists()) return null;
      return await file.readAsString();
    } catch (_) {
      return null;
    }
  }

  /// للاختبارات: حذف الملف (محاكاة «إعادة تشغيل بلا ملف»).
  Future<void> deleteFileForTests() async {
    try {
      final File file = await _file();
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// للاختبارات: قراءة الملف الخام كما هو على القرص.
  Future<String?> rawFileContents() async {
    try {
      final File file = await _file();
      if (!await file.exists()) return null;
      return await file.readAsString();
    } catch (_) {
      return null;
    }
  }

  /// يتحقق أن النص المخزَّن هو JSON صالح (حماية من ملف تالف).
  static bool isValidPayload(String payload) {
    try {
      final decoded = jsonDecode(payload);
      return decoded is Map;
    } catch (_) {
      return false;
    }
  }
}
