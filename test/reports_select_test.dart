import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A document must be fetched WHOLE, and the reason is not tidiness.
///
/// `report_blocks` was missing from the detail select from 0069 until 0103, and
/// it hid perfectly: the only type that carries blocks is `general`, and
/// `general` had zero documents until the three meal shapes were converted into
/// it. The moment there was a written document it read as a blank page.
///
/// The blank page was the lesser half. Both screens push
/// `ReportEditorScreen(existing: …)` with exactly what they fetched, and the
/// editor never refetches — while `save_report` deletes every block and
/// re-inserts the ones it is handed. A written document opened and saved would
/// have had its whole content deleted, silently, by somebody who came to
/// correct its title.
///
/// A string lint, because the failure is a missing string. It cannot check that
/// PostgREST returns the rows; it can check that we asked.
void main() {
  late String source;

  setUpAll(() {
    source = File(
      'lib/features/reports/data/reports_repository.dart',
    ).readAsStringSync();
  });

  test('the detail select asks for everything a document is made of', () {
    // The one-line body of the select, wherever it sits in the file.
    final detail = RegExp(
      r"'\$_columns,([^']*)'",
      dotAll: true,
    ).firstMatch(source)?.group(1);

    expect(
      detail,
      isNotNull,
      reason: 'the select has been reshaped and this lint no longer sees it',
    );

    for (final embed in const [
      'report_rows(*)',
      'report_blocks(*)',
      'report_attachments(*)',
    ]) {
      expect(
        detail,
        contains(embed),
        reason: '$embed is not fetched — a document read without it is a '
            'document the editor will then save WITHOUT it',
      );
    }
  });

  test('the list select does NOT carry the heavy parts', () {
    // The other direction, and it matters for the same reason in reverse: the
    // list draws a card per document and never renders a block, a row or an
    // attachment. Fetching them would pull every table in the season down a
    // phone connection to draw forty titles.
    final list = RegExp(
      r'_listColumns\s*=\s*.{3}(.*?).{3};',
      dotAll: true,
    ).firstMatch(source)?.group(1);

    expect(list, isNotNull);
    for (final embed in const [
      'report_rows',
      'report_blocks',
      'report_attachments',
      // `data` is the header jsonb and can carry paragraphs.
      'data',
    ]) {
      expect(
        list,
        isNot(contains(embed)),
        reason: '$embed is in the LIST projection, which never draws it',
      );
    }
  });

  test('both selects carry what tells a قرار from a تعميم', () {
    // The badge is drawn in the list and the segmented button in the editor,
    // and both read the same column. A projection that forgot it would show
    // every document as a قرار — the enum's fallback — which is worse than
    // showing nothing, because it reads as an answer.
    for (final column in const ['kind', 'subtitle']) {
      expect(
        RegExp('_columns\\s*=\\s*.{3}[^;]*$column').hasMatch(source),
        isTrue,
        reason: '$column is missing from a projection',
      );
    }
  });
}
