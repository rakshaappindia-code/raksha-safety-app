package com.rakshaapp.raksha

import android.content.Context
import android.media.AudioManager
import android.os.Handler
import android.os.Looper
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    // ── Audio channel (Fake Call + Siren) ─────────────────────────────────────
    private val AUDIO_CHANNEL = "com.rakshaapp.raksha/audio"

    // ── Triggers channel (Power Button) ───────────────────────────────────────
    private val TRIGGERS_CHANNEL = "com.rakshaapp.raksha/triggers"
    private var triggersChannel: MethodChannel? = null

    // ── Audio manager ─────────────────────────────────────────────────────────
    private var savedAlarmVolume: Int = -1
    private var audioManager: AudioManager? = null

    // ── Power button triple-press detection ───────────────────────────────────
    private val powerButtonPresses = mutableListOf<Long>()
    private val handler = Handler(Looper.getMainLooper())
    private val TRIPLE_PRESS_WINDOW_MS = 2000L

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager

        // ── Audio channel handler ─────────────────────────────────────────────
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AUDIO_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {

                // Fake Call: Switch to STREAM_ALARM (bypasses silent mode)
                "setAlarmStream", "setStreamAlarm" -> {
                    audioManager?.requestAudioFocus(
                        null,
                        AudioManager.STREAM_ALARM,
                        AudioManager.AUDIOFOCUS_GAIN_TRANSIENT
                    )
                    result.success(null)
                }

                // Siren: Maximize STREAM_ALARM volume, save original
                "setMaxAlarmVolume" -> {
                    audioManager?.let { am ->
                        savedAlarmVolume = am.getStreamVolume(AudioManager.STREAM_ALARM)
                        val maxVol = am.getStreamMaxVolume(AudioManager.STREAM_ALARM)
                        am.setStreamVolume(AudioManager.STREAM_ALARM, maxVol, 0)
                    }
                    result.success(null)
                }

                // Siren stop: Restore media stream
                "setStreamMedia" -> {
                    audioManager?.let { am ->
                        if (savedAlarmVolume >= 0) {
                            am.setStreamVolume(AudioManager.STREAM_ALARM, savedAlarmVolume, 0)
                            savedAlarmVolume = -1
                        }
                        am.abandonAudioFocus(null)
                    }
                    result.success(null)
                }

                // Restore to previous volume (generic)
                "restoreVolume" -> {
                    audioManager?.let { am ->
                        if (savedAlarmVolume >= 0) {
                            am.setStreamVolume(AudioManager.STREAM_ALARM, savedAlarmVolume, 0)
                            savedAlarmVolume = -1
                        }
                        am.abandonAudioFocus(null)
                    }
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }

        // ── Triggers channel ──────────────────────────────────────────────────
        triggersChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            TRIGGERS_CHANNEL
        )
        // The Flutter side sets a handler; we call methods on this channel.
        triggersChannel?.setMethodCallHandler { _, result ->
            result.notImplemented()
        }
    }

    // ── Power button interception ─────────────────────────────────────────────

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (keyCode == KeyEvent.KEYCODE_POWER) {
            val now = System.currentTimeMillis()

            // Remove presses older than the window
            powerButtonPresses.removeAll { now - it > TRIPLE_PRESS_WINDOW_MS }
            powerButtonPresses.add(now)

            if (powerButtonPresses.size >= 3) {
                powerButtonPresses.clear()
                // Notify Flutter on the main thread
                handler.post {
                    triggersChannel?.invokeMethod("powerButtonTripleTap", null)
                }
            }

            // Do NOT consume the event — let Android handle screen on/off
            return super.onKeyDown(keyCode, event)
        }
        return super.onKeyDown(keyCode, event)
    }
}
