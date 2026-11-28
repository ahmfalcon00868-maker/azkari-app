import 'package:flutter/foundation.dart';

/// سجل داخلي لمراحل الإقلاع.
///
/// الهدف: **لا يُبتلع أي خطأ بصمت**. كل خطأ في مسار البدء يُسجَّل هنا ويُطبع في
/// Logcat، ويُعرض للمستخدم إذا فشلت تهيئة أساسية (مثل التخزين) بدل شاشة بيضاء.
///
/// السجل في الذاكرة فقط ولا يمسّ بيانات المستخدم المحفوظة.
@immutable
class StartupEntry {
  const StartupEntry({required this.label, required this.isError, this.details});

  final String label;
  final bool isError;
  final String? details;

  String toLine() =>
      isError ? '✗ $label${details == null ? '' : ': $details'}' : '✓ $label';

  @override
  String toString() => toLine();
}

class StartupDiagnostics {
  StartupDiagnostics._();

  static final StartupDiagnostics instance = StartupDiagnostics._();

  /// الحد الأقصى للاحتفاظ بالمدخلات (ذاكرة فقط، لا يُكتب على القرص).
  static const int _maxEntries = 60;

  final List<StartupEntry> _entries = <StartupEntry>[];

  List<StartupEntry> get entries => List<StartupEntry>.unmodifiable(_entries);

  bool get hasErrors => _entries.any((entry) => entry.isError);

  void phase(String label) => _add(StartupEntry(label: label, isError: false));

  void error(String label, Object error, [StackTrace? stack]) {
    final String details;
    if (stack == null) {
      details = '$error';
    } else {
      details = '$error\n$stack';
    }
    _add(StartupEntry(label: label, isError: true, details: details));
  }

  void _add(StartupEntry entry) {
    _entries.add(entry);
    if (_entries.length > _maxEntries) {
      _entries.removeAt(0);
    }
    try {
      // يظهر في Logcat تحت وسم flutter، ويسهّل تشخيص أي جهاز بلا أدوات.
      debugPrint('[startup] ${entry.toLine()}');
    } catch (_) {
      // لا نرمي أبدًا من داخل معالج أخطاء.
    }
  }

  String report() => _entries.map((entry) => entry.toLine()).join('\n');
}

/// ينفّذ مهمة **اختيارية** بمهلة صريحة.
///
/// أي فشل أو تعليق يُسجَّل ولا يمنع الواجهة من الظهور. تعيد `true` عند النجاح.
/// تُستخدم لتهيئة الخدمات التي يجوز فشلها: الصوت في الخلفية، الإشعارات،
/// مزامنة الاشتراك… إلخ.
Future<bool> guardedStartup(
  String label,
  Future<void> Function() task, {
  Duration timeout = const Duration(seconds: 8),
}) async {
  try {
    await task().timeout(timeout);
    StartupDiagnostics.instance.phase(label);
    return true;
  } catch (error, stack) {
    StartupDiagnostics.instance.error(label, error, stack);
    return false;
  }
}
