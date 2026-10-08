package com.shud.hajjoperations

import android.content.Context
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

/**
 * The noise an urgent report makes while its dialog is on screen.
 *
 * Written by hand rather than taken from an audio plugin, for the same reason
 * the home-screen widget is: this app needs one sound played one way, and a
 * general-purpose player would be a dependency in every build, a plugin
 * registration in every launch, and a second opinion about audio focus — in
 * service of about forty lines.
 *
 * Three decisions, and each of them is the difference between a man noticing
 * and a man not noticing:
 *
 *  * **USAGE_ALARM, not USAGE_NOTIFICATION.** An alarm plays on the alarm
 *    stream, which is the one the phone does NOT silence when it is on silent,
 *    and the one Do Not Disturb's "alarms only" lets through. A notification
 *    sound in a pocket at 3am is a sound nobody hears; that is the whole
 *    complaint this exists to answer.
 *  * **Looping.** A single chime is over before anyone has looked up. This
 *    keeps going until somebody presses the button, which is what makes it an
 *    alarm rather than a notification with ambition.
 *  * **Vibration alongside it**, because the one phone that will not make a
 *    sound is the one somebody has muted at hardware level, and it is nearly
 *    always the phone of whoever is in a meeting rather than asleep.
 *
 * Nothing here throws outward. A device with no alarm tone, no vibrator, or an
 * OEM that refuses one of these is a device that shows the dialog silently —
 * which is worse than the sound and far better than a crash on the one screen
 * that must appear.
 */
object AlarmSound {

    const val CHANNEL = "com.shud.hajjoperations/alarm_sound"

    private var player: MediaPlayer? = null

    /**
     * Starts, or does nothing if it is already going.
     *
     * The second report arriving while the first is still ringing must not
     * start a second player over the top of the first — that is two alarms out
     * of phase, and only one of them would ever be stopped.
     */
    fun start(context: Context) {
        if (player != null) return

        val uri = RingtoneManager.getActualDefaultRingtoneUri(
            context, RingtoneManager.TYPE_ALARM,
        ) ?: RingtoneManager.getActualDefaultRingtoneUri(
            context, RingtoneManager.TYPE_NOTIFICATION,
        ) ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)

        vibrate(context)
        if (uri == null) return

        try {
            player = MediaPlayer().apply {
                setDataSource(context, uri)
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build(),
                )
                isLooping = true
                // Prepared synchronously: the source is a local content URI, so
                // there is nothing to buffer, and the async form would leave a
                // gap between "an emergency arrived" and any sound at all.
                prepare()
                start()
            }
        } catch (e: Exception) {
            // A tone the device cannot open. The dialog still appears.
            player?.release()
            player = null
        }
    }

    /** Silence. Safe to call when nothing is playing, which is most calls. */
    fun stop(context: Context) {
        try {
            player?.let {
                if (it.isPlaying) it.stop()
                it.release()
            }
        } catch (e: Exception) {
            // Already torn down by the system; nothing left to do.
        }
        player = null
        try {
            vibrator(context)?.cancel()
        } catch (e: Exception) {
        }
    }

    /**
     * A repeating pattern rather than one buzz, and on the alarm usage so a
     * phone in Do Not Disturb still feels it. Index 0 repeats the whole pattern
     * from the start; [stop] is what ends it.
     */
    private fun vibrate(context: Context) {
        val vibrator = vibrator(context) ?: return
        if (!vibrator.hasVibrator()) return
        val pattern = longArrayOf(0, 600, 400)
        try {
            vibrator.vibrate(
                VibrationEffect.createWaveform(pattern, 0),
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
        } catch (e: Exception) {
        }
    }

    private fun vibrator(context: Context): Vibrator? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE)
                as? VibratorManager)?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
}
