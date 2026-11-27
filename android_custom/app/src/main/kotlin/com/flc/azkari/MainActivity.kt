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

    private var lastVolumeEventAt: Long = 0L
    private var lastVolumeDirection: Int = 0

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        val code = event.keyCode
        val isVolume = code == KeyEvent.KEYCODE_VOLUME_UP ||
            code == KeyEvent.KEYCODE_VOLUME_DOWN
        if (isVolume && captureVolume) {
            val dir = if (code == KeyEvent.KEYCODE_VOLUME_UP) 1 else -1
            // الضغط المستمر يولّد أحداث ACTION_DOWN متكررة بنفس النوع؛ تُحتسب
            // تسبيحة واحدة فقط عند أول ضغطة، وأي حدث تكرار يُبتلع بلا عدّ.
            val isRepeat = event.repeatCount > 0 ||
                event.action == KeyEvent.ACTION_MULTIPLE
            val now = System.currentTimeMillis()
            val tooSoon = dir == lastVolumeDirection &&
                now - lastVolumeEventAt < MIN_PRESS_GAP_MS
            if (!isRepeat && event.action == KeyEvent.ACTION_DOWN && !tooSoon) {
                lastVolumeEventAt = now
                lastVolumeDirection = dir
                channel?.invokeMethod("volumeKey", dir)
            }
            // منع تغيير صوت الهاتف تماماً (سواء ضغطة أصلية أو تكراراً)
            return true
        }
        return super.dispatchKeyEvent(event)
    }

    private companion object {
        /** أقل فاصل بين ضغطتين منفصلتين على نفس الزر (مللي ثانية). */
        const val MIN_PRESS_GAP_MS = 150L
    }
}
