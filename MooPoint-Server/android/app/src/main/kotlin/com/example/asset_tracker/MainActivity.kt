package com.example.asset_tracker

import android.media.AudioManager
import android.media.ToneGenerator
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "moopoint/beep"
    private var tone: ToneGenerator? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "beep" -> {
                        val durationMs = call.argument<Int>("durationMs") ?: 80
                        val volume = call.argument<Int>("volume") ?: 80

                        if (tone == null) {
                            tone = ToneGenerator(AudioManager.STREAM_MUSIC, volume)
                        }

                        tone?.startTone(ToneGenerator.TONE_PROP_BEEP, durationMs)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        tone?.release()
        tone = null
        super.onDestroy()
    }
}
