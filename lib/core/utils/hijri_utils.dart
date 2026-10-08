import 'package:hijri/hijri_calendar.dart';

/// Helpers for deriving the current Hijri (Umm al-Qura) year.
class HijriUtils {
  const HijriUtils._();

  /// Current Hijri year, e.g. 1447.
  static int currentYear() => HijriCalendar.now().hYear;

  /// Today written out in full, in the reader's language: "21 صفر 1448" or
  /// "21 Safar 1448".
  ///
  /// [languageCode] is applied to the package's own static locale rather than
  /// passed in, because that is the only handle it offers — and an unsupported
  /// code throws rather than falling back, so it is checked first. The package
  /// carries Arabic, English and Turkish; this app ships the first two.
  ///
  /// Composed by hand rather than through the package's own `toFormat`, for the
  /// DIGITS. `toFormat` silently converts to Arabic-Indic numerals whenever the
  /// locale is Arabic, and nothing else in this app does: the Gregorian date
  /// beside this one comes from `intl`, whose Arabic data carries no ZERODIGIT
  /// and so prints "4 أغسطس 2026"; the prayer clock under it prints "4:32 ص";
  /// every date in a list prints "2026-08-04". One card showing "٢١ صفر ١٤٤٨"
  /// next to "4 أغسطس 2026" is two habits of counting on one line. The month
  /// name is still the package's, and still Arabic.
  static String todayInWords(String languageCode) {
    if (HijriCalendar.supportedLocales.contains(languageCode)) {
      HijriCalendar.setLocal(languageCode);
    }
    final today = HijriCalendar.now();
    return '${today.hDay} ${today.getLongMonthName()} ${today.hYear}';
  }

  /// The Gregorian span the *current Hijri year* falls in, e.g. "2025/2026".
  ///
  /// Derived from the Hijri year's own first and last day, not from today's
  /// Gregorian year: between 1 January and the Hijri new year the running Hijri
  /// year began in the *previous* Gregorian year, so `now.year/now.year + 1`
  /// was off by one for roughly half of every year — and the wrong label was
  /// being written onto season rows.
  static String currentGregorianLabel() =>
      gregorianLabelFor(HijriCalendar.now().hYear);

  /// The Gregorian span of any Hijri year, e.g. 1447 → "2025/2026".
  static String gregorianLabelFor(int hijriYear) {
    final calendar = HijriCalendar();
    final start = calendar.hijriToGregorian(hijriYear, 1, 1);
    // Length varies (29/30 Dhu al-Hijjah); the year of day 1 of the *next*
    // Hijri year minus a day is exact without knowing the month's length.
    final end = calendar
        .hijriToGregorian(hijriYear + 1, 1, 1)
        .subtract(const Duration(days: 1));
    return start.year == end.year
        ? '${start.year}'
        : '${start.year}/${end.year}';
  }
}
