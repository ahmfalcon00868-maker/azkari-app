import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// قفل «الخشوع»: يمنع انطفاء الشاشة أثناء القراءة ويخفي الشريط السفلي،
/// ويعود بلمسة واحدة إلى الوضع الطبيعي.
class KhushuService {
  KhushuService._();

  /// حالة القفل مشتركة بين الشريط السفلي وصفحات القراءة.
  static final ValueNotifier<bool> active = ValueNotifier<bool>(false);

  static Future<void> toggle({bool? value}) async {
    final next = value ?? !active.value;
    active.value = next;
    try {
      await WakelockPlus.toggle(enable: next);
    } catch (_) {
      // بعض المنصات لا تدعم Wakelock — الحالة تبقى محفوظة في الواجهة.
    }
  }

  static Future<void> disable() => toggle(value: false);
}
