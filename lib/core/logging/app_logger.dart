import 'package:flutter/foundation.dart';

/// Where a line came from, so a busy console can be read at a glance.
enum LogLevel {
  debug('DEBUG', '\x1B[90m'),
  info('INFO ', '\x1B[36m'),
  warn('WARN ', '\x1B[33m'),
  error('ERROR', '\x1B[31m');

  const LogLevel(this.label, this.colour);

  final String label;

  /// ANSI colour. `flutter run` renders these; a terminal that does not will
  /// show the escape codes, which is why [AppLogger.useColour] can turn them
  /// off wholesale.
  final String colour;
}

/// The app's console log.
///
/// Debug builds only — every call compiles down to nothing in release, so a
/// request body cannot end up in a production log by accident. That is not a
/// convenience: these lines carry names, phone numbers and signed URLs.
///
/// Printing goes through [debugPrint] rather than `print`, because Android's
/// logcat drops anything past ~1000 characters on a line and a truncated
/// response body is worse than none.
class AppLogger {
  const AppLogger._();

  static const _reset = '\x1B[0m';

  /// Set false when the console mangles escape codes.
  static bool useColour = true;

  /// How much of a request or response body to print before cutting it off.
  /// A list of two hundred employees is not something anybody reads in a
  /// terminal, but its first lines say whether the query was right.
  static int maxBodyChars = 2000;

  static bool get enabled => kDebugMode;

  static void debug(String tag, Object? message) =>
      _write(LogLevel.debug, tag, message);

  static void info(String tag, Object? message) =>
      _write(LogLevel.info, tag, message);

  static void warn(String tag, Object? message) =>
      _write(LogLevel.warn, tag, message);

  /// An error, with the stack trace under it when there is one.
  static void error(
    String tag,
    Object? message, [
    Object? errorObject,
    StackTrace? stackTrace,
  ]) {
    if (!enabled) return;
    _write(LogLevel.error, tag, message);
    if (errorObject != null) _write(LogLevel.error, tag, errorObject);
    if (stackTrace != null) {
      // Trimmed: the first frames are where it broke, and the rest is the
      // framework getting there.
      final frames = stackTrace.toString().trimRight().split('\n');
      for (final frame in frames.take(12)) {
        _write(LogLevel.error, tag, '  $frame');
      }
      if (frames.length > 12) {
        _write(LogLevel.error, tag, '  … ${frames.length - 12} more frames');
      }
    }
  }

  /// Cuts [body] down to [maxBodyChars], saying how much was left out.
  static String truncate(String? body) {
    if (body == null || body.isEmpty) return '';
    if (body.length <= maxBodyChars) return body;
    return '${body.substring(0, maxBodyChars)}'
        '\n… ${body.length - maxBodyChars} more characters';
  }

  static void _write(LogLevel level, String tag, Object? message) {
    if (!enabled) return;
    final now = DateTime.now();
    final time =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}.'
        '${now.millisecond.toString().padLeft(3, '0')}';
    final line = '$time ${level.label} [$tag] $message';
    debugPrint(useColour ? '${level.colour}$line$_reset' : line);
  }
}
