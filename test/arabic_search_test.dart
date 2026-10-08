import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/utils/arabic_search.dart';

/// The directory has to find a name however it was spelled.
///
/// The mission's own decisions spell the same man both ways in the same week —
/// 'أحمد' and 'احمد', 'نقاوة' and 'نقاوه' — so a search that treats those as
/// different words hides records that are sitting in the list.
void main() {
  group('foldArabic', () {
    test('hamza on a seat folds to bare alif', () {
      expect(foldArabic('أحمد'), foldArabic('احمد'));
      expect(foldArabic('إبراهيم'), foldArabic('ابراهيم'));
      expect(foldArabic('آمنة'), foldArabic('امنه'));
    });

    test('taa marbuta folds to haa', () {
      expect(foldArabic('نقاوة'), foldArabic('نقاوه'));
      expect(foldArabic('حليمة'), foldArabic('حليمه'));
    });

    test('alif maqsura folds to yaa', () {
      expect(foldArabic('مصطفى'), foldArabic('مصطفي'));
      expect(foldArabic('ذكرى'), foldArabic('ذكري'));
    });

    test('harakat and tatweel are ignored', () {
      expect(foldArabic('مُحَمَّد'), foldArabic('محمد'));
      expect(foldArabic('محـــمد'), foldArabic('محمد'));
    });

    test('hamza seats on waw and yaa fold to their letters', () {
      expect(foldArabic('مؤتمن'), foldArabic('موتمن'));
      expect(foldArabic('سائر'), foldArabic('ساير'));
    });

    test('Arabic-Indic digits match ASCII ones', () {
      expect(foldArabic('مخيم ١٦'), foldArabic('مخيم 16'));
    });

    test('latin is lowercased, so one call serves a mixed list', () {
      expect(foldArabic('Ahmad'), foldArabic('ahmad'));
    });

    test('a عبد name folds the same with the space and without', () {
      expect(foldArabic('عبدالله'), foldArabic('عبد الله'));
      expect(foldArabic('عبدالرحمن'), foldArabic('عبد الرحمن'));
      expect(foldArabic('عبدالعزيز'), foldArabic('عبد العزيز'));
      // And in the middle of a full name, not only at the start of one.
      expect(
        foldArabic('محمد عبد الله الأحمد'),
        foldArabic('محمد عبدالله الاحمد'),
      );
    });

    test('only a STANDALONE عبد closes, never three letters inside a word', () {
      // عابد and معبد are not عبد, and their space is a real one.
      expect(foldArabic('عابد الحسن'), contains(' '));
      expect(foldArabic('معبد الله'), contains(' '));
      // A عبد with nothing after it has no space to close.
      expect(foldArabic('محمد عبد'), foldArabic('محمد عبد'));
      expect(foldArabic('محمد عبد'), endsWith('عبد'));
    });

    test('tashkeel inside عبد does not stop it closing', () {
      // The marks are gone by the time the space is looked at.
      expect(foldArabic('عَبْد الله'), foldArabic('عبدالله'));
    });
  });

  group('arabicMatchesAll', () {
    const fields = ['أحمد', 'فتحي', 'الحدّاد', 'أحمد فتحي الحدّاد'];

    test('finds a man by his first name alone', () {
      expect(arabicMatchesAll(fields, 'احمد'), isTrue);
    });

    test('finds him by his FATHER name alone', () {
      expect(arabicMatchesAll(fields, 'فتحي'), isTrue);
    });

    test('finds him by his surname alone', () {
      expect(arabicMatchesAll(fields, 'الحداد'), isTrue);
    });

    test('finds him by first + surname, skipping the father name', () {
      expect(arabicMatchesAll(fields, 'أحمد الحداد'), isTrue);
    });

    test('word order does not matter', () {
      expect(arabicMatchesAll(fields, 'الحداد احمد'), isTrue);
    });

    test('every word must land somewhere', () {
      expect(arabicMatchesAll(fields, 'احمد سرميني'), isFalse);
    });

    test('an empty query matches everyone', () {
      expect(arabicMatchesAll(fields, '   '), isTrue);
    });

    test('null fields are skipped rather than matched', () {
      expect(arabicMatchesAll([null, 'أحمد'], 'احمد'), isTrue);
      expect(arabicMatchesAll([null, null], 'احمد'), isFalse);
    });

    test('spelling differences on BOTH sides fold together', () {
      // The record is filed one way and searched the other.
      expect(arabicMatchesAll(['حسن نقاوه'], 'نقاوة'), isTrue);
      expect(arabicMatchesAll(['حسن نقاوة'], 'نقاوه'), isTrue);
    });

    test('a عبد name is found whichever way either side spelled it', () {
      // The four combinations, because the file and the searcher disagree in
      // both directions and neither of them is wrong.
      expect(arabicMatchesAll(['عبد الله فتحي'], 'عبدالله'), isTrue);
      expect(arabicMatchesAll(['عبدالله فتحي'], 'عبد الله'), isTrue);
      expect(arabicMatchesAll(['عبد الرحمن سالم'], 'عبدالرحمن سالم'), isTrue);
      expect(arabicMatchesAll(['عبدالرحمن سالم'], 'عبد الرحمن سالم'), isTrue);
    });

    test('عبد alone still narrows rather than matching the whole family', () {
      // It is a prefix of every one of these names, so it finds them all —
      // which is what a searcher who typed three letters asked for.
      expect(arabicMatchesAll(['عبد الله فتحي'], 'عبد'), isTrue);
      expect(arabicMatchesAll(['عبدالرحمن سالم'], 'عبد'), isTrue);
      // But the second half is not thrown away: عبدالله is not عبدالرحمن.
      expect(arabicMatchesAll(['عبد الرحمن سالم'], 'عبدالله'), isFalse);
      expect(arabicMatchesAll(['عبدالله فتحي'], 'عبد الرحمن'), isFalse);
    });
  });
}
