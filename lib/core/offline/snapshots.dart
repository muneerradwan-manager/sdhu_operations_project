import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../logging/app_logger.dart';
import '../utils/network_error.dart';

/// The other half of working without a signal.
///
/// [Outbox] solved writing: what a man does in the field is kept and sent when
/// the network returns. Reading was never solved at all, and it is the half he
/// needs more often. Standing in Mina with no bars he cannot open the roster of
/// his own file, cannot find a colleague's telephone number, cannot see what is
/// on his own list — not because the answer is unknown, but because it was on
/// the screen forty minutes ago and nothing kept it.
///
/// So: the LAST GOOD ANSWER to a handful of reads, on disk, returned when the
/// network fails and never otherwise.
///
/// Three properties, and each of them is a decision:
///
///   * **Raw rows, not objects.** What is stored is exactly what the server
///     sent, and it is read back through the same `fromMap` the live path uses.
///     No `toJson` on twenty domain models, no second parser to drift from the
///     first, and a stored shape that changes only when the query does.
///
///   * **Only on a network failure.** Not on a refusal, not on a 500, not on a
///     permission that was revoked this morning. Those are answers, and showing
///     yesterday's roster to somebody who was removed from a file is not
///     resilience — it is the app arguing with the server about what is true.
///
///   * **Per person, and dropped at sign-out.** The keys carry the user id, and
///     [clear] runs when a session ends. A shared phone in an operations room
///     is normal, and one man reading the previous man's staff directory —
///     names, telephone numbers — out of a cache is not a stale read, it is a
///     leak.
///
/// Deliberately JSON files rather than a database, for the reasons [OutboxStore]
/// gives one file over: what is kept is small, read whole in a millisecond,
/// inspectable when something goes wrong in the field, and carries no schema to
/// migrate at the start of a season.
class Snapshots {
  Snapshots(this.root);

  /// The installed store, or null where there is nowhere to keep one.
  ///
  /// Null on the web, exactly as the outbox is: `path_provider` has no
  /// implementation there. Every call site reaches for this with `?.`, so a
  /// platform without a disk simply has no saved copies and every read is live
  /// — which is the correct behaviour for a browser and needs no flag.
  static Snapshots? instance;

  static Future<Snapshots> open() async {
    final support = await getApplicationSupportDirectory();
    final root = Directory('${support.path}/snapshots');
    await root.create(recursive: true);
    return Snapshots(root);
  }

  final Directory root;

  File _file(String key) => File('${root.path}/${_safe(key)}.json');

  /// A key reduced to something that is certainly a filename.
  ///
  /// The keys carry user ids and query names — `tasks.mine.<uuid>` — which are
  /// already safe. This is here for the key somebody adds later that is not.
  static String _safe(String key) =>
      key.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');

  /// Keeps [rows] as the last good answer for [key].
  ///
  /// Never throws and never awaits anything the caller depends on: a snapshot
  /// that could not be written is a screen that will be blank in the field
  /// later, which is bad, and an exception here is a screen that is blank NOW,
  /// which is worse.
  Future<void> put(String key, Object? rows) async {
    try {
      await _file(key).writeAsString(
        jsonEncode({'saved_at': DateTime.now().toIso8601String(), 'rows': rows}),
        flush: true,
      );
    } catch (error, stack) {
      AppLogger.error('snapshot', 'could not keep $key', error, stack);
    }
  }

  /// The last good answer for [key], or null if there is none.
  Future<Snapshot?> get(String key) async {
    try {
      final file = _file(key);
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString()) as Map;
      final savedAt = DateTime.tryParse(decoded['saved_at'] as String? ?? '');
      if (savedAt == null) return null;
      return Snapshot(rows: decoded['rows'], savedAt: savedAt);
    } catch (error, stack) {
      // A half-written file from a process killed mid-save, or a shape an older
      // build wrote. Same answer as the outbox gives: treat it as absent. The
      // saved copy failing must never be the reason a screen fails.
      AppLogger.error('snapshot', '$key unreadable — treating as absent', error, stack);
      return null;
    }
  }

  /// Drops everything. Called when a session ends — see the class comment.
  Future<void> clear() async {
    try {
      if (!await root.exists()) return;
      await for (final entity in root.list()) {
        if (entity is File) await entity.delete();
      }
    } catch (error, stack) {
      AppLogger.error('snapshot', 'could not clear', error, stack);
    }
  }
}

/// A saved answer, and when it was true.
class Snapshot {
  const Snapshot({required this.rows, required this.savedAt});

  final Object? rows;
  final DateTime savedAt;
}

/// A read, and whether it came from the network or from disk.
///
/// [savedAt] is null for a live answer and carries a time for a saved one, so
/// a screen can say WHEN rather than merely that something is old. "A saved
/// copy" invites the reader to guess; "saved at 14:32" lets them decide whether
/// it is good enough for what they are about to do — which, standing at a gate
/// in Mina, is a decision only they can make.
class Cached<T> {
  const Cached(this.data, {this.savedAt});

  final T data;
  final DateTime? savedAt;

  bool get isStale => savedAt != null;
}

/// Fetches [key] live, keeps the answer, and falls back to the kept one when
/// the network is the thing that failed.
///
/// [fetch] returns the RAW rows and [parse] turns them into whatever the caller
/// wanted; both paths run the same [parse], which is what keeps a restored
/// screen identical to a live one.
///
/// Anything that is not a network failure is rethrown untouched. See the class
/// comment for why that line is drawn there and not around all errors.
Future<Cached<T>> readWithSnapshot<T>({
  required String key,
  required Future<Object?> Function() fetch,
  required T Function(Object? rows) parse,
}) async {
  try {
    final rows = await fetch();
    // Unawaited on purpose: nothing on screen is waiting for the copy to reach
    // the disk, and a slow write should not delay a live answer.
    final kept = Snapshots.instance?.put(key, rows);
    if (kept != null) unawaited(kept);
    return Cached(parse(rows));
  } catch (error) {
    if (!looksLikeNetworkFailure(error)) rethrow;
    final saved = await Snapshots.instance?.get(key);
    if (saved == null) rethrow;
    AppLogger.info('snapshot', 'no network — $key served from ${saved.savedAt}');
    return Cached(parse(saved.rows), savedAt: saved.savedAt);
  }
}
