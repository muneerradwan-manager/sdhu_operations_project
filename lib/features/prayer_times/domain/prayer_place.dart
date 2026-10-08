import 'dart:math' as math;

/// The places this mission actually stands in, so the card can name one.
///
/// A prayer card has to say where its times are for — a Fajr with no place
/// beside it is a number the reader has no way to check. The honest general
/// answer is reverse geocoding, which means another package, another network
/// call and another permission dialog for a label.
///
/// This app does not need the general answer. A Hajj mission spends its season
/// inside a handful of named points, and between them the difference in Fajr is
/// a minute or two — منى is eight kilometres from the Haram, which is about
/// twenty seconds of longitude. So the label is drawn from a list of six, by
/// distance, with a radius each; anywhere else the card says "موقعك" and shows
/// the times it computed, which is true and enough.
///
/// The radii are deliberately tight and deliberately unequal. مكة's is six
/// kilometres rather than the ten that would cover the city, because منى's
/// centre is eight away and a Makkah radius that swallows Mina makes the label
/// wrong on the one night of the year it matters most.
enum PrayerPlace {
  /// المسجد الحرام.
  makkah(21.422510, 39.826168, 6),

  mina(21.413300, 39.893300, 3.5),

  muzdalifah(21.383300, 39.937000, 3),

  /// عرفات — the widest of the three مشاعر, because the standing spreads.
  arafat(21.355000, 39.984000, 5),

  /// المسجد النبوي.
  madinah(24.467200, 39.611100, 15),

  jeddah(21.543300, 39.172800, 25);

  const PrayerPlace(this.latitude, this.longitude, this.radiusKm);

  final double latitude;
  final double longitude;

  /// How far from the point this name still holds.
  final double radiusKm;

  /// The nearest named place within its own radius, or null out in the world.
  ///
  /// Nearest rather than first-match: the radii overlap around the مشاعر, and
  /// the answer a reader wants there is the one they are standing in, not the
  /// one that happens to be declared earlier.
  static PrayerPlace? nearestTo(double latitude, double longitude) {
    PrayerPlace? best;
    var bestKm = double.infinity;
    for (final place in values) {
      final km = kilometresBetween(
        latitude,
        longitude,
        place.latitude,
        place.longitude,
      );
      if (km <= place.radiusKm && km < bestKm) {
        best = place;
        bestKm = km;
      }
    }
    return best;
  }
}

/// Great-circle distance in kilometres.
///
/// Written out rather than taken from `Geolocator.distanceBetween` so that this
/// file — and the test that pins the مشاعر apart — stays free of the plugin and
/// runs without a platform binding.
double kilometresBetween(double lat1, double lon1, double lat2, double lon2) {
  const earthRadiusKm = 6371.0;
  double radians(double degrees) => degrees * math.pi / 180;

  final dLat = radians(lat2 - lat1);
  final dLon = radians(lon2 - lon1);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(radians(lat1)) *
          math.cos(radians(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}
