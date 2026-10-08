import 'dart:io';
import 'dart:typed_data';

import 'package:bidi/bidi.dart' as bidi;
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';

/// The exported PDF is in the app's own typeface, and getting it there took a
/// conversion this test exists to police.
///
/// itfQomra ships as `OTTO` — OpenType with CFF outlines. Flutter renders that
/// happily; the `pdf` package cannot embed it at all, because a PDF font is
/// built from the `glyf` and `loca` tables a CFF file does not have. So a
/// second copy lives in `assets/fonts/pdf/` with its curves converted.
///
/// Two things can go wrong with that copy, and NEITHER RAISES AN ERROR. A file
/// without `glyf` is refused; a file whose Arabic is incomplete produces a
/// document full of blank boxes and saves without complaint. Somebody finds out
/// when the sheet is already with the leadership.
///
/// So the coverage is asserted here, against the same shaping the `pdf` package
/// performs at render time: it takes the Arabic, has `bidi` join and reorder it
/// into presentation forms, and looks each resulting character up in the font.
void main() {
  late TtfParser regular;
  late TtfParser bold;

  setUpAll(() {
    ByteData load(String path) {
      final file = File(path);
      expect(
        file.existsSync(),
        isTrue,
        reason: '$path is missing — the PDF export has no font to draw with',
      );
      return ByteData.sublistView(file.readAsBytesSync());
    }

    regular = TtfParser(load('assets/fonts/pdf/itfQomraArabic-Regular.ttf'));
    bold = TtfParser(load('assets/fonts/pdf/itfQomraArabic-Bold.ttf'));
  });

  /// Text as it actually appears in this app's exports.
  const samples = <String, String>{
    'a full Arabic name': 'منير عبدالله رضوان',
    'a column heading': 'البريد الإلكتروني',
    'a place': 'مخيم منى — القطاع السابع',
    'a duty note': 'الغرف ٤٠١ و٤٠٢ مغلقة',
    'a state': 'قيد التنفيذ',
    'the lam-alef ligature': 'لا إله إلا الله',
    // A letter that does not join forward — و, ر, د — leaves the one after it
    // ISOLATED, which is a different glyph again from the initial and final
    // forms every other sample here exercises. «شورى» ends on an isolated alef
    // maqsura and «دعوى» on the same after a waw.
    'an isolated form after a non-joiner': 'شورى دعوى مأوى',
    // Real names, and they are here because they were reported off a printed
    // sheet: every one of them ends a word on a ي that follows a letter which
    // does not join forward, so every one of them lost that ي. See
    // [_isolatedPairs].
    'a name ending on an isolated yeh': 'هاشم الحموي، محمد هادي الشعال',
    'a job ending on an isolated yeh': 'موظف إداري',
    'taa marbuta and hamza': 'المدينة المنوّرة، مسؤول الرحلة',
    'a season': 'الموسم ١٤٤٧هـ',
    'mixed with Latin and digits': 'Hotel 12 — فندق الأنصار',
    'Arabic-Indic digits': '٠١٢٣٤٥٦٧٨٩',
    'Western digits': '0123456789',
  };

  for (final entry in samples.entries) {
    test('the regular face can draw ${entry.key}', () {
      final missing = _missingFrom(regular, entry.value);

      expect(
        missing,
        isEmpty,
        reason:
            'these would be drawn as blank boxes in every exported PDF, and '
            'nothing would report an error: '
            '${missing.map((c) => '${String.fromCharCode(c)} (U+${c.toRadixString(16).toUpperCase()})').join(', ')}',
      );
    });

    test(
      'the regular face draws ${entry.key} rather than only claiming to',
      () {
        final blank = _blankIn(regular, entry.value);

        expect(blank, isEmpty, reason: _blankReason(blank));
      },
    );
  }

  test('the bold face draws the headings rather than only claiming to', () {
    final blank = <int>{
      for (final sample in samples.values) ..._blankIn(bold, sample),
    };

    expect(blank, isEmpty, reason: _blankReason(blank));
  });

  test('the bold face can draw the headings', () {
    // Only the headings are bold, but a heading is where the column names are
    // and they are the part of the sheet a reader must be able to read.
    final missing = <int>{
      for (final sample in samples.values) ..._missingFrom(bold, sample),
    };

    expect(missing, isEmpty);
  });

  for (final face in ['regular', 'bold']) {
    test('the $face face draws each isolated letter as ITSELF', () {
      final font = face == 'regular' ? regular : bold;
      final wrong = <String>[];

      _isolatedPairs.forEach((isolated, base) {
        final drawn = font.charToGlyphIndexMap[isolated];
        final should = font.charToGlyphIndexMap[base];
        if (drawn == should) return;
        wrong.add(
          '${String.fromCharCode(base)} '
          '(U+${isolated.toRadixString(16).toUpperCase()} → glyph $drawn, '
          'the letter itself is glyph $should)',
        );
      });

      expect(
        wrong,
        isEmpty,
        reason:
            'an isolated letter is drawn from a glyph belonging to some other '
            'letter, or from none at all:\n${wrong.join('\n')}\n'
            'run tool/fill_pdf_font_ligatures.py over assets/fonts/pdf/',
      );
    });
  }

  test('both faces are TrueType — a CFF file cannot be embedded at all', () {
    // TtfParser reaching this point already proves it, since it reads `glyf`.
    // Stated anyway: this is the mistake that would be made by copying the
    // OTF back over the TTF, and it is not obvious that it is a mistake.
    expect(regular.charToGlyphIndexMap, isNotEmpty);
    expect(bold.charToGlyphIndexMap, isNotEmpty);
  });

  test('the two faces agree on what they can draw', () {
    // A bold face missing a letter the regular one has gives a sheet whose
    // headings are broken and whose body is fine, which reads as a layout bug
    // rather than as a font one.
    final regularOnly = regular.charToGlyphIndexMap.keys
        .where((c) => !bold.charToGlyphIndexMap.containsKey(c))
        .toList();

    expect(regularOnly, isEmpty);
  });
}

/// The characters of [text] that the font has no glyph for, AFTER the shaping
/// and reordering the `pdf` package applies to right-to-left text.
///
/// Shaping is the point. `م` on its own is U+0645, but joined in the middle of
/// a word it is drawn from a different glyph in the presentation-forms block,
/// and a font carrying the first without the second renders correct-looking
/// isolated letters and blanks for everything joined.
Set<int> _missingFrom(TtfParser font, String text) {
  final visual = bidi.logicalToVisual(text);
  return {
    for (final code in visual)
      if (!font.charToGlyphIndexMap.containsKey(code) && !_ignorable(code))
        code,
  };
}

/// The characters of [text] whose glyph the font DECLARES and leaves empty.
///
/// The other half of [_missingFrom], and the half that was missing when the
/// first exported roster came back reading «البريد اɑلكتروني».
///
/// A cmap entry is a promise, not a drawing. itfQomra declares the whole
/// presentation-forms block and leaves the five lam-alef ligatures — U+FEF5 to
/// U+FEFC — with no outline at all, because on screen nothing ever asks for
/// them: HarfBuzz joins lam and alef through the font's own init/fina forms and
/// never touches the legacy block. The `pdf` package has no such shaper. It
/// maps straight onto the presentation forms, so it asks for exactly the eight
/// glyphs the font does not have.
///
/// And it does not come out blank, which is why this went unnoticed for so
/// long: an empty glyph has `loca[i] == loca[i+1]`, and `TtfParser.readGlyph`
/// reads from that offset regardless — landing in the middle of whatever glyph
/// comes NEXT and drawing that instead. «لا» printed as a Latin ɑ. A blank
/// would at least have looked like a font problem.
///
/// So the outlines are filled in by `tool/fill_pdf_font_ligatures.py`, and this
/// is what keeps them filled in when somebody re-converts the font.
Set<int> _blankIn(TtfParser font, String text) {
  final visual = bidi.logicalToVisual(text);
  return {
    for (final code in visual)
      if (!_ignorable(code))
        if (font.charToGlyphIndexMap[code] case final glyph?)
          if (glyph < font.glyphSizes.length && font.glyphSizes[glyph] == 0)
            code,
  };
}

String _blankReason(Set<int> blank) =>
    'the font claims these and draws nothing for them, so the PDF prints '
    'whichever glyph happens to sit next in the file: '
    '${blank.map((c) => '${String.fromCharCode(c)} (U+${c.toRadixString(16).toUpperCase()})').join(', ')}'
    '\nrun tool/fill_pdf_font_ligatures.py over assets/fonts/pdf/';

/// Every isolated presentation form, against the letter it is a form OF.
///
/// The third failure mode, and the nastiest of the three, because a font that
/// passes both checks above can still fail this one: the glyph is present, it
/// is drawn, and it is the WRONG LETTER.
///
/// The `pdf` package does not read isolated forms out of a font's cmap at all.
/// It aliases them itself — `basicToIsolatedMappings` in
/// `pdf/lib/src/pdf/font/bidi_utils.dart` — pointing each isolated codepoint at
/// the base letter's glyph. One line of that table is wrong:
///
///     0x064A: 0xFEEF, // ي
///
/// U+FEEF is the isolated ى; the isolated ي is U+FEF1. So ي's glyph was handed
/// to ى — «مجلس الشورى» printed «الشوري», a different word — and U+FEF1 was
/// left pointing at nothing, so a ي standing alone was not drawn at all.
/// «هاشم الحموي» printed «هاشم الحمو» and «موظف إداري» printed «موظف إدار»:
/// a letter of a man's name gone off an official sheet, silently, in every
/// name ending on ي after one of the six letters that do not join forward.
///
/// `tool/fill_pdf_font_ligatures.py` writes the two correct mappings into the
/// font's own cmap, where they overwrite the package's aliases. This is what
/// says they are still there.
const _isolatedPairs = <int, int>{
  0xFE80: 0x0621, // ء
  0xFE81: 0x0622, // آ
  0xFE83: 0x0623, // أ
  0xFE85: 0x0624, // ؤ
  0xFE87: 0x0625, // إ
  0xFE89: 0x0626, // ئ
  0xFE8D: 0x0627, // ا
  0xFE8F: 0x0628, // ب
  0xFE93: 0x0629, // ة
  0xFE95: 0x062A, // ت
  0xFE99: 0x062B, // ث
  0xFE9D: 0x062C, // ج
  0xFEA1: 0x062D, // ح
  0xFEA5: 0x062E, // خ
  0xFEA9: 0x062F, // د
  0xFEAB: 0x0630, // ذ
  0xFEAD: 0x0631, // ر
  0xFEAF: 0x0632, // ز
  0xFEB1: 0x0633, // س
  0xFEB5: 0x0634, // ش
  0xFEB9: 0x0635, // ص
  0xFEBD: 0x0636, // ض
  0xFEC1: 0x0637, // ط
  0xFEC5: 0x0638, // ظ
  0xFEC9: 0x0639, // ع
  0xFECD: 0x063A, // غ
  0xFED1: 0x0641, // ف
  0xFED5: 0x0642, // ق
  0xFED9: 0x0643, // ك
  0xFEDD: 0x0644, // ل
  0xFEE1: 0x0645, // م
  0xFEE5: 0x0646, // ن
  0xFEE9: 0x0647, // ه
  0xFEED: 0x0648, // و
  0xFEEF: 0x0649, // ى
  0xFEF1: 0x064A, // ي
};

/// Characters no font needs a mark for.
bool _ignorable(int code) =>
    code == 0x20 || // space
    code == 0x200B || // zero-width space
    code == 0x200C || // zero-width non-joiner
    code == 0x200D || // zero-width joiner
    (code >= 0x202A && code <= 0x202E); // bidi embedding controls
