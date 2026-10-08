import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:sdhu_operations_project/core/offline/snapshots.dart';

/// Reading with no signal, and the one line that decides whether it is honest.
void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('snapshots_test');
    Snapshots.instance = Snapshots(temp);
  });

  tearDown(() async {
    Snapshots.instance = null;
    // Best effort, and the failure it swallows is Windows-specific and real:
    // the write under test is deliberately NOT awaited, so a `put` can still
    // hold its file open when the test ends — and Windows refuses to delete a
    // directory containing an open handle (`errno 32`). That surfaced as this
    // file passing alone and failing about two runs in three inside the full
    // suite, reported against whichever test happened to be running.
    //
    // A scratch directory the operating system declined to remove says nothing
    // about the code, and systemTemp is the operating system's to sweep.
    try {
      if (temp.existsSync()) await temp.delete(recursive: true);
    } on FileSystemException {
      // Left for the OS.
    }
  });

  /// A failure that reads like the network, in one of the several shapes the
  /// layers below actually produce. See `network_error.dart`.
  Object networkDown() => const SocketException('Failed host lookup');

  /// Retries [read] until it answers with something, or gives up.
  ///
  /// For the one thing here that happens off the caller's timeline. Returns
  /// null on timeout rather than throwing, so the failure is reported by the
  /// expectation that asked — with its own reason — instead of by a helper.
  Future<T?> eventually<T>(Future<T?> Function() read) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (DateTime.now().isBefore(deadline)) {
      final value = await read();
      if (value != null) return value;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    return null;
  }

  group('the fallback', () {
    test('a live read is served live, and kept', () async {
      final read = await readWithSnapshot(
        key: 'k',
        fetch: () async => [
          {'id': 1},
        ],
        parse: (rows) => (rows as List).length,
      );

      expect(read.data, 1);
      expect(read.savedAt, isNull, reason: 'a live read is not a saved copy');
      expect(read.isStale, isFalse);

      // Polled rather than slept past, and the distinction is the design under
      // test: the write is deliberately NOT awaited, so that a slow disk cannot
      // delay a live answer. A single `Duration.zero` yield passed this file on
      // its own and failed inside the full suite, where the disk is contended —
      // which was the test guessing at a duration the code promises nothing
      // about. This waits for the fact instead.
      expect(await eventually(() => Snapshots.instance!.get('k')), isNotNull);
    });

    test('a network failure is served from the kept answer, with its time', () async {
      await Snapshots.instance!.put('k', [
        {'id': 1},
        {'id': 2},
      ]);

      final read = await readWithSnapshot(
        key: 'k',
        fetch: () async => throw networkDown(),
        parse: (rows) => (rows as List).length,
      );

      expect(read.data, 2);
      expect(read.isStale, isTrue);
      expect(read.savedAt, isNotNull);
    });

    test('the same parse runs on both paths', () async {
      // What makes a restored screen identical to a live one rather than
      // merely similar. Stored raw, read back through the caller's own parser.
      await Snapshots.instance!.put('k', [
        {'name': 'أحمد'},
      ]);

      final restored = await readWithSnapshot(
        key: 'k',
        fetch: () async => throw networkDown(),
        parse: (rows) => [
          for (final r in rows as List) (r as Map)['name'] as String,
        ],
      );

      expect(restored.data, ['أحمد']);
    });
  });

  group('what is NOT a reason to show an old answer', () {
    // The line this whole design rests on. A refusal, a 500, a permission
    // revoked this morning — those are ANSWERS. Serving yesterday's roster to
    // somebody who was removed from a file at dawn is not resilience; it is the
    // app arguing with the server about what is true, and winning.
    test('a refusal is rethrown even when a copy exists', () async {
      await Snapshots.instance!.put('k', [
        {'id': 1},
      ]);

      expect(
        () => readWithSnapshot(
          key: 'k',
          fetch: () async => throw Exception('permission denied'),
          parse: (rows) => (rows as List).length,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('a network failure with no copy is rethrown too', () async {
      expect(
        () => readWithSnapshot(
          key: 'nothing-kept',
          fetch: () async => throw networkDown(),
          parse: (rows) => (rows as List).length,
        ),
        throwsA(isA<SocketException>()),
      );
    });
  });

  group('the store itself', () {
    test('an absent key is null, not an error', () async {
      expect(await Snapshots.instance!.get('never-written'), isNull);
    });

    test('a half-written file reads as absent rather than throwing', () async {
      // A process killed mid-save, or a shape an older build wrote. The saved
      // copy failing must never be the reason a screen fails.
      await File('${temp.path}/broken.json').writeAsString('{"rows": [1,2');
      expect(await Snapshots.instance!.get('broken'), isNull);
    });

    test('a file with no timestamp reads as absent', () async {
      // Without a time there is nothing honest to put on the banner, so there
      // is nothing worth serving.
      await File('${temp.path}/undated.json').writeAsString(jsonEncode({'rows': []}));
      expect(await Snapshots.instance!.get('undated'), isNull);
    });

    test('clear drops everything — a shared handset must not carry it over', () async {
      await Snapshots.instance!.put('a', [1]);
      await Snapshots.instance!.put('b', [2]);

      await Snapshots.instance!.clear();

      expect(await Snapshots.instance!.get('a'), isNull);
      expect(await Snapshots.instance!.get('b'), isNull);
    });

    test('a key that is not a filename still works', () async {
      await Snapshots.instance!.put('tasks/mine:me', [1]);
      expect(await Snapshots.instance!.get('tasks/mine:me'), isNotNull);
    });
  });

  test('with no store installed, every read is live', () async {
    // The web, where `path_provider` has no directory to offer. Nothing is
    // kept, nothing is served, and no call site has to know which platform it
    // is on.
    Snapshots.instance = null;

    final read = await readWithSnapshot(
      key: 'k',
      fetch: () async => [1],
      parse: (rows) => (rows as List).length,
    );
    expect(read.data, 1);
    expect(read.isStale, isFalse);

    await expectLater(
      () => readWithSnapshot(
        key: 'k',
        fetch: () async => throw networkDown(),
        parse: (rows) => (rows as List).length,
      ),
      throwsA(isA<SocketException>()),
    );
  });
}
