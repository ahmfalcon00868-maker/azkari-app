package com.flc.azkari

import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * يعترض زرّي رفع/خفض الصوت أثناء صفحة السبحة فيمنع تغيير صوت الجهاز
 * ويرسل الحدث إلى Dart عبر القناة com.flc.azkari/volume.
 */
class MainActivity : FlutterActivity() {
    private var captureVolume: Boolean = false
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.flc.azkari/volume"
        ).also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    "setCapture" -> {
                        captureVolume = call.arguments as? Boolean ?: false
                        result.success(captureVolume)
                    }
                    "isCapturing" -> result.success(captureVolume)
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        val code = event.keyCode
        val isVolume = code == KeyEvent.KEYCODE_VOLUME_UP ||
            code == KeyEvent.KEYCODE_VOLUME_DOWN
        if (isVolume && captureVolume) {
            if (event.action == KeyEvent.ACTION_DOWN) {
                val dir = if (code == KeyEvent.KEYCODE_VOLUME_UP) 1 else -1
                channel?.invokeMethod("volumeKey", dir)
            }
            // منع تغيير صوت الهاتف تماماً
            return true
        }
        return super.dispatchKeyEvent(event)
    }
}
