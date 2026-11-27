import 'dart:async';

import 'package:flutter/services.dart';

/// اعتراض أزرار الصوت الجانبية للتسبيح.
///
/// عند تفعيل [setCapture] يرسل الجانب الأصلي (MainActivity.kt) حدث الضغط إلى
/// Dart ويعيد `true` من `dispatchKeyEvent` فيمنع تغيير صوت الجهاز تماماً.
class VolumeButtonService {
  VolumeButtonService._();
  static final VolumeButtonService instance = VolumeButtonService._();

  static const MethodChannel _channel = MethodChannel('com.flc.azkari/volume');
  final StreamController<int> _controller = StreamController<int>.broadcast();
  bool _initialized = false;

  /// بثّ الضغطات: 1 لرفع الصوت، -1 لخفضه.
  Stream<int> get presses => _controller.stream;

  void init() {
    if (_initialized) return;
    _initialized = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'volumeKey' && !_controller.isClosed) {
        final dir = (call.arguments as num?)?.toInt() ?? 1;
        _controller.add(dir);
      }
      return null;
    });
  }

  /// تفعيل/إيقاف اعتراض أزرار الصوت (يُستدعى عند دخول/خروج صفحة السبحة).
  Future<void> setCapture(bool enabled) async {
    init();
    try {
      await _channel.invokeMethod<bool>('setCapture', enabled);
    } catch (_) {
      // المنصة غير مهيأة (مثلاً أثناء الاختبارات) — تجاهل بصمت.
    }
  }
}
