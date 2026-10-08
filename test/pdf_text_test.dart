import 'package:bidi/bidi.dart' as bidi;
import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/features/export/data/pdf_writer.dart';

/// Two things the exported sheet does to Arabic before drawing it, both of
/// them forced by the same defect in the `pdf` package: it lays a line out by
/// REVERSING the shaped string and then advancing word by word, and nothing in
/// that walk knows what the next word's ink will do.
///
/// Neither symptom raises an error. Both were found by reading a printed file:
/// «مُفعَّل» arrived looking like «مفطل», and «صدور القرار» arrived as
/// «صدورالقرار» — a word that does not exist, in a document that goes to the
/// leadership.
void main() {
  group('the vocalisation comes off', () {
    test('the short vowels and tanween go', () {
      // They cannot be PLACED by this package — a mark has no advance, and
      // reversing the line puts it before the letter it belongs to — so a
      // vocalised word arrives corrupted. Unvocalised and correct beats
      // vocalised and wrong.
      expect(PdfWriter.unvocalised('مُفعَّل'), 'مفعل');
      expect(PdfWriter.unvocalised('تمهيداً لاقتراح'), 'تمهيدا لاقتراح');
      expect(PdfWriter.unvocalised('وتقدّر قيمة ما لم يُستلم'),
          'وتقدر قيمة ما لم يستلم');
    });

    test('the tatweel stays, because it is a letter and not a mark', () {
      // «قـرار» is spelt with one on purpose, and it is how half the office's
      // file names are written.
      expect(PdfWriter.unvocalised('قـرار 3197 اداري'), 'قـرار 3197 اداري');
    });

    test('the Arabic-Indic digits survive', () {
      // The range U+064B…U+0670 spelt as one span would have eaten these. A
      // sheet quietly missing its numbers is a worse failure than the one the
      // strip was written for.
      expect(PdfWriter.unvocalised('٠١٢٣٤٥٦٧٨٩'), '٠١٢٣٤٥٦٧٨٩');
      expect(PdfWriter.unvocalised('١٤٤٧هـ'), '١٤٤٧هـ');
      expect(PdfWriter.unvocalised('٪٥٠'), '٪٥٠');
    });

    test('nothing else is touched', () {
      expect(PdfWriter.unvocalised('الملفات التشغيلية'), 'الملفات التشغيلية');
      expect(PdfWriter.unvocalised('Ministry of Religious Affairs'),
          'Ministry of Religious Affairs');
      expect(PdfWriter.unvocalised('لجنة (5 نجوم) — 1447هـ'),
          'لجنة (5 نجوم) — 1447هـ');
    });

    test('a stripped word still shapes and reverses to itself', () {
      // The guard on the strip itself: taking a mark out must not disturb the
      // joining around it, or the cure is worse than the disease.
      const before = 'المقدَّمة';
      final shaped = String.fromCharCodes(
        bidi.logicalToVisual(PdfWriter.unvocalised(before)),
      );
      expect(shaped.runes.length, 'المقدمة'.runes.length);
    });
  });

  group('the words keep their spaces', () {
    test('the gap is wide enough for a final rah to sweep under it', () {
      // A word ending in ر begins, once reversed for drawing, with a final ﺮ
      // whose tail inks 0.149 em to the LEFT of its own origin — inside the gap
      // the package just measured. The font's space is 0.175 em, so at the
      // package's default the pair «صدور القرار» had half a point between them.
      //
      // Asserted as a floor rather than an exact figure: the number was
      // measured against the worst pair on a real sheet, and lowering it is the
      // change that would silently bring the merging back.
      expect(
        PdfWriter.wordSpacing * 0.175,
        greaterThanOrEqualTo(0.149 + 0.29),
        reason: 'the tail would land in the gap again',
      );
    });
  });
}
