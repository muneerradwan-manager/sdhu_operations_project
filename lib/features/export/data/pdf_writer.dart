import 'dart:math' as math;
import 'dart:typed_data';

import 'package:bidi/bidi.dart' as bidi;
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../domain/export_dataset.dart';
import 'export_values.dart';

/// Turns a table into a printable document that reads right to left.
///
/// The font is the whole difficulty, and it is worth stating why there is a
/// second copy of it in `assets/fonts/pdf/`.
///
/// The app's own itfQomra ships as `OTTO` — OpenType with CFF outlines. Flutter
/// renders that happily; the `pdf` package cannot embed it at all, because a
/// PDF font is built out of the `glyf` and `loca` tables that a CFF file does
/// not have. So the same typeface is kept a second time with its curves
/// converted to the quadratic form TrueType uses. It is the same design to
/// well inside a printed dot; it is not a different font, and the exported
/// sheet is in the app's own hand.
///
/// That copy is also PATCHED, by `tool/fill_pdf_font_ligatures.py`, and this is
/// the part to remember when it is ever rebuilt. The typeface declares the
/// eight lam-alef presentation forms and draws none of them: on screen nothing
/// ever asks — HarfBuzz joins lam and alef through the font's own init/fina
/// forms — and this package asks for nothing else. The script fills them in
/// from those same two forms. Without it every «لا», «الإلكتروني» and
/// «الميلاد» in an exported sheet prints with a Latin letter in the middle of
/// it, because an empty glyph is read from the offset of the one stored after
/// it. `test/pdf_font_test.dart` fails if the patch is ever lost.
///
/// Shaping and ordering are the package's, not ours: given a right-to-left
/// [pw.Directionality] and a font carrying the Arabic presentation forms, it
/// joins the letters and lays the line out itself. What we owe it is a font
/// that HAS those forms, and columns wide enough that it never has to break a
/// word — see [_columnWidths], because its shaper runs once, before the line
/// breaker, and a word cut afterwards comes out backwards.
class PdfWriter {
  const PdfWriter._();

  static pw.Font? _regular;
  static pw.Font? _bold;
  static ByteData? _regularBytes;
  static ByteData? _boldBytes;

  /// Loaded once. A font is a megabyte of parsed tables and an export screen
  /// can be used several times in a sitting.
  ///
  /// The bytes are kept beside the built fonts because the column measuring in
  /// [_columnWidths] needs a [PdfFont] of its own — a `pw.Font` only becomes
  /// one inside a build, and the page's width has to be settled before there is
  /// a page to build.
  static Future<void> _loadFonts() async {
    if (_regular != null) return;
    _regularBytes = await rootBundle.load(
      'assets/fonts/pdf/itfQomraArabic-Regular.ttf',
    );
    _boldBytes = await rootBundle.load(
      'assets/fonts/pdf/itfQomraArabic-Bold.ttf',
    );
    _regular = pw.Font.ttf(_regularBytes!);
    _bold = pw.Font.ttf(_boldBytes!);
  }

  static const _headerSize = 9.0;
  static const _cellSize = 8.5;

  /// How much of the font's own space each gap between words gets.
  ///
  /// **This is not a taste setting. Without it Arabic words run together.**
  ///
  /// The package draws each word as its own positioned run and advances by
  /// `word.advanceWidth + space.advanceWidth * wordSpacing` — there is no space
  /// GLYPH in the output at all, and nothing in that sum knows what the next
  /// word's ink will do. itfQomra's space advances 0.175 em, and an Arabic word
  /// whose last letter is a ر begins — once the line is reversed for drawing —
  /// with a final ﺮ whose tail inks **0.149 em to the LEFT of its own origin**.
  /// So the tail is laid down inside the gap that was just measured, and at 8.5
  /// points «صدور القرار» came out with half a point between the two: not a
  /// tight sheet, a WRONG one, because the reader sees «صدورالقرار», a word
  /// that does not exist.
  ///
  /// Measured rather than chosen. The worst pair on the page it was found in is
  /// «عشر يوما», and its ink gap runs:
  ///
  ///     1.0 → 0.0 pt   1.8 → 0.53 pt   2.2 → 1.13 pt
  ///     2.6 → 1.72 pt  3.0 → 2.32 pt
  ///
  /// An ordinary space at this size is about 2 points, so 2.6 is where the
  /// WORST pair stops touching. It leaves the easy pairs looser than they need
  /// to be — the spread across a line is 1.7 to 6.1 — and that is the price of
  /// one constant standing in for a per-word measurement the package will not
  /// make. A loose line is read; a merged word is misread.
  static const _wordSpacing = 2.6;

  /// Read by `test/pdf_text_test.dart`, which holds the floor under it.
  static const wordSpacing = _wordSpacing;

  /// The Arabic short vowels and tanween, and nothing else.
  ///
  /// [_stripped] takes these out of everything this file prints. See there for
  /// why that is the lesser loss.
  ///
  /// Two pieces, not one span: U+064B…U+065F carries the marks, and U+0670
  /// the superscript alef. Everything BETWEEN them must be left alone —
  /// U+0660…U+0669 are the Arabic-Indic digits ٠١٢٣٤٥٦٧٨٩, and U+066A…U+066F
  /// the percent sign and the separators. A sheet quietly missing its numbers
  /// would be a far worse failure than the one this fixes.
  static final _diacritics = RegExp(r'[ً-ٰٟ]');

  /// Text with its vocalisation removed.
  ///
  /// **The marks are not dropped for tidiness — they are dropped because this
  /// package cannot place them, and misplaced they destroy the word.**
  ///
  /// A combining mark has no advance, and the package lays the line out by
  /// REVERSING the shaped string: the mark therefore arrives BEFORE the letter
  /// it belongs to, and its own bearing — cut for a mark that follows its base
  /// — carries it a whole glyph further left. So it lands on the letter before,
  /// or in the gap between two words. In the file this was found in, «مُفعَّل»
  /// printed as something a reader takes for «مفطل», and «تمهيداً لاقتراح»
  /// printed as «تمهيدالاقتراح» with the tanween sitting in the space it had
  /// just eaten.
  ///
  /// Which makes the choice one-sided. Vocalised-and-corrupt is not a richer
  /// rendering than unvocalised-and-correct; it is a wrong word. Arabic is
  /// written without the marks everywhere but a Qur'an and a schoolbook, and
  /// the sheet is now written that way too.
  ///
  /// The tatweel (U+0640) is deliberately NOT in the range: it is a letter's
  /// own extension, not a mark, and «قـرار» is spelt with one on purpose.
  static String _stripped(String value) => value.replaceAll(_diacritics, '');

  /// The same, for anything outside this file that prints Arabic through
  /// [arabicTheme]. Public because the reason is not local to the export.
  static String unvocalised(String value) => _stripped(value);

  /// The horizontal padding inside a cell, on each side, plus the rule.
  static const _cellInset = 4.0 * 2 + 1;

  /// A column never narrower than this, however short its contents — a column
  /// of «ذكر» still needs a heading over it.
  static const _minColumn = 34.0;

  /// …and never wider. The cap is what a long unbroken Latin run — an address,
  /// a UUID — is allowed to claim before it is left to wrap. Those break
  /// mid-token and read perfectly well; the Arabic words this whole measurement
  /// exists for are far below it.
  static const _maxColumn = 150.0;

  /// How much of the table is measured. Every row of a four-thousand-name
  /// roster would be forty thousand string measurements for an answer the first
  /// few hundred already give: a column's widest word is a property of the KIND
  /// of thing in it, not of how many there are.
  static const _rowsSampled = 300;

  /// Where the sheet stops growing sideways. Past this the columns are left to
  /// wrap rather than the page becoming a scroll nothing can print.
  static const _maxPageWidth = 2400.0;

  static final _whitespace = RegExp(r'\s+');

  /// What each column needs to never break a word in half.
  ///
  /// This is the measurement that keeps the sheet readable, and it is worth
  /// saying exactly what goes wrong without it. The `pdf` package lays Arabic
  /// out by converting it to the Unicode presentation forms and REVERSING it,
  /// once, before the line breaker ever sees it. So when a word will not fit
  /// its column the breaker cuts a string it no longer understands: «المدينة»
  /// in a 44-point column came out as «دينة» on the first line and «الم» on the
  /// second — the two halves in the wrong order, and neither of them a word.
  /// Latin survives the same treatment, which is why an over-narrow column
  /// looks like a layout choice in English and like corruption in Arabic.
  ///
  /// A break at a SPACE is fine — «البعثة الإدارية» stacks in the right order —
  /// so the fix is not to stop wrapping. It is to make sure no single word ever
  /// has to be broken, which means measuring the widest word in each column and
  /// letting the page grow to hold them.
  ///
  /// Measured against the shaped text rather than the stored text: an Arabic
  /// letter is a different glyph, of a different width, joined than it is
  /// alone, and measuring «م» to lay out «ـمـ» is measuring the wrong thing.
  static List<double>? _columnWidths(ExportTable table) {
    if (_regularBytes == null || _boldBytes == null) return null;
    try {
      // A document that is never saved, existing only to give the two fonts
      // somewhere to be parsed into so their metrics can be read.
      final probe = PdfDocument();
      final regular = PdfTtfFont(probe, _regularBytes!);
      final bold = PdfTtfFont(probe, _boldBytes!);

      final sampled = math.min(table.rows.length, _rowsSampled);
      return [
        for (var c = 0; c < table.columnCount; c++)
          () {
            var need = c < table.headers.length
                ? _widestWord(bold, table.headers[c], _headerSize)
                : 0.0;
            for (var r = 0; r < sampled; r++) {
              final row = table.rows[r];
              if (c >= row.length) continue;
              final width = _widestWord(regular, row[c], _cellSize);
              if (width > need) need = width;
            }
            return (need + _cellInset).clamp(_minColumn, _maxColumn);
          }(),
      ];
    } catch (_) {
      // A sheet laid out by the package's own guess is worth having; no sheet
      // at all because a measurement threw is not.
      return null;
    }
  }

  /// The same table with its columns turned round, so that the first one lands
  /// on the right.
  ///
  /// [pw.Table] has no notion of direction at all — it lays its cells out left
  /// to right whatever the page around them is doing, and the `tableDirection`
  /// the helper offers reaches only the TEXT inside each cell. So a sheet whose
  /// every word read right to left had its COLUMNS running the other way: the
  /// employees dataset begins with «الاسم الكامل» and ends with «المعرّف», and
  /// an Arabic reader opening the sheet met the identifier first and had to
  /// travel the width of the page to reach the name.
  ///
  /// Reversed here rather than in the catalogue, because the catalogue's order
  /// is not wrong — the CSV, which is opened in a spreadsheet that handles
  /// right-to-left itself, wants exactly the order it has. This is the PDF's
  /// own business.
  ///
  /// A row shorter than the headers is padded before it is turned, never after:
  /// reversing a short row would slide every value in it one column across, and
  /// a name under the heading «المهنة» on an official sheet is worse than a
  /// blank cell by a long way.
  static ExportTable _rightToLeft(ExportTable table) {
    final columns = table.columnCount;
    // Every string the sheet prints passes through here, which is why the
    // vocalisation is taken off at this point rather than at each `pw.Text`:
    // one place, and the column measuring below then measures what is drawn.
    String plain(String value) => _stripped(value);
    return ExportTable(
      title: plain(table.title),
      caption: table.caption == null ? null : plain(table.caption!),
      opensRecord: table.opensRecord,
      // A heading-less block stays heading-less: an empty list turned round is
      // still empty, and padding it out here would put a row of blank cells
      // above every «البيان / القيمة» block in a whole-record export.
      headers: [
        if (table.headers.isNotEmpty)
          for (var i = columns - 1; i >= 0; i--)
            i < table.headers.length ? plain(table.headers[i]) : '',
      ],
      rows: [
        for (final row in table.rows)
          [
            for (var i = columns - 1; i >= 0; i--)
              i < row.length ? plain(row[i]) : '',
          ],
      ],
    );
  }

  /// The width of the longest single word in [text], drawn at [size].
  static double _widestWord(PdfFont font, String text, double size) {
    var widest = 0.0;
    for (final word in text.split(_whitespace)) {
      if (word.isEmpty) continue;
      final shaped = String.fromCharCodes(bidi.logicalToVisual(word));
      final width = font.stringMetrics(shaped).width * size;
      if (width > widest) widest = width;
    }
    return widest;
  }

  /// A theme that can draw Arabic, for any other page this app prints.
  ///
  /// Shared rather than copied. The conversion in `assets/fonts/pdf/` is the
  /// only reason ANY document here can render Arabic at all, and a second
  /// screen that quietly used the package's default font would print a page of
  /// empty boxes — which looks like a bug in the content rather than a missing
  /// font, and is how somebody ends up "fixing" the wrong thing.
  static Future<pw.ThemeData> arabicTheme() async {
    await _loadFonts();
    return _spaced(pw.ThemeData.withFont(base: _regular!, bold: _bold!));
  }

  /// The same theme with [_wordSpacing] on every style it carries.
  ///
  /// Folded into the THEME rather than left to each call site, because the
  /// merging it prevents is a property of this font and this package and not of
  /// any one page — a second document that set its own styles and forgot would
  /// print «صدورالقرار» and nobody would know why. The export overrides these
  /// styles anyway, and carries the same constant explicitly.
  static pw.ThemeData _spaced(pw.ThemeData theme) => theme.copyWith(
    defaultTextStyle: theme.defaultTextStyle.copyWith(
      wordSpacing: _wordSpacing,
    ),
    paragraphStyle: theme.paragraphStyle.copyWith(wordSpacing: _wordSpacing),
    bulletStyle: theme.bulletStyle.copyWith(wordSpacing: _wordSpacing),
    tableHeader: theme.tableHeader.copyWith(wordSpacing: _wordSpacing),
    tableCell: theme.tableCell.copyWith(wordSpacing: _wordSpacing),
    header0: theme.header0.copyWith(wordSpacing: _wordSpacing),
    header1: theme.header1.copyWith(wordSpacing: _wordSpacing),
    header2: theme.header2.copyWith(wordSpacing: _wordSpacing),
    header3: theme.header3.copyWith(wordSpacing: _wordSpacing),
    header4: theme.header4.copyWith(wordSpacing: _wordSpacing),
    header5: theme.header5.copyWith(wordSpacing: _wordSpacing),
  );

  /// The letterhead, in both languages at once.
  ///
  /// Not in the ARB, and deliberately. Everything else on this sheet is written
  /// in the reader's language; this is not addressed to the reader at all. It is
  /// the issuing body naming itself, and an official paper names itself the same
  /// way on every copy — the Arabic side stays Arabic when the app is in
  /// English, and the English side stays English when it is in Arabic, because
  /// the sheet leaves the app and is read by people who never opened it.
  ///
  /// The first line of each side is the state, the second the ministry, the
  /// third this directorate — largest to smallest, the way a seal is read.
  static const _letterheadAr = [
    'الجمهورية العربية السورية',
    'وزارة الأوقاف',
    'إدارة الحـج والعمـرة',
  ];

  static const _letterheadEn = [
    'Syrian Arab Republic',
    'Ministry of Religious Affairs',
    'Directorate of Hajj and Umrah',
  ];

  static pw.MemoryImage? _logo;

  /// Loaded beside the fonts and forgiven if it is not there.
  ///
  /// A missing mark costs the sheet its emblem; it must not cost it the sheet.
  /// The two name blocks stand on their own and the header simply closes over
  /// the gap.
  static Future<void> _loadLogo() async {
    if (_logo != null) return;
    try {
      final data = await rootBundle.load('assets/images/sduh_logo.png');
      _logo = pw.MemoryImage(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
    } catch (_) {
      _logo = null;
    }
  }

  static Future<Uint8List> write(
    ExportTable table, {
    required String subtitle,
    required String pageLabel,
  }) => writeAll([table], subtitle: subtitle, pageLabel: pageLabel);

  /// Several blocks in one document, which is what a whole-record export is.
  ///
  /// The letterhead, the title and the page numbering are the document's and
  /// are printed once; each block gets its caption and its own table under it.
  /// The page is as wide as the WIDEST block needs — a document whose paper
  /// changed width halfway through is not a document — and the narrow blocks
  /// simply share the extra out in their own ratio, exactly as a narrow export
  /// on A4 always has.
  static Future<Uint8List> writeAll(
    List<ExportTable> tables, {
    required String subtitle,
    required String pageLabel,
  }) async {
    await _loadFonts();
    await _loadLogo();

    final theme = _spaced(pw.ThemeData.withFont(base: _regular!, bold: _bold!));
    final document = pw.Document(theme: theme);

    final sheets = [for (final table in tables) _rightToLeft(table)];
    final title = sheets.isEmpty ? '' : sheets.first.title;
    final note = _stripped(subtitle);
    final page = _stripped(pageLabel);

    // Landscape, because these are wide things: a roster with a name, a trade,
    // two telephone numbers and an email does not fit a portrait page without
    // becoming unreadable, and an unreadable sheet is the same as no sheet.
    //
    // And wider than landscape when the columns ask for it. A4 was a fixed
    // ceiling before, so an eighteen-column roster divided 794 points between
    // eighteen headings and gave each of them forty-four — narrower than the
    // word «المدينة», which was then cut in half and stacked backwards. See
    // [_columnWidths]. The paper grows instead: the common export of five or
    // six columns is exactly the A4 landscape it always was, and the wide one
    // becomes a wide sheet rather than a broken one.
    const margin = 24.0;
    final widths = [for (final sheet in sheets) _columnWidths(sheet)];
    var wanted = 0.0;
    for (final measured in widths) {
      if (measured == null) continue;
      final total =
          measured.fold(0.0, (sum, width) => sum + width) + margin * 2;
      if (total > wanted) wanted = total;
    }
    final pageWidth = math.max(
      PdfPageFormat.a4.landscape.width,
      math.min(wanted, _maxPageWidth),
    );

    final empty = sheets.every((sheet) => sheet.isEmpty);

    document.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat(
            pageWidth,
            PdfPageFormat.a4.landscape.height,
            marginLeft: margin,
            marginRight: margin,
            marginTop: 28,
            marginBottom: 28,
          ),
          theme: theme,
          textDirection: pw.TextDirection.rtl,
        ),
        header: (context) => _header(title, note, context),
        footer: (context) => _footer(context, page),
        build: (context) => [
          if (empty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 40),
              child: pw.Text(
                note,
                style: const pw.TextStyle(
                  fontSize: 11,
                  color: PdfColors.grey600,
                ),
              ),
            )
          else
            for (var i = 0; i < sheets.length; i++)
              ..._block(sheets[i], widths[i], isFirst: i == 0),
        ],
      ),
    );

    return document.save();
  }

  /// One block of the document: its caption, and the table under it.
  ///
  /// Returned as a list rather than wrapped in a [pw.Column] because this goes
  /// into a [pw.MultiPage], and a column is an atom to it — a forty-tower
  /// roster inside one would be laid out as a single widget taller than the
  /// page and dropped. Loose children page-break where they should.
  static List<pw.Widget> _block(
    ExportTable sheet,
    List<double>? widths, {
    required bool isFirst,
  }) {
    final caption = sheet.caption;
    return [
      if (caption != null && caption.isNotEmpty) ...[
        if (!isFirst) pw.SizedBox(height: sheet.opensRecord ? 16 : 10),
        // The record's own name is set heavier and ruled off, so that a file of
        // forty operational files reads as forty documents rather than as two
        // hundred captions of equal weight.
        pw.Text(
          caption,
          style: pw.TextStyle(
            fontSize: sheet.opensRecord ? 12 : 10,
            fontWeight: pw.FontWeight.bold,
            wordSpacing: _wordSpacing,
            color: sheet.opensRecord
                ? const PdfColor.fromInt(0xFF016D5D)
                : PdfColors.grey800,
          ),
        ),
        if (sheet.opensRecord)
          pw.Divider(height: 6, color: const PdfColor.fromInt(0xFF016D5D)),
        pw.SizedBox(height: 4),
      ],
      if (sheet.isEmpty)
        pw.SizedBox(height: 2)
      else
        pw.TableHelper.fromTextArray(
          headers: sheet.headers.isEmpty ? null : sheet.headers,
          // Without headers the helper takes the first DATA row for one, which
          // would print the first line of every «البيان / القيمة» block in
          // white on green and then lose it from the block.
          headerCount: sheet.headers.isEmpty ? 0 : 1,
          data: sheet.rows,
          // Proportional to what each column needs rather than fixed at it,
          // so the row still fills the sheet: where the page was widened to
          // the measured total every column lands on its own figure, and
          // where it was held at the A4 floor — a narrow export, three
          // columns — the spare width is shared out in the same ratio
          // instead of leaving a third of the paper blank.
          columnWidths: widths == null
              ? null
              : {
                  for (var i = 0; i < widths.length; i++)
                    i: pw.FlexColumnWidth(widths[i]),
                },
          border: pw.TableBorder.all(color: PdfColors.grey400, width: .4),
          headerStyle: pw.TextStyle(
            fontSize: _headerSize,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.white,
            wordSpacing: _wordSpacing,
          ),
          headerDecoration: const pw.BoxDecoration(
            color: PdfColor.fromInt(0xFF016D5D),
          ),
          cellStyle: pw.TextStyle(
            fontSize: _cellSize,
            wordSpacing: _wordSpacing,
          ),
          // Alternating rows: forty names in one block is a block a reader
          // loses his line in.
          oddRowDecoration: const pw.BoxDecoration(
            color: PdfColor.fromInt(0xFFF3F6F5),
          ),
          cellAlignment: pw.Alignment.centerRight,
          headerAlignment: pw.Alignment.centerRight,
          cellPadding: const pw.EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 3,
          ),
          headerPadding: const pw.EdgeInsets.symmetric(
            horizontal: 4,
            vertical: 5,
          ),
        ),
    ];
  }

  static pw.Widget _header(String title, String subtitle, pw.Context context) {
    // Only on the first page. Repeating a letterhead and a title above every
    // page of a forty-page roster wastes the lines that the columns need — and
    // the footer already carries the page number and the moment, which is what
    // a loose sheet from the middle of the file needs to be placed.
    if (context.pageNumber > 1) return pw.SizedBox();
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _letterhead(),
          pw.SizedBox(height: 8),
          pw.Divider(height: 1, color: PdfColors.grey400),
          pw.SizedBox(height: 8),
          // The title and what made it, on one line: the sheet's own name at
          // the start of it and the provenance trailing off at the far end,
          // which is where an eye reading the table below is not looking.
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Expanded(
                child: pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Text(
                subtitle,
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                  wordSpacing: _wordSpacing,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Divider(height: 1, color: PdfColors.grey400),
        ],
      ),
    );
  }

  /// Who issued this sheet: the state in Arabic on one side, in English on the
  /// other, and the emblem between them.
  ///
  /// The Arabic block is FIRST in the row and therefore on the right, without
  /// anybody naming a side — the page is laid out right to left, so the first
  /// child is the one the reader meets first. The English block carries a
  /// left-to-right [pw.Directionality] of its own, which is what makes it stack
  /// against the left edge and stops «Ministry of Religious Affairs» from being
  /// reordered by a paragraph direction it does not belong to.
  ///
  /// Both blocks are [pw.Expanded] and equal, so the emblem between them sits
  /// on the centre line of the page rather than wherever the longer name leaves
  /// it — which is the difference between a letterhead and a row of three
  /// things.
  static pw.Widget _letterhead() {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(child: _names(_letterheadAr, pw.TextDirection.rtl)),
        if (_logo case final logo?)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12),
            child: pw.Image(logo, height: 48),
          ),
        pw.Expanded(child: _names(_letterheadEn, pw.TextDirection.ltr)),
      ],
    );
  }

  /// One side of the letterhead: three lines, the first of them the state's own
  /// name and set heaviest, the two under it stepping down to this directorate.
  static pw.Widget _names(List<String> lines, pw.TextDirection direction) {
    return pw.Directionality(
      textDirection: direction,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          for (var i = 0; i < lines.length; i++) ...[
            if (i > 0) pw.SizedBox(height: 2),
            pw.Text(
              lines[i],
              style: pw.TextStyle(
                fontSize: i == 0 ? 10 : 9,
                fontWeight: i == 0 ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: i == 0 ? PdfColors.black : PdfColors.grey800,
                // Only where the words are Arabic. The English side has no
                // overhanging finals to compensate for, and widening its spaces
                // would just look loose.
                wordSpacing: direction == pw.TextDirection.rtl
                    ? _wordSpacing
                    : 1,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _footer(pw.Context context, String pageLabel) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 6),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          ExportValues.moment(DateTime.now()),
          style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
        ),
        pw.Text(
          '$pageLabel ${context.pageNumber} / ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
        ),
      ],
    ),
  );
}
