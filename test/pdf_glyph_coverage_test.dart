/// A character the PDF font cannot draw does not fail. It is silently absent.
///
/// The `pdf` package parses the typeface itself and looks each codepoint up in
/// the font's `cmap`. One that is not there produces no glyph, no exception and
/// no log line: the character is simply not on the page, and the text around it
/// closes up as though it had never been written. «القطاع الخامس ← بركة اليقين»
/// arrives as two names run together, and the file looks finished.
///
/// itfQomraArabic maps 303 codepoints. That is enough for Arabic and for the
/// ASCII punctuation beside it, and it is NOT enough for the typographic marks
/// somebody reaches for because they look right in an editor — … • « » ← ‹ ›
/// are each one keystroke away and none of them is in the font.
///
/// So this reads the coverage out of the font and the symbols out of the code,
/// and puts them against each other. Reading a printed file is the only other
/// way to catch this, and it is the slowest one there is.
library;


import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

const _regularFont = 'assets/fonts/pdf/itfQomraArabic-Regular.ttf';
const _boldFont = 'assets/fonts/pdf/itfQomraArabic-Bold.ttf';

/// The files whose strings are WRITTEN INTO a document.
///
/// Not all of `features/export`: a label in `export_screen.dart` or an
/// [ExportChoice] in `export_catalog.dart` is drawn by Flutter, in the UI
/// typeface, and Flutter falls back to another font for a glyph it lacks. The
/// PDF does not fall back. Only the writers and the record builders below put
/// their own characters on a page.
const _writers = <String>[
  'lib/features/export/data/pdf_writer.dart',
  'lib/features/export/data/csv_writer.dart',
  'lib/features/export/data/export_sections.dart',
  'lib/features/export/data/module_export.dart',
  'lib/features/export/data/decision_export.dart',
  'lib/features/export/data/export_values.dart',
  'lib/features/export/data/export_runner.dart',
];

/// The Arabic combining marks, which `PdfText._stripped` removes before a line
/// is laid out — see `pdf_writer.dart`. They appear in source strings and never
/// reach a glyph lookup, so their coverage is not a question this asks.
bool _stripped(int cp) => (cp >= 0x064B && cp <= 0x0670);

/// Every codepoint a TrueType `cmap` maps, from subtable formats 4 and 12.
Set<int> _coverage(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: '$path is missing');
  final bytes = ByteData.sublistView(Uint8List.fromList(file.readAsBytesSync()));

  int? cmap;
  final numTables = bytes.getUint16(4);
  for (var i = 0; i < numTables; i++) {
    final record = 12 + 16 * i;
    final tag = String.fromCharCodes(
      List<int>.generate(4, (j) => bytes.getUint8(record + j)),
    );
    if (tag == 'cmap') cmap = bytes.getUint32(record + 8);
  }
  expect(cmap, isNotNull, reason: '$path has no cmap table');

  final covered = <int>{};
  final subtables = bytes.getUint16(cmap! + 2);
  for (var i = 0; i < subtables; i++) {
    final start = cmap + bytes.getUint32(cmap + 4 + 8 * i + 4);
    switch (bytes.getUint16(start)) {
      case 4:
        final segments = bytes.getUint16(start + 6) ~/ 2;
        for (var s = 0; s < segments; s++) {
          final end = bytes.getUint16(start + 14 + 2 * s);
          // The final segment is the 0xFFFF terminator, not coverage.
          if (end == 0xFFFF) continue;
          final first = bytes.getUint16(start + 16 + 2 * segments + 2 * s);
          for (var cp = first; cp <= end; cp++) {
            covered.add(cp);
          }
        }
      case 12:
        final groups = bytes.getUint32(start + 12);
        for (var g = 0; g < groups; g++) {
          final at = start + 16 + 12 * g;
          final first = bytes.getUint32(at);
          final end = bytes.getUint32(at + 4);
          for (var cp = first; cp <= end; cp++) {
            covered.add(cp);
          }
        }
    }
  }
  return covered;
}

/// Characters of every quoted literal in [path], ignoring comment lines — a
/// dash in a sentence explaining the code is not one the exporter will draw.
Map<int, int> _literals(String path) {
  final quoted = RegExp("'([^'\\n]*)'|\"([^\"\\n]*)\"");
  final found = <int, int>{};
  final lines = File(path).readAsLinesSync();

  for (var i = 0; i < lines.length; i++) {
    if (lines[i].trimLeft().startsWith('//')) continue;
    for (final match in quoted.allMatches(lines[i])) {
      for (final cp in ((match.group(1) ?? '') + (match.group(2) ?? '')).runes) {
        found.putIfAbsent(cp, () => i + 1);
      }
    }
  }
  return found;
}

String _describe(int cp) =>
    'U+${cp.toRadixString(16).toUpperCase().padLeft(4, '0')} '
    '${String.fromCharCode(cp)}';

void main() {
  test('both PDF fonts map every symbol the writers put on a page', () {
    final regular = _coverage(_regularFont);
    final bold = _coverage(_boldFont);

    final missing = <String>[];
    for (final path in _writers) {
      expect(File(path).existsSync(), isTrue, reason: '$path has moved');
      _literals(path).forEach((cp, line) {
        if (cp <= 0x7F || _stripped(cp)) return;
        if (regular.contains(cp) && bold.contains(cp)) return;
        missing.add('${_describe(cp)} at $path:$line');
      });
    }

    expect(
      missing,
      isEmpty,
      reason:
          'Absent from one of the PDF fonts, so it will be drawn as nothing:\n'
          '${missing.join('\n')}',
    );
  });

  test('the marks that are NOT in the font are the ones expected to be out', () {
    // Guards the guard. If this ever fails the font has been replaced, and the
    // list above — and the choice of '...' over '…' anywhere it matters — is
    // worth re-reading rather than trusting.
    final regular = _coverage(_regularFont);
    // Verified against the file: ellipsis, leftwards arrow, bullet and
    // middle dot are out. The angle quotes and curly quotes ARE in, which is
    // why the list is read from the font rather than guessed at.
    for (final cp in [0x2026, 0x2190, 0x2022, 0x00B7]) {
      expect(
        regular.contains(cp),
        isFalse,
        reason: '${_describe(cp)} is now mapped',
      );
    }
    for (final cp in [0x002E, 0x2014, 0x2013, 0x00AB, 0x00BB, 0x2039, 0x203A]) {
      expect(
        regular.contains(cp),
        isTrue,
        reason: '${_describe(cp)} is no longer mapped',
      );
    }
  });
}
