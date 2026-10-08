import 'package:flutter_test/flutter_test.dart';
import 'package:hijri/hijri_calendar.dart';

import 'package:sdhu_operations_project/core/utils/hijri_utils.dart';

void main() {
  group('gregorianLabelFor', () {
    test('derives the span from the Hijri year itself, not the device clock',
        () {
      // 1447 AH began 26 June 2025 and ends mid-June 2026: the label must say
      // so regardless of what today's Gregorian year happens to be.
      expect(HijriUtils.gregorianLabelFor(1447), '2025/2026');
      expect(HijriUtils.gregorianLabelFor(1446), '2024/2025');
      expect(HijriUtils.gregorianLabelFor(1448), '2026/2027');
    });

    test('start and end are consistent with the calendar\'s own conversion',
        () {
      for (final year in [1445, 1446, 1447, 1448, 1449, 1450]) {
        final calendar = HijriCalendar();
        final start = calendar.hijriToGregorian(year, 1, 1);
        final end = calendar
            .hijriToGregorian(year + 1, 1, 1)
            .subtract(const Duration(days: 1));
        final label = HijriUtils.gregorianLabelFor(year);
        expect(
          label,
          start.year == end.year
              ? '${start.year}'
              : '${start.year}/${end.year}',
        );
        // A Hijri year is ~354 days: it must never span three Gregorian years,
        // and its end must never precede its start.
        expect(end.isAfter(start), isTrue);
        expect(end.difference(start).inDays, inInclusiveRange(350, 356));
      }
    });

    test('currentGregorianLabel agrees with the current Hijri year', () {
      expect(
        HijriUtils.currentGregorianLabel(),
        HijriUtils.gregorianLabelFor(HijriUtils.currentYear()),
      );
    });
  });
}
