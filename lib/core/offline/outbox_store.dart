import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../attachments/attachment.dart';
import '../logging/app_logger.dart';
import '../supabase/storage_key.dart';
import 'outbox_entry.dart';

/// Where the queue lives between one run of the app and the next.
///
/// A queue that only exists in memory solves the wrong half of the problem. The
/// network in the Mashaa'ir does not merely drop for a minute — the phone is
/// carried for hours, is put away, runs out of battery, is restarted. What was
/// written must still be there afterwards or the queue has only moved the
/// moment of loss, not prevented it.
///
/// Deliberately a JSON file rather than a database. What is kept here is tens
/// of entries, never thousands: it is what one person did since the last time
/// he had a signal. A file is read whole in a millisecond, is inspectable when
/// something goes wrong in the field, and adds no schema to migrate at the
/// start of a season.
class OutboxStore {
  OutboxStore(this.root);

  /// The real one, under the app's own support directory — not the cache
  /// directory, which the system is entitled to empty whenever it likes, and
  /// emptying this would silently discard a day's work.
  static Future<OutboxStore> open() async {
    final support = await getApplicationSupportDirectory();
    final root = Directory('${support.path}/outbox');
    await root.create(recursive: true);
    return OutboxStore(root);
  }

  final Directory root;

  File get _index => File('${root.path}/queue.json');
  Directory get _files => Directory('${root.path}/files');

  Future<List<OutboxEntry>> load() => _serial(_read);

  Future<List<OutboxEntry>> _read() async {
    try {
      if (!await _index.exists()) return [];
      final decoded = jsonDecode(await _index.readAsString());
      return [
        for (final row in (decoded as List?) ?? const [])
          OutboxEntry.fromJson((row as Map).cast<String, dynamic>()),
      ];
    } catch (error, stack) {
      // A half-written file from a process killed mid-save, or a shape an
      // older build wrote. Losing the queue is bad; failing to start the app
      // because of the queue is worse, and it is the queue's own job not to
      // stand between a person and the screen he opened the app for.
      AppLogger.error('outbox', 'queue unreadable — starting empty', error, stack);
      return [];
    }
  }

  /// Everything this store does to the index file, in the order it was asked
  /// for. Reads are in the chain as well as writes, and both halves matter.
  ///
  /// Two writes overlap easily: a person files a report (one save) while the
  /// drain his last entry started is finishing another. Both were writing a
  /// temporary file and renaming it onto the same target.
  ///
  /// A read overlapping a write is the subtler one, and on Windows it is the
  /// one that actually failed: `readAsString` holds the file open, and a rename
  /// onto a file that something else has open is refused outright — the index
  /// lost, not to a crash, but to the queue reading its own book while writing
  /// in it.
  Future<void> _fileOps = Future<void>.value();

  /// Puts [work] at the end of the queue of things done to the index file.
  Future<T> _serial<T>(Future<T> Function() work) {
    final done = _fileOps.then((_) => work());
    // The chain is kept alive past a failure on purpose: one operation that
    // could not be completed must not poison every one after it.
    _fileOps = done.then((_) {}, onError: (_) {});
    return done;
  }

  /// Writes through a temporary file and renames over the old one.
  ///
  /// A rename is atomic where a write is not. Saving in place means that a
  /// phone which dies mid-write leaves a truncated file, and the entry being
  /// saved is very often the one written seconds before the battery gave out.
  Future<void> save(List<OutboxEntry> entries) => _serial(() => _write(entries));

  /// Completes when everything asked of this store has finished.
  ///
  /// Wanted at shutdown. Several of the calls into here are started and not
  /// awaited — a drain persisting after the screen that caused it has gone —
  /// and closing while one is mid-rename leaves the index in the one state the
  /// temporary-file dance exists to prevent.
  Future<void> settled() => _serial(() async {});

  Future<void> _write(List<OutboxEntry> entries) async {
    // Named per write rather than reusing one path: a `.tmp` left behind by a
    // process that died, or by a second store somebody points at this same
    // directory, must not be something this write can trip over.
    final temp = File('${_index.path}.${DateTime.now().microsecondsSinceEpoch}.tmp');
    await temp.writeAsString(
      jsonEncode([for (final entry in entries) entry.toJson()]),
      flush: true,
    );
    await temp.rename(_index.path);
  }

  /// Takes a private copy of an attachment, and returns the queue's handle on
  /// it. See [OutboxFile] for why a copy rather than the original path.
  Future<OutboxFile> keep(PendingAttachment attachment, {required String entryId}) async {
    final dir = Directory('${_files.path}/$entryId');
    await dir.create(recursive: true);

    // The stored name is ASCII for the same reason storage keys are — the
    // Arabic name is kept on the entry, which is what gets uploaded and what
    // the reader sees.
    var target = '${dir.path}/${storageKey(attachment.name, fallback: 'file')}';
    if (await File(target).exists()) {
      target = '${dir.path}/${DateTime.now().microsecondsSinceEpoch}_'
          '${storageKey(attachment.name, fallback: 'file')}';
    }
    final copy = await attachment.file.copy(target);

    return OutboxFile(
      path: copy.path,
      name: attachment.name,
      kind: attachment.kind,
      mimeType: attachment.mimeType,
    );
  }

  /// Throws away the copies an entry was holding, once it no longer needs them.
  ///
  /// Never allowed to fail loudly: the entry has already been sent by the time
  /// this runs, and a file that would not delete is a few hundred kilobytes,
  /// not a reason to put a finished piece of work back in the queue.
  Future<void> discardFiles(String entryId) => _serial(() => _discard(entryId));

  Future<void> _discard(String entryId) async {
    try {
      final dir = Directory('${_files.path}/$entryId');
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (error) {
      AppLogger.error('outbox', 'could not clear files for $entryId', error, null);
    }
  }

  /// Deletes file directories belonging to no entry in [entries].
  ///
  /// The copies are the only thing here big enough to matter, and every way an
  /// entry can leave the queue without its own tidy-up — an old build, a
  /// corrupt index read as empty, an interrupted delete — leaves them behind.
  /// Run once at start-up, when the queue is known.
  Future<void> sweep(List<OutboxEntry> entries) => _serial(() => _sweep(entries));

  Future<void> _sweep(List<OutboxEntry> entries) async {
    try {
      if (!await _files.exists()) return;
      final live = {for (final entry in entries) entry.id};
      await for (final child in _files.list()) {
        if (child is! Directory) continue;
        final name = child.path.split(Platform.pathSeparator).last;
        if (live.contains(name)) continue;
        await child.delete(recursive: true);
        AppLogger.debug('outbox', 'swept orphaned files for $name');
      }
    } catch (error) {
      AppLogger.error('outbox', 'sweep failed', error, null);
    }
  }
}
