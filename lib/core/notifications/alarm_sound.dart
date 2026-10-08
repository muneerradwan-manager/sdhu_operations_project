import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../logging/app_logger.dart';

/// The looping alarm tone behind an urgent report's dialog.
///
/// Android only, and hand-written rather than taken from an audio package —
/// `AlarmSound.kt` explains why, and what it costs to get this wrong (a
/// notification chime in a pocket at 3am is a sound nobody hears).
///
/// Everywhere else this is a no-op: the dialog still appears, in silence. That
/// is the right failure. A desktop reader is looking at the screen the alarm
/// would have been for.
class AlarmSoundBridge {
  AlarmSoundBridge._();
  static final instance = AlarmSoundBridge._();

  /// Matches `AlarmSound.CHANNEL` on the Kotlin side.
  static const _channel = MethodChannel('com.shud.hajjoperations/alarm_sound');

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// True while this side believes something is playing.
  ///
  /// Kept here as well as in Kotlin because [stop] is called from a dialog's
  /// dismissal, which can happen more than once for one alarm — a barrier tap,
  /// a back gesture and the button all end the same dialog — and a channel call
  /// per dismissal is noise on the platform thread for nothing.
  bool _playing = false;

  Future<void> start() async {
    if (!supported || _playing) return;
    _playing = true;
    try {
      await _channel.invokeMethod<void>('start');
    } catch (e) {
      AppLogger.warn('alarm', 'start failed: $e');
    }
  }

  /// Silence. Never throws, and deliberately clears [_playing] BEFORE the call:
  /// a stop that failed must not leave this side thinking a tone is still going
  /// and refusing to start the next one.
  Future<void> stop() async {
    if (!supported || !_playing) return;
    _playing = false;
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (e) {
      AppLogger.warn('alarm', 'stop failed: $e');
    }
  }
}
