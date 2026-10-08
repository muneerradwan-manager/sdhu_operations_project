import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The reference catalog is cached, and a cache has exactly one way to be wrong.
///
/// `fetchReferenceSets` carries every entry of every list and is read by nine
/// call sites, so it is held per process for five minutes. That is safe for the
/// report-type catalog next door, which nobody edits from inside the app. These
/// lists ARE edited from inside the app, on a screen built for nothing else —
/// so every write has to drop the cache, and a write added later that forgets
/// to is the whole failure mode.
///
/// It fails quietly and it fails locally: the person who just typed a hotel is
/// the one person guaranteed to be holding a stale copy, and to them it reads
/// as the save having silently failed. They press save again. Now there are
/// two.
///
/// A lint over the source, not a runtime check — there is no fake Supabase here
/// to write against. It can tell whether every method that writes to
/// `reference_items` also drops the cache, which is the mistake that gets made.
void main() {
  final source = File('lib/features/modules/data/modules_repository.dart');

  late String code;

  setUpAll(() {
    expect(
      source.existsSync(),
      isTrue,
      reason: 'run from the project root — ${source.absolute.path}',
    );
    // Line endings normalised, because the terminator below is a newline and
    // this repository is checked out on Windows: on disk the file ends its
    // lines with CRLF, so `}` is followed by `\r` and every search for `}\n`
    // finds nothing. A test whose correctness depends on the checkout's
    // autocrlf setting is not a test.
    code = source.readAsStringSync().replaceAll('\r\n', '\n');
  });

  /// The body of a method, from its signature to its closing brace.
  ///
  /// The terminator is a brace ALONE on its line — `\n  }\n` — and the newline
  /// at the end is doing real work. Without it this matched `\n  })`, which is
  /// how a named-parameter list closes, so every method taking named arguments
  /// was cut off at its own signature and read as an empty body. Four of the
  /// five checks below passed on nothing; the fifth passed honestly, because
  /// `deleteReferenceItem(String id)` is the one method here with a positional
  /// parameter and no such line to trip over.
  String bodyOf(String signature) {
    final start = code.indexOf(signature);
    expect(
      start,
      isNot(-1),
      reason:
          '$signature is gone from ModulesRepository — if it was renamed, this '
          'test must learn the new name or it guards nothing',
    );
    final end = code.indexOf('\n  }\n', start);
    expect(end, isNot(-1), reason: 'could not find the end of $signature');
    return code.substring(start, end);
  }

  /// Everything that writes rows the cached catalog holds.
  ///
  /// `copyModuleSectors` is in the list although it reads as being about nodes:
  /// sectors have been reference entries since 0095, so importing them writes
  /// into `reference_items` too. That one is exactly the sort of write a future
  /// reader would not think to check, which is why it is named here rather than
  /// left to judgement.
  const writers = [
    'Future<void> addReferenceItem(',
    'Future<void> updateReferenceItem(',
    'Future<void> deleteReferenceItem(',
    'Future<int> copyReferenceItems(',
    'Future<int> copyModuleSectors(',
  ];

  for (final writer in writers) {
    final name = writer.split(' ').last.replaceAll('(', '');
    test('$name drops the cached catalog', () {
      expect(
        bodyOf(writer),
        contains('invalidateReferenceSets()'),
        reason:
            'a write that leaves the cache standing shows the editor a list '
            'without the change they just made — and the natural response to '
            'that is to make it again',
      );
    });
  }

  test('the catalog is still fetched whole, never narrowed by season', () {
    // The standing temptation, and 0040 forbids it in as many words:
    //
    //   > the PICKER offers the entries of this season; the RESOLVER knows all.
    //
    // A tower in a 1448 file points at a 1448 hotel row, and opening that file
    // while 1447 is current must still print the hotel's name. Narrowing this
    // query by season turns every older file into a screen of raw uuids — the
    // failure 0104 had to migrate its way out of — and it does so only for
    // files nobody is looking at today, which is why it would ship.
    //
    // Caching made this MORE tempting, not less: the payload is now visibly the
    // thing being optimised. It is the frequency that was the problem.
    final fetch = bodyOf('Future<List<ReferenceSet>> fetchReferenceSets(');

    expect(
      fetch,
      contains("select('*, reference_items(*)')"),
      reason: 'the resolver needs every entry of every season',
    );
    expect(
      fetch.contains('season_id'),
      isFalse,
      reason:
          'no season filter belongs in this query — it goes in '
          'ReferenceSet.itemsForSeason, which the pickers call and the '
          'resolvers do not',
    );
  });

  test('what is cached is the full catalog, not the filtered view', () {
    // `activeOnly` is a view of the same rows. Caching the two variants apart
    // would double the reads the cache exists to remove and let them disagree
    // — and caching the FILTERED one would be worse than either: a resolver
    // reading an older file needs the entry that was retired last season to
    // still have a name.
    final fetch = bodyOf('Future<List<ReferenceSet>> fetchReferenceSets(');
    final assignment = fetch.indexOf('_setsCache = ');
    final filter = fetch.indexOf('_applyActiveOnly(sets, activeOnly)');

    expect(assignment, isNot(-1), reason: 'nothing is being cached');
    expect(filter, isNot(-1), reason: 'the filter is no longer applied on read');
    expect(
      assignment < filter,
      isTrue,
      reason: 'the unfiltered catalog must be what goes into the cache',
    );
  });
}
