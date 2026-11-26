import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:azkari/data/azkar_data.dart';
import 'package:azkari/services/cloud_sync_service.dart';
import 'package:azkari/services/update_service.dart';

void main() {
  group('قاعدة بيانات الأذكار', () {
    final items = getInitialAzkarList();

    test('تحتوي على أذكار وكل التصنيفات السبعة', () {
      expect(items, isNotEmpty);
      final categories = items.map((z) => z.category).toSet();
      expect(
        categories,
        containsAll(<String>[
          'morning',
          'evening',
          'sleep',
          'wakeup',
          'prayer',
          'daily',
          'supplications',
        ]),
      );
    });

    test('كل ذكر له نص غير فارغ ومعرّف فريد وهدف موجب', () {
      final ids = <int>{};
      for (final z in items) {
        expect(z.text.trim(), isNotEmpty, reason: 'نص الذكر ${z.id} فارغ');
        expect(z.target, greaterThan(0), reason: 'هدف الذكر ${z.id} غير صالح');
        expect(ids.add(z.id), isTrue, reason: 'معرّف مكرر: ${z.id}');
      }
    });

    test('لكل ذكر ترجمة إنجليزية وتركية', () {
      for (final z in items) {
        expect(kAzkarEnglishById.containsKey(z.id), isTrue,
            reason: 'لا توجد ترجمة إنجليزية للذكر ${z.id}');
        expect(kAzkarTurkishById.containsKey(z.id), isTrue,
            reason: 'لا توجد ترجمة تركية للذكر ${z.id}');
      }
    });
  });

  group('روابط المزامنة السحابية', () {
    test('المفتاح العام يُرسل في apikey فقط وليس Authorization', () {
      final headers = CloudSyncService.authHeaders;
      expect(headers['apikey'], CloudSyncService.kSupabaseAnonKey);
      expect(headers.containsKey('Authorization'), isFalse,
          reason: 'مفاتيح sb_publishable ليست JWT وترفض في Authorization');
    });

    test('رابط المشروع أساسي بدون مسار', () {
      final uri = Uri.parse(CloudSyncService.kSupabaseProjectUrl);
      expect(uri.path, anyOf('', '/'));
      expect(uri.hasQuery, isFalse);
      expect(CloudSyncService.isCloudConfigured, isTrue);
    });

    test('مسارات REST والدوال تُبنى بشكل صحيح', () {
      final base = CloudSyncService.kSupabaseProjectUrl;
      expect(CloudSyncService.rest('azkari_sync?select=payload'),
          '$base/rest/v1/azkari_sync?select=payload');
      expect(CloudSyncService.function('verify-bybit'),
          '$base/functions/v1/verify-bybit');
    });

    test('تصدير واستيراد النسخة الاحتياطية يعمل ذهابًا وإيابًا', () async {
      SharedPreferences.setMockInitialValues({
        'totalTasbihCount': 33,
        'is_azkari_pro': true,
        'bookmarkedSurahs': <String>['2', '18'],
        'ignoredKey': 'should-not-be-exported',
      });
      final source = await SharedPreferences.getInstance();
      final json = CloudSyncService.instance.exportSnapshotJson(source);

      expect(json, contains('azkari_sync_v1'));
      expect(json, isNot(contains('ignoredKey')));

      SharedPreferences.setMockInitialValues({});
      final target = await SharedPreferences.getInstance();
      expect(
        await CloudSyncService.instance.importSnapshotJson(target, json),
        isTrue,
      );
      expect(target.getInt('totalTasbihCount'), 33);
      expect(target.getBool('is_azkari_pro'), isTrue);
      expect(target.getStringList('bookmarkedSurahs'), <String>['2', '18']);
    });

    test('رفض JSON غير صالح', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      expect(
        await CloudSyncService.instance.importSnapshotJson(prefs, 'not-json'),
        isFalse,
      );
    });
  });

  group('حماية المستخدمين من التحديثات', () {
    test('نظام التحديثات موقوف أثناء التطوير', () {
      expect(
        UpdateService.kUpdatesEnabled,
        isFalse,
        reason: 'لا تُفعّل التحديثات قبل جهوزية الإصدار الجديد',
      );
    });

    test('مقارنة الإصدارات تعتبر الأحدث فقط تحديثًا', () {
      expect(UpdateService.isNewerVersion('1.1.0', '1.0.0'), isTrue);
      expect(UpdateService.isNewerVersion('v1.2.0', '1.1.9'), isTrue);
      expect(UpdateService.isNewerVersion('1.0.0', '1.1.0'), isFalse);
      expect(UpdateService.isNewerVersion('1.1.0', '1.1.0'), isFalse);
      expect(UpdateService.isNewerVersion('1.1', '1.1.0'), isFalse);
    });
  });
}
