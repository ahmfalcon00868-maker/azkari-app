// اختبارات «البدء المرن»: الخدمات الاختيارية وفشل التخزين لا يجوز أن يمنعا
// فتح التطبيق أو أن يبتلعا الخطأ بصمت.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:azkari/main.dart' as app;
import 'package:azkari/services/startup_diagnostics.dart';
import 'package:azkari/widgets/startup_failure_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('guardedStartup', () {
    test('failing optional task is recorded and never thrown', () async {
      final bool ok = await guardedStartup(
        'optional-throws',
        () async => throw StateError('audio init failed'),
      );
      expect(ok, isFalse);
      // الخطأ صار مرئيًا في السجل بدل الابتلاع الصامت.
      expect(StartupDiagnostics.instance.hasErrors, isTrue);
      expect(StartupDiagnostics.instance.report(), contains('optional-throws'));
    });

    test('hanging optional task is cut by the timeout', () async {
      final bool ok = await guardedStartup(
        'optional-hangs',
        () => Future<void>.delayed(const Duration(milliseconds: 400)),
        timeout: const Duration(milliseconds: 30),
      );
      expect(ok, isFalse);
      expect(StartupDiagnostics.instance.report(), contains('optional-hangs'));
    });

    test('successful task is recorded as ok', () async {
      final bool ok = await guardedStartup('optional-ok', () async {});
      expect(ok, isTrue);
      expect(StartupDiagnostics.instance.report(), contains('✓ optional-ok'));
    });
  });

  group('storage', () {
    test('loadPrefsSafely returns prefs when storage works', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{'darkMode': true});
      final SharedPreferences? prefs = await app.loadPrefsSafely();
      expect(prefs, isNotNull);
      expect(prefs!.getBool('darkMode'), isTrue);
      expect(StartupDiagnostics.instance.report(), contains('storage-ready'));
    });
  });

  group('StartupFailureApp', () {
    testWidgets('shows an understandable message and opens the app after retry',
        (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      int attempts = 0;
      SharedPreferences? opened;

      await tester.pumpWidget(
        StartupFailureApp(
          lang: 'ar',
          loadPrefs: () async {
            attempts++;
            if (attempts == 1) return null; // أول محاولة تفشل
            return SharedPreferences.getInstance();
          },
          onReady: (SharedPreferences prefs) => opened = prefs,
        ),
      );

      // رسالة واضحة، وليست شاشة بيضاء.
      expect(find.text('تعذّر فتح أذكاري'), findsOneWidget);
      expect(find.textContaining('لم تُحذف'), findsOneWidget);

      // المحاولة الأولى تفشل ⇒ تُعرض رسالة الفشل مرة أخرى + زر إعادة المحاولة.
      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pump();
      await tester.pump();
      expect(attempts, 1);
      expect(find.textContaining('القراءة فشلت'), findsOneWidget);

      // المحاولة الثانية تنجح ⇒ يُفتح التطبيق الحقيقي.
      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pump();
      await tester.pump();
      expect(attempts, 2);
      expect(opened, isNotNull);
    });

    testWidgets('shows diagnostics on demand', (WidgetTester tester) async {
      await tester.pumpWidget(
        StartupFailureApp(
          lang: 'en',
          loadPrefs: () async => null,
          onReady: (_) {},
        ),
      );
      expect(find.text('Azkari could not start'), findsOneWidget);
      await tester.tap(find.text('Show error details'));
      await tester.pump();
      expect(find.textContaining('startup'), findsWidgets);
    });
  });
}
