import 'package:equatable/equatable.dart';

/// A position, and when it was taken.
///
/// The timestamp is the point of the class. A fix is cached so the card can
/// draw before the GPS answers — and a cached fix is a claim about where
/// somebody was, not where they are. [PrayerFix.capturedAt] is what lets the
/// cubit decide whether to trust it or go and ask again.
class PrayerFix extends Equatable {
  const PrayerFix({
    required this.latitude,
    required this.longitude,
    required this.capturedAt,
  });

  final double latitude;
  final double longitude;
  final DateTime capturedAt;

  @override
  List<Object?> get props => [latitude, longitude, capturedAt];
}

/// What came of asking the device where it is.
enum LocationOutcome {
  /// A position arrived and has been remembered.
  located,

  /// Permission has not been granted, and this attempt was not allowed to ask
  /// — see `PrayerTimesRepository.locate`.
  needsPermission,

  /// Refused, and the system will not show the dialog again.
  permanentlyDenied,

  /// Location is switched off on the device.
  serviceOff,

  /// It threw, it timed out, or the platform has no implementation. All three
  /// mean the same thing to the card: keep what you had.
  failed,
}

/// [LocationOutcome], and the fix if there was one.
class LocationResult {
  const LocationResult(this.outcome, [this.fix]);

  final LocationOutcome outcome;
  final PrayerFix? fix;
}
