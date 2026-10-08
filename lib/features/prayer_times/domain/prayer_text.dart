import '../../../l10n/app_localizations.dart';
import 'prayer_day.dart';
import 'prayer_place.dart';

/// The words and numbers this feature is read in.
///
/// They live down here rather than in the card because the card is no longer
/// the only thing that says them: a notification raised at four in the morning
/// and a widget drawn on the home screen name the same six marks and print the
/// same clock, and none of the three has a [BuildContext] the others can share.
/// One set of strings, three readers.

String slotName(AppLocalizations l, PrayerSlot slot) => switch (slot) {
  PrayerSlot.fajr => l.prayerFajr,
  PrayerSlot.sunrise => l.prayerSunrise,
  PrayerSlot.dhuhr => l.prayerDhuhr,
  PrayerSlot.asr => l.prayerAsr,
  PrayerSlot.maghrib => l.prayerMaghrib,
  PrayerSlot.isha => l.prayerIsha,
};

String placeName(AppLocalizations l, PrayerPlace place) => switch (place) {
  PrayerPlace.makkah => l.prayerPlaceMakkah,
  PrayerPlace.mina => l.prayerPlaceMina,
  PrayerPlace.muzdalifah => l.prayerPlaceMuzdalifah,
  PrayerPlace.arafat => l.prayerPlaceArafat,
  PrayerPlace.madinah => l.prayerPlaceMadinah,
  PrayerPlace.jeddah => l.prayerPlaceJeddah,
};

/// "4:32 ص".
///
/// Built by hand rather than with [DateFormat], which would need
/// `initializeDateFormatting` and the whole locale database loaded at start-up
/// to render two letters this app already has translated.
String clockText(AppLocalizations l, DateTime at) {
  final hour = at.hour % 12 == 0 ? 12 : at.hour % 12;
  final minute = at.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${at.hour < 12 ? l.prayerAm : l.prayerPm}';
}

/// "4:32" — for the strip, where the column order carries the half of the day.
String shortClockText(DateTime at) {
  final hour = at.hour % 12 == 0 ? 12 : at.hour % 12;
  return '$hour:${at.minute.toString().padLeft(2, '0')}';
}

/// "1:23:45" over an hour, "23:45" under one.
///
/// The hours are dropped rather than padded to a leading zero because the last
/// hour is the one anybody is actually watching, and "0:04:12" spends three of
/// its seven characters saying nothing.
String countdownText(Duration left) {
  final hours = left.inHours;
  final minutes = left.inMinutes % 60;
  final seconds = left.inSeconds % 60;
  final mm = minutes.toString().padLeft(2, '0');
  final ss = seconds.toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
}
