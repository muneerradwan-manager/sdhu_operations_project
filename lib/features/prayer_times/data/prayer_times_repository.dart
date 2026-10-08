import 'package:adhan_dart/adhan_dart.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/prayer_day.dart';
import '../domain/prayer_fix.dart';

/// Where the times come from: the device's position, and the astronomy.
///
/// The two halves are here together because they answer one question and they
/// fail together — a position that never arrives and an almanac that cannot be
/// computed both end in the same place, which is "show Makkah and say so".
class PrayerTimesRepository {
  /// المسجد الحرام, and the same point the map picker falls back to.
  ///
  /// A prayer card cannot render nothing. Before the first fix — and on a
  /// device that will never give one, a desktop with no location provider —
  /// this is what it computes, and it is marked approximate everywhere it is
  /// shown so that nobody takes it for their own.
  static const fallbackLatitude = 21.422510;
  static const fallbackLongitude = 39.826168;

  static const _kLatitude = 'prayer.latitude';
  static const _kLongitude = 'prayer.longitude';
  static const _kCapturedAt = 'prayer.capturedAt';

  /// The last position this device saw, from a previous run if need be.
  ///
  /// Read from preferences rather than from `getLastKnownPosition`: that call
  /// still needs the permission and still crosses the platform channel, and the
  /// whole point of this one is to have something to draw with before either
  /// has happened.
  Future<PrayerFix?> lastKnownFix() async {
    final prefs = await SharedPreferences.getInstance();
    final latitude = prefs.getDouble(_kLatitude);
    final longitude = prefs.getDouble(_kLongitude);
    final capturedAt = prefs.getInt(_kCapturedAt);
    if (latitude == null || longitude == null || capturedAt == null) {
      return null;
    }
    return PrayerFix(
      latitude: latitude,
      longitude: longitude,
      capturedAt: DateTime.fromMillisecondsSinceEpoch(capturedAt),
    );
  }

  /// Asks the device where it is.
  ///
  /// [prompt] is the whole permission policy in one flag, and it is false on
  /// every automatic call. The home screen is the first thing a person sees
  /// after signing in, and throwing the system's location dialog at them there
  /// — before they have touched anything, with nothing on screen to explain it
  /// — is how an app teaches people to press "Don't allow". So a silent attempt
  /// stops at [LocationOutcome.needsPermission] and the card grows a chip that
  /// says what it wants; the dialog appears when that chip is tapped, which is
  /// the moment the request explains itself.
  Future<LocationResult> locate({required bool prompt}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult(LocationOutcome.serviceOff);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (!prompt) {
          return const LocationResult(LocationOutcome.needsPermission);
        }
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationResult(LocationOutcome.permanentlyDenied);
      }
      if (permission == LocationPermission.denied) {
        return const LocationResult(LocationOutcome.needsPermission);
      }

      final position = await Geolocator.getCurrentPosition(
        // Deliberately LOW, where the rest of the app asks for high. A prayer
        // time is a function of latitude and longitude at the scale of
        // kilometres — a hundred metres of error is a fraction of a second of
        // Fajr — so the metre-accurate fix buys nothing and costs the GPS
        // radio, several seconds of waiting, and a battery figure attributed to
        // this app in the phone's settings. Low accuracy is answered from the
        // network, usually before the card has finished its entry animation.
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 20),
        ),
      );

      final fix = PrayerFix(
        latitude: position.latitude,
        longitude: position.longitude,
        capturedAt: DateTime.now(),
      );
      await _remember(fix);
      return LocationResult(LocationOutcome.located, fix);
    } catch (_) {
      // A timeout, a platform with no implementation, a plugin that threw on a
      // desktop build. None of them are worth distinguishing here: whatever
      // happened, there is no new position and the caller keeps the old one.
      return const LocationResult(LocationOutcome.failed);
    }
  }

  /// Opens the system's own location page — where a refusal is undone.
  ///
  /// On Windows this is not a fallback, it is the entire answer. There is no
  /// per-app permission dialog on a desktop: `requestPermission` there reads a
  /// system-wide switch and reports what it finds, so a refusal cannot be
  /// re-asked from inside the app at all — it is turned around in
  /// `ms-settings:privacy-location` or it is not turned around. The same page
  /// carries both switches that can produce it, the machine's "location
  /// services" and the one for desktop apps, which is why the reader is sent
  /// there for a denial and for a switched-off service alike.
  Future<void> openSettings() async {
    try {
      await Geolocator.openLocationSettings();
    } catch (_) {
      // A platform with no page to open. There is nothing to say about it that
      // the reader could act on.
    }
  }

  Future<void> _remember(PrayerFix fix) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kLatitude, fix.latitude);
    await prefs.setDouble(_kLongitude, fix.longitude);
    await prefs.setInt(_kCapturedAt, fix.capturedAt.millisecondsSinceEpoch);
  }

  /// The day's times for a position, in local time.
  ///
  /// Pure, synchronous and cheap — a few dozen trigonometric calls — which is
  /// why nothing caches it and why the cubit is free to recompute on every new
  /// fix rather than working out whether the move was far enough to matter.
  PrayerDay dayFor({
    required double latitude,
    required double longitude,
    DateTime? at,
  }) {
    final now = at ?? DateTime.now();
    final times = PrayerTimes(
      // The LOCAL calendar day, handed over as a UTC midnight. The library
      // stamps its results onto whatever year/month/day it is given and returns
      // them in UTC; passing a local DateTime would have it read the fields off
      // a value it then treats as UTC, which is the same day here and a day out
      // for anyone east of the line at the wrong hour.
      date: DateTime.utc(now.year, now.month, now.day),
      coordinates: Coordinates(latitude, longitude),
      calculationParameters: parametersFor(latitude, longitude),
    );

    return PrayerDay(
      day: DateTime(now.year, now.month, now.day),
      fajr: times.fajr.toLocal(),
      sunrise: times.sunrise.toLocal(),
      dhuhr: times.dhuhr.toLocal(),
      asr: times.asr.toLocal(),
      maghrib: times.maghrib.toLocal(),
      isha: times.isha.toLocal(),
      previousIsha: times.ishaBefore.toLocal(),
      nextFajr: times.fajrAfter.toLocal(),
    );
  }

  /// أم القرى inside the Kingdom, رابطة العالم الإسلامي outside it.
  ///
  /// There is no neutral choice here. The methods disagree by up to a quarter of
  /// an hour at Fajr and Isha, and a card showing a Makkah reader anything other
  /// than the أم القرى times — the ones on the Haram's own board, and on every
  /// clock in every hotel around it — is simply wrong to them, however defensible
  /// the angle behind it. Umm al-Qura is not the general answer, though: its
  /// ninety-minute Isha interval is derived for this latitude and drifts badly
  /// away from it, so the mission's people back in Syria get the Muslim World
  /// League's angles, which are what is used there.
  ///
  /// The box is the Kingdom, loosely: 16°–33° N, 34.5°–56° E.
  static CalculationParameters parametersFor(
    double latitude,
    double longitude,
  ) {
    final inKingdom =
        latitude >= 16 &&
        latitude <= 33 &&
        longitude >= 34.5 &&
        longitude <= 56;
    // Madhab is left at the library's default of Shāfiʿī, which is the ʿAsr the
    // Kingdom's own calendar prints.
    return inKingdom
        ? CalculationMethodParameters.ummAlQura()
        : CalculationMethodParameters.muslimWorldLeague();
  }
}
