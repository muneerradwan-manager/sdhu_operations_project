package com.shud.hajjoperations

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * The one activity, and the only place Flutter can reach the urgent-report
 * alarm. `applicationContext` rather than `this`: the sound outlives the
 * activity.
 */
class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        alarmChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AlarmSound.CHANNEL,
        ).also { alarm ->
            alarm.setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        AlarmSound.start(applicationContext)
                        result.success(null)
                    }
                    "stop" -> {
                        AlarmSound.stop(applicationContext)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    /**
     * Dropped on the way out. The engine this channel speaks over is gone by
     * the time this runs, and a stale one held in a static would be a leak of
     * the whole engine plus a call into a messenger that no longer exists.
     */
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        alarmChannel?.setMethodCallHandler(null)
        alarmChannel = null
        // The engine going away means the dialog that was ringing is gone too,
        // and a MediaPlayer looping an alarm tone with nothing left able to stop
        // it is a phone the reader has to reboot.
        AlarmSound.stop(applicationContext)
        super.cleanUpFlutterEngine(flutterEngine)
    }

    companion object {
        /** Held so the teardown above can find it; null while no engine is attached. */
        private var alarmChannel: MethodChannel? = null
    }
}
