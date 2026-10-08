import 'package:geolocator/geolocator.dart';

import '../logging/app_logger.dart';

/// The phone's position, or nothing, and never an exception.
///
/// Distinct from the location picker's version of this on purpose. There, a
/// failure is worth a sentence on screen — the person pressed "use my
/// location" and is waiting for a pin. Here, the position is EVIDENCE
/// accompanying an act that must succeed without it: a man reporting that he
/// has arrived at a camp in Mina, where the location service may be off, the
/// permission refused, or the sky simply not visible from inside a tent.
///
/// So every way of failing collapses to null rather than to an exception. What
/// the CALLER does with the null has changed, and the change is worth naming
/// here because this comment used to promise the opposite: a check-in with no
/// position is not a weaker record any more, it is refused (0098). Enforcing
/// proximity is what keeps the season map from painting green pins off arrivals
/// that could have been filed from another city — and enforcing it means a fix
/// is no longer optional evidence but the thing being checked.
///
/// This function still refuses to throw. Null is an answer the caller must
/// handle, not a failure to report.
///
/// [currentFix] is the same thing narrowed to the three numbers anybody
/// actually uses, so a caller can be handed a position in a test without
/// building a whole `Position` — and so the check-in flow does not depend on
/// geolocator's types to state its own rules.
Future<Position?> currentPositionOrNull({
  Duration timeout = const Duration(seconds: 12),
}) async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      AppLogger.info('location', 'service off — no fix');
      return null;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      AppLogger.info('location', 'permission refused — no fix');
      return null;
    }

    // Shorter than the picker's twenty seconds. Somebody is standing at a gate
    // waiting for a button to finish; a fix that has not arrived in twelve
    // seconds is not going to arrive before he gives up and walks away, and
    // walking away with no record is the outcome this exists to prevent.
    return await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: timeout,
      ),
    );
  } catch (error) {
    AppLogger.info('location', 'no fix — $error');
    return null;
  }
}

/// Where the phone says it is, and what it thinks that is worth.
typedef Fix = ({double latitude, double longitude, double? accuracy});

/// [currentPositionOrNull], as the three numbers a caller uses.
Future<Fix?> currentFix() async {
  final position = await currentPositionOrNull();
  if (position == null) return null;
  return (
    latitude: position.latitude,
    longitude: position.longitude,
    accuracy: position.accuracy,
  );
}
