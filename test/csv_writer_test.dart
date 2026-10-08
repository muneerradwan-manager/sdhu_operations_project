import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/features/export/data/csv_writer.dart';
import 'package:sdhu_operations_project/features/export/domain/export_dataset.dart';

ExportTable table(List<String> headers, List<List<String>> rows) =>
    ExportTable(title: 'اختبار', headers: headers, rows: rows);

void main() {
  group('what makes an Arabic CSV open correctly', () {
    test('it starts with a byte-order mark', () {
      final bytes = CsvWriter.write(table(['الاسم'], [
        ['منير']
      ]));

      expect(
        bytes.take(3),
        [0xEF, 0xBB, 0xBF],
        reason: 'without it Excel reads the file in the machine ANSI code page '
            'and every Arabic name arrives as mojibake',
      );
    });

    test('the Arabic survives the round trip', () {
      final bytes = CsvWriter.write(table(['الاسم'], [
        ['منير عبدالله رضوان']
      ]));
      final text = utf8.decode(bytes.skip(3).toList());

      expect(text, contains('منير عبدالله رضوان'));
    });

    test('nothing stands between the mark and the headings', () {
      // This is a regression test with a real file behind it.
      //
      // A `sep=,` line used to sit here, to tell Excel which separator to split
      // on. It is the standard cure for a comma file opening as one column on a
      // machine whose locale uses semicolons — and it CANNOT be used with a
      // byte-order mark: given a `sep=` first line, Excel stops honouring the
      // mark and reads the file in the ANSI code page instead. Every Arabic
      // name came out as mojibake, which is precisely what the mark was added
      // to prevent.
      //
      // Readable text in one column is a ten-second fix. An unreadable file is
      // not a file.
      final bytes = CsvWriter.write(table(['الاسم'], [
        ['منير']
      ]));
      final text = utf8.decode(bytes.skip(3).toList());

      expect(text.startsWith('الاسم'), isTrue);
      expect(
        text,
        isNot(contains('sep=')),
        reason: 'a sep= line makes Excel ignore the BOM and mangle the Arabic',
      );
    });

    test('rows end CRLF', () {
      final bytes = CsvWriter.write(table(['a'], [
        ['b']
      ]));
      final text = utf8.decode(bytes.skip(3).toList());

      expect(text, 'a\r\nb\r\n');
    });
  });

  group('escaping', () {
    test('a comma forces quotes', () {
      expect(CsvWriter.escape('مكة, السعودية'), '"مكة, السعودية"');
    });

    test('a quote is doubled inside quotes', () {
      expect(CsvWriter.escape('قال "نعم"'), '"قال ""نعم"""');
    });

    test('a newline inside a note keeps the row one row', () {
      final bytes = CsvWriter.write(table(['ملاحظة'], [
        ['الغرف ٤٠١\nو٤٠٢ مغلقة']
      ]));
      final text = utf8.decode(bytes.skip(3).toList());

      expect(text, contains('"الغرف ٤٠١\nو٤٠٢ مغلقة"'));
    });

    test('leading or trailing space is preserved rather than eaten', () {
      expect(CsvWriter.escape(' منير '), '" منير "');
    });

    test('plain text is left alone', () {
      expect(CsvWriter.escape('منير'), 'منير');
    });
  });

  group('a spreadsheet must not execute what somebody typed', () {
    // A duty note, a complaint, an external organisation name — all free text,
    // and a cell that opens with any of these four is a FORMULA to Excel.
    test('a leading = is defused', () {
      expect(CsvWriter.escape('=1+1'), "'=1+1");
    });

    test('the other three openers too', () {
      expect(CsvWriter.escape('+SUM(A1)'), "'+SUM(A1)");
      expect(CsvWriter.escape('-2+3'), "'-2+3");
      expect(CsvWriter.escape('@SUM(A1)'), "'@SUM(A1)");
    });

    test('the classic remote-command payload is defused', () {
      const attack = '=cmd|\' /C calc\'!A0';

      final escaped = CsvWriter.escape(attack);

      // Not quoted, and does not need to be: it carries no comma, no double
      // quote and no newline. The apostrophe is the whole defence, and the
      // whole defence is what the cell no longer starts with.
      expect(escaped, "'$attack");
      expect(
        escaped,
        isNot(startsWith('=')),
        reason: 'opening the sheet must not run it',
      );
    });

    test('a number is still a number', () {
      expect(CsvWriter.escape('1447'), '1447');
      expect(CsvWriter.escape('٠٩٩١٢٣٤٥٦٧'), '٠٩٩١٢٣٤٥٦٧');
    });
  });

  test('an export with no rows is still a readable file with its headings', () {
    final bytes = CsvWriter.write(table(['الاسم', 'البريد'], []));
    final text = utf8.decode(bytes.skip(3).toList());

    expect(text, 'الاسم,البريد\r\n');
  });

  test('the whole file decodes as UTF-8 after the mark', () {
    // What the reported bug actually looked like: a valid file that Excel read
    // with the wrong codec. Nothing in Dart can reproduce Excel, so what is
    // asserted here is the half this code owns — that the bytes after the mark
    // are UTF-8 and nothing else, with no preamble of any kind in front of the
    // first heading.
    final bytes = CsvWriter.write(
      table(['الاسم الكامل', 'المهنة'], [
        ['منير عبدالله رضوان', 'مشرف برج'],
      ]),
    );

    expect(bytes.take(3), [0xEF, 0xBB, 0xBF]);
    final text = utf8.decode(bytes.skip(3).toList());
    expect(
      text,
      'الاسم الكامل,المهنة\r\nمنير عبدالله رضوان,مشرف برج\r\n',
    );
  });
}
