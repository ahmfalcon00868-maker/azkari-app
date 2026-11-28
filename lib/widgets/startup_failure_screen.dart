import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/startup_diagnostics.dart';

/// شاشة تُعرض عندما تفشل التهيئة **الأساسية** (قراءة التخزين المحلي).
///
/// قواعد صارمة:
/// * لا تحذف ولا تُصفّر أي بيانات محفوظة.
/// * لا تدّعي نجاحًا وهميًا: تقول بوضوح إن الإعدادات لم تُقرأ.
/// * تُعطي المستخدم زر إعادة محاولة، وتعرض الخطأ الفعلي ليُرسله للدعم.
class StartupFailureApp extends StatefulWidget {
  const StartupFailureApp({
    super.key,
    required this.lang,
    required this.loadPrefs,
    required this.onReady,
  });

  /// 'ar' أو 'en' أو 'tr' — لغة واجهة الفشل.
  final String lang;

  /// محاولة قراءة التخزين المحلي (تعيد `null` عند الفشل).
  final Future<SharedPreferences?> Function() loadPrefs;

  /// تُنادى بعد نجاح المحاولة: تفتح التطبيق الحقيقي.
  final void Function(SharedPreferences prefs) onReady;

  @override
  State<StartupFailureApp> createState() => _StartupFailureAppState();
}

class _StartupFailureAppState extends State<StartupFailureApp> {
  bool _retrying = false;
  bool _showDetails = false;
  int _failedAttempts = 0;

  bool get _isArabic => widget.lang == 'ar';
  bool get _isTurkish => widget.lang == 'tr';

  String _t(String ar, String en, String tr) {
    if (_isArabic) return ar;
    if (_isTurkish) return tr;
    return en;
  }

  Widget _retryIcon() {
    if (_retrying) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      );
    }
    return const Icon(Icons.refresh);
  }

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() {
      _retrying = true;
      _failedAttempts = 0;
    });
    final prefs = await widget.loadPrefs();
    if (!mounted) return;
    if (prefs != null) {
      widget.onReady(prefs);
      return;
    }
    setState(() {
      _retrying = false;
      _failedAttempts = _failedAttempts + 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color accent = Color(0xFF0288D1);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      home: Directionality(
        textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          backgroundColor: const Color(0xFF000000),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    const Icon(Icons.sd_card_alert_outlined,
                        color: accent, size: 64),
                    const SizedBox(height: 20),
                    Text(
                      _t('تعذّر فتح أذكاري',
                          'Azkari could not start', 'Azkari açılamadı'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _t(
                        'لم نتمكن من قراءة إعداداتك المحفوظة على الجهاز. '
                            'بياناتك لم تُحذف ولم تُغيَّر.',
                        'We could not read your saved settings on this device. '
                            'Your data has not been deleted or changed.',
                        'Cihazınızdaki kayıtlı ayarlarınız okunamadı. '
                            'Verileriniz silinmedi ve değiştirilmedi.',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.6,
                        color: Color(0xFFA0AEC0),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_failedAttempts > 0) ...<Widget>[
                      Text(
                        _t(
                          'القراءة فشلت مرة أخرى. أعد المحاولة، وإن استمر الفشل '
                              'أغلق التطبيق وأعد فتحه أو أرسل التفاصيل للدعم.',
                          'Reading failed again. Retry, and if it keeps failing '
                              'restart the app or send the details to support.',
                          'Okuma yine başarısız oldu. Tekrar deneyin; sürerse '
                              'uygulamayı yeniden başlatın veya ayrıntıları gönderin.',
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    FilledButton.icon(
                      onPressed: _retrying ? null : _retry,
                      icon: _retryIcon(),
                      label: Text(
                        _retrying
                            ? _t('جارٍ المحاولة…', 'Trying…', 'Deneniyor…')
                            : _t('إعادة المحاولة', 'Try again', 'Tekrar dene'),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () =>
                          setState(() => _showDetails = !_showDetails),
                      child: Text(
                        _showDetails
                            ? _t('إخفاء التفاصيل', 'Hide details', 'Ayrıntıları gizle')
                            : _t('عرض تفاصيل الخطأ', 'Show error details',
                                'Hata ayrıntılarını göster'),
                        style: const TextStyle(color: Color(0xFF64748B)),
                      ),
                    ),
                    if (_showDetails)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF101010),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF222222)),
                        ),
                        child: SelectableText(
                          StartupDiagnostics.instance.report(),
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                            fontSize: 11,
                            height: 1.45,
                            fontFamily: 'monospace',
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
