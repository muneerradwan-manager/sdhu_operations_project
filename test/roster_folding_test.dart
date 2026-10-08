import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/features/modules/presentation/module_detail_screen.dart';

/// Folding the groups of a large file.
///
/// A group is a قطاع on a file with a tree and a role on one without. Ten of
/// the fifteen types have no tree at all — الطوافة والنقل, الإعاشة المركزية,
/// الطيران المركزي and the rest are a roster and nothing else — so while this
/// governed sectors only, it reached the minority of the files and left the
/// majority as one unbroken wall of faces.
///
/// A file with four groups is one page and should stay one page. توزيع أعضاء
/// مكاتب البعثة على مخيمات منى runs to hundreds across a dozen, and there the
/// roster is not something a reader READS — it is something he scrolls PAST to
/// reach the reports and the duties under it.
///
/// Three inputs, and only one of them is a preference.
void main() {
  group('a small file', () {
    test('is open, because there is nothing to scroll past', () {
      expect(
        groupIsOpen(
          filtering: false,
          foldByDefault: false,
          movedByReader: false,
        ),
        isTrue,
      );
    });

    test('and the reader may still shut a sector', () {
      expect(
        groupIsOpen(
          filtering: false,
          foldByDefault: false,
          movedByReader: true,
        ),
        isFalse,
      );
    });
  });

  group('a large file', () {
    test('starts folded', () {
      expect(
        groupIsOpen(
          filtering: false,
          foldByDefault: true,
          movedByReader: false,
        ),
        isFalse,
      );
    });

    test('and the reader may open the one he wants', () {
      expect(
        groupIsOpen(
          filtering: false,
          foldByDefault: true,
          movedByReader: true,
        ),
        isTrue,
      );
    });
  });

  group('a live filter overrides both', () {
    // The rule, not the preference.
    //
    // A name matching inside a folded sector would be found by the search,
    // counted in "showing 3 of 120" at the top of the page, and then be
    // nowhere on the screen. A search that reports a result it does not show
    // is worse than one that finds nothing at all.
    test('every sector is open while searching, however large the file', () {
      for (final moved in [false, true]) {
        for (final foldByDefault in [false, true]) {
          expect(
            groupIsOpen(
              filtering: true,
              foldByDefault: foldByDefault,
              movedByReader: moved,
            ),
            isTrue,
            reason: 'a match must never be hidden — moved=$moved '
                'foldByDefault=$foldByDefault',
          );
        }
      }
    });
  });

  test('what the reader moved is remembered as an EXCEPTION, not a state', () {
    // The reason this function takes "moved against the default" rather than
    // "is open": the default moves underneath it. A file that crosses the
    // folding threshold because one person was added must not re-open every
    // sector the reader had shut, and one that drops back below it must not
    // shut the ones he had opened.
    //
    // Same reader, same gesture, on either side of the threshold.
    expect(
      groupIsOpen(filtering: false, foldByDefault: false, movedByReader: true),
      isFalse,
      reason: 'he shut it while the file was small',
    );
    expect(
      groupIsOpen(filtering: false, foldByDefault: true, movedByReader: true),
      isTrue,
      reason: 'the same flag now means he opened it, which is what he would '
          'have meant on a page that started folded',
    );
  });
}
