import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/widgets/responsive.dart';

/// One width scale and one card scale, for every page in the app.
///
/// The state this replaces is worth writing down, because it is the state every
/// app drifts into and nothing in a compiler notices. Screens capped themselves
/// at 520, 560, 640, 700, 720, 820, 860, 900, 1100 and 1200 — or at nothing —
/// and asked for cards 150, 200, 220, 300, 320, 340, 360, 380 and 420 wide.
/// Every one of those numbers was defensible on the afternoon it was typed, and
/// together they meant a reader going from القرارات to الموظفون to مهامي watched
/// the page change width three times without changing what it was doing, and
/// counted two cards on one screen and four on the next.
///
/// Nothing about that is a bug in any single screen, which is exactly why it
/// needs a test at the level of all of them.
void main() {
  /// Every Dart file under a feature — the screens, and the widgets they build
  /// their pages out of.
  final screens = Directory('lib/features')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  setUpAll(() {
    expect(
      screens,
      isNotEmpty,
      reason: 'run from the project root — this test reads lib/features',
    );
  });

  group('the card scale', () {
    test('one card width gives one more column at each step, once', () {
      // The claim the whole scale rests on. If these four numbers move, every
      // list in the app re-columns together — which is the point — but somebody
      // should have to mean it.
      const caps = {
        WindowSize.medium: 2,
        WindowSize.expanded: 3,
        WindowSize.large: 4,
        WindowSize.extraLarge: 4,
      };

      caps.forEach((size, expected) {
        expect(
          columnsFor(
            size.contentMaxWidth,
            minTileWidth: CardWidth.list,
            maxColumns: 4,
          ),
          expected,
          reason: '${size.name} stopped giving $expected columns of cards',
        );
      });
    });

    test('a card never comes out narrower than a card', () {
      // The other half: more columns is only an improvement while each one is
      // still wide enough to hold a title, a line and a badge. 320 is the floor
      // that was measured for that on the employee tile.
      for (final size in [
        WindowSize.medium,
        WindowSize.expanded,
        WindowSize.large,
        WindowSize.extraLarge,
      ]) {
        final width = size.contentMaxWidth;
        final columns = columnsFor(
          width,
          minTileWidth: CardWidth.list,
          maxColumns: 4,
        );
        expect(
          cellWidthFor(width, columns, 12),
          greaterThanOrEqualTo(320),
          reason: '${size.name} squeezed its cards below a readable width',
        );
      }
    });

    test('every screen asks for a card size by name, never by number', () {
      // A raw number here is how the ten of them accumulated: each one was a
      // reasonable answer for the screen in front of somebody, and none of them
      // knew about the others.
      final raw = RegExp(r'minTileWidth: (?!CardWidth\.)([^,\n)]+)');
      final offenders = <String>[];

      for (final file in screens) {
        for (final m in raw.allMatches(file.readAsStringSync())) {
          offenders.add('${file.path}: ${m.group(1)}');
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'these asked for a card width in pixels instead of naming one of '
            'CardWidth — see lib/core/widgets/responsive.dart:\n'
            '${offenders.join('\n')}',
      );
    });

    test('a column count is either one or as many as fit', () {
      // `maxColumns: 2` and `: 3` were the same guess as the raw widths, made
      // twice as arbitrarily: they capped a grid at a number that had nothing
      // to do with how much room there was. Either the content is one-per-row
      // — a table, a message, a section of a file — or the width decides.
      final counts = RegExp(r'maxColumns: (\d+)');
      final offenders = <String>[];

      for (final file in screens) {
        for (final m in counts.allMatches(file.readAsStringSync())) {
          final n = int.parse(m.group(1)!);
          if (n != 1 && n != 4) offenders.add('${file.path}: $n');
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'these capped a grid at a count instead of letting the card width '
            'decide:\n${offenders.join('\n')}',
      );
    });
  });

  group('the width scale', () {
    test('a page that is not a list says which kind it is', () {
      // The compiler already refuses a page that passes a number — there is no
      // `maxWidth` on [ResponsivePage] any more. What it cannot catch is a page
      // that names a kind it is not, so all this can check is that the kinds in
      // use are the four that exist.
      final kinds = RegExp(r'PageWidth\.(\w+)');
      final named = <String>{};

      for (final file in screens) {
        for (final m in kinds.allMatches(file.readAsStringSync())) {
          named.add(m.group(1)!);
        }
      }

      expect(
        named.difference(PageWidth.values.map((v) => v.name).toSet()),
        isEmpty,
        reason: 'a page named a width kind that does not exist',
      );
    });

    test('a skeleton is as wide as the page it is standing in', () {
      // The half of the shimmer that was wrong everywhere. The shape was
      // already measured by the same arithmetic and cut into the same columns,
      // and then drawn at the browse width regardless — so a form capped at 640
      // flashed a placeholder 1680 wide and snapped in to a third of it. The
      // promise has to include the width, or the arrival still reads as the
      // page jumping.
      final narrow = RegExp(r'PageWidth\.(form|reading|editor)');
      final offenders = <String>[];

      for (final file in screens) {
        final source = file.readAsStringSync();
        if (!source.contains('SkeletonList(')) continue;
        if (!narrow.hasMatch(source)) continue;

        for (final m in RegExp('SkeletonList\\(').allMatches(source)) {
          final call = source.substring(
            m.end,
            (m.end + 400).clamp(0, source.length),
          );
          if (!call.contains('width: PageWidth.')) {
            offenders.add(file.path);
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'these draw a placeholder at the browse width on a page that is '
            'not a browse page:\n${offenders.toSet().join('\n')}',
      );
    });

    test('a skeleton says how tall the thing it stands for is', () {
      // Left to the default, every placeholder in the app is 76 pixels tall —
      // which describes an employee row and lies about a complaint, an
      // evaluation, an urgent report and a file. The height is the only part of
      // the shape a skeleton cannot work out for itself.
      final offenders = <String>[];

      for (final file in screens) {
        final source = file.readAsStringSync();
        for (final m in RegExp('SkeletonList\\(').allMatches(source)) {
          final call = source.substring(
            m.end,
            (m.end + 400).clamp(0, source.length),
          );
          // Up to the closing paren of this call, roughly: the next `;` ends it.
          final end = call.indexOf(';');
          final body = end == -1 ? call : call.substring(0, end);
          if (!body.contains('height:')) offenders.add(file.path);
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'these promise a 76-pixel row and then deliver something else:\n'
            '${offenders.toSet().join('\n')}',
      );
    });
  });
}
