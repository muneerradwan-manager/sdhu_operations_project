import 'dart:async';

import '../attachments/attachment.dart';
import '../logging/app_logger.dart';
import '../logging/error_reporting.dart';
import '../utils/network_error.dart';
import 'outbox_entry.dart';
import 'outbox_store.dart';

/// Performs one queued operation. Throwing means it did not happen; returning
/// means it did, and the entry leaves the queue.
typedef OutboxHandler = Future<void> Function(OutboxEntry entry);

/// [Outbox.sendOrQueue], for callers that may run where no queue was installed.
///
/// That is a widget test building one screen on its own, and nothing else in a
/// shipped app — `bootstrap` installs the queue before the first frame. Rather
/// than have every cubit ask whether the app was fully started, the fallback is
/// stated once, here: with no queue, a write is what it was before there was
/// one, and the caller is told it was sent because as far as this run is
/// concerned it either was or it threw.
Future<bool> sendOrQueue({
  required Future<void> Function() send,
  required String kind,
  required Map<String, dynamic> payload,
  String? label,
  List<PendingAttachment> attachments = const [],
}) async {
  if (!Outbox.isInstalled) {
    await send();
    return true;
  }
  return Outbox.instance.sendOrQueue(
    send: send,
    kind: kind,
    payload: payload,
    label: label,
    attachments: attachments,
  );
}

/// The work a person has done that has not reached the server yet.
///
/// The problem this exists for is not a slow network. It is that the network in
/// the Mashaa'ir during the days of Tashreeq goes away for hours, and until now
/// a man who moved a duty to منجز or filed the evening report while it was gone
/// was shown an error and lost what he had written. He is standing in a camp;
/// he will not write it again. The record of the day the whole system is built
/// around was the record most likely to be missing from it.
///
/// So a write is no longer an attempt that succeeds or fails. It is a thing
/// ACCEPTED from the person — kept on his own device, with its photographs —
/// and sent when there is something to send it over. From his side it is done
/// the moment he presses the button, which is the truth: it is done, and the
/// app has taken responsibility for the rest.
///
/// What this deliberately does NOT do is let two people edit the same thing
/// offline and merge it afterwards. Everything queued here is an APPEND — a
/// state set, a report filed, evidence attached — and the last one to arrive
/// wins, which is what would have happened had they both been online. There is
/// no merge because there is nothing being merged.
class Outbox {
  // Assigned in the initializer list rather than through `this._store`, which
  // Dart does not allow for a NAMED parameter — the name would have to be the
  // private one, and `Outbox(_store: …)` is not a thing that can be written.
  Outbox({required OutboxStore store, Stream<void>? reconnects})
    // ignore: prefer_initializing_formals
    : _store = store,
      // ignore: prefer_initializing_formals
      _reconnects = reconnects;

  final OutboxStore _store;
  final Stream<void>? _reconnects;
  StreamSubscription<void>? _reconnectSub;
  Timer? _wakeup;

  /// The app's queue.
  ///
  /// A singleton for the same reason the Supabase client is one: everything
  /// that writes needs to reach it, it holds a file and a timer that must not
  /// exist twice, and threading it through eighteen cubits to their
  /// repositories would be plumbing in service of nothing. Assigned once in
  /// `bootstrap`; [instance] before that is a programming error, not a state to
  /// handle.
  static Outbox? _instance;

  static Outbox get instance {
    final outbox = _instance;
    if (outbox == null) {
      throw StateError('Outbox used before bootstrap installed it');
    }
    return outbox;
  }

  /// Whether there is one yet. For the few call sites that can legitimately run
  /// before the queue exists — a widget test building a screen in isolation.
  static bool get isInstalled => _instance != null;

  static set instance(Outbox outbox) => _instance = outbox;

  final Map<String, OutboxHandler> _handlers = {};
  final List<OutboxEntry> _entries = [];
  final StreamController<List<OutboxEntry>> _changes =
      StreamController<List<OutboxEntry>>.broadcast();

  /// The drain in progress, if there is one. One at a time: two would upload
  /// the same photograph twice and race each other to write the queue file.
  ///
  /// Held as the FUTURE rather than as a flag so that a second caller can wait
  /// for the run already going instead of being told "busy" and returning as if
  /// the work were done. That distinction is invisible in the app — every drain
  /// there is fire-and-forget — and it is the whole difference between a test
  /// that observes the queue emptying and one that observes it mid-flight.
  Future<void>? _draining;

  /// Shut down. Nothing further is sent and nothing further is written.
  ///
  /// It matters that this exists at all: a drain is started and not awaited
  /// from half a dozen places, so without a flag saying stop, work carries on
  /// against a queue whose owner has gone — writing a file whose directory a
  /// test has already removed, or, in the app, holding the store open past the
  /// point anything is listening.
  bool _closed = false;

  /// Set while a drain is running and something asked for another. Sending the
  /// queue is the moment a person is most likely to add to it — he files the
  /// report, then immediately marks the duty done — and that second entry must
  /// not wait for the next trigger.
  bool _drainAgain = false;

  /// How long to wait before trying an entry again, by how many times it has
  /// already failed.
  ///
  /// It climbs steeply and then stops. The early retries are for a signal that
  /// flickered; the later ones are for a phone that has been in a bag for an
  /// hour, and hammering a congested cell every few seconds is one more thing
  /// making it congested.
  static const backoff = [
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 45),
    Duration(minutes: 2),
    Duration(minutes: 5),
    Duration(minutes: 15),
    Duration(minutes: 30),
  ];

  /// After this many failures an entry stops trying and starts waiting for a
  /// person instead.
  ///
  /// Not because the network could not come back, but because by then it is no
  /// longer a network problem and nobody has been told. An entry that retries
  /// forever in silence is indistinguishable, from the outside, from an entry
  /// that was sent.
  static const maxAttempts = 8;

  List<OutboxEntry> get entries => List.unmodifiable(_entries);

  /// What is still on its way. The count a badge shows.
  int get pendingCount => _entries.where((entry) => !entry.isBlocked).length;

  /// What has given up and needs somebody to look at it.
  int get blockedCount => _entries.where((entry) => entry.isBlocked).length;

  Stream<List<OutboxEntry>> get changes => _changes.stream;

  /// Names the operation [kind] refers to. Registered at start-up by the
  /// repositories that own these writes, so that the queue knows how to send
  /// something without knowing anything about what it is.
  void register(String kind, OutboxHandler handler) {
    _handlers[kind] = handler;
  }

  /// Reads what was left over from last time and starts trying to send it.
  Future<void> start() async {
    _entries
      ..clear()
      ..addAll(await _store.load());
    _entries.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // Anything the queue no longer knows about is holding photographs open.
    // Awaited so that a sweep is not still deleting directories underneath the
    // first drain — and so that "started" covers this too.
    await _store.sweep(_entries);

    if (_entries.isNotEmpty) {
      AppLogger.info('outbox', '${_entries.length} waiting from last time');
    }
    _emit();

    // `onError` as well, and not because the stream this is given in the app
    // promises to fail — it promises not to. It is because a stream is an
    // argument here, and an error on one that nobody handles does not stay in
    // the queue: it escapes to the framework and is reported as a crash. The
    // queue watching the network must never be the reason the app looks broken.
    _reconnectSub ??= _reconnects?.listen(
      (_) => unawaited(onReconnect()),
      onError: (Object error) {
        AppLogger.info('outbox', 'reconnect stream failed — $error');
      },
      cancelOnError: false,
    );

    // Awaited, so that "started" means the first attempt has been made rather
    // than merely begun. `bootstrap` does not wait on start() at all, so this
    // costs the opening screen nothing and gives every other caller — a test,
    // a future resume handler — a point it can rely on.
    await drain();
  }

  /// Accepts a piece of work from a person, keeping its attachments.
  ///
  /// Returns once it is safely on disk — NOT once it has been sent. That is the
  /// whole point, and every caller must treat it that way: the screen closes,
  /// the confirmation is shown, and the sending is no longer the person's
  /// problem.
  Future<OutboxEntry> add({
    required String kind,
    required Map<String, dynamic> payload,
    String? label,
    List<PendingAttachment> attachments = const [],
  }) async {
    assert(
      _handlers.containsKey(kind),
      'no outbox handler registered for "$kind" — it would never be sent',
    );

    final id = '${DateTime.now().microsecondsSinceEpoch}';
    final files = [
      for (final attachment in attachments)
        await _store.keep(attachment, entryId: id),
    ];

    final entry = OutboxEntry(
      id: id,
      kind: kind,
      payload: payload,
      label: label,
      files: files,
      createdAt: DateTime.now(),
    );

    _entries.add(entry);
    await _persist();
    unawaited(drain());
    return entry;
  }

  /// The device has a network again. Everything waiting goes now.
  ///
  /// The backoff is DROPPED rather than waited out, and that is the point of
  /// having this at all instead of just calling [drain]. The delay on an entry
  /// exists because the last attempt failed on a dead radio; a live one is new
  /// information, and it makes the delay wrong. Without this, a man who walks
  /// out of a dead spot into a working one is made to stand there for the
  /// remaining twenty-five minutes of a backoff that is answering a question
  /// nobody is asking any more.
  ///
  /// A blocked entry is left alone: it is not waiting on a network.
  Future<void> onReconnect() async {
    AppLogger.info('outbox', 'network back — draining');
    var moved = false;
    for (var i = 0; i < _entries.length; i++) {
      final entry = _entries[i];
      if (entry.isBlocked || entry.nextAttemptAt == null) continue;
      _entries[i] = entry.copyWith(clearNextAttempt: true);
      moved = true;
    }
    if (moved) await _persist();
    await drain();
  }

  /// Tries to do the thing now, and keeps it for later only if the NETWORK was
  /// what stopped it. Returns true when it went through immediately.
  ///
  /// This, rather than queuing everything unconditionally, is what the writing
  /// screens use — and the difference matters both ways.
  ///
  /// Online is still the ordinary case: most of this app is used in an office
  /// in Makkah on a working connection, and there a refusal should be SEEN.
  /// "You are no longer a member of this file", "the period is closed", "that
  /// duty was deleted" — a queue that swallowed those and reported success
  /// would be lying to the person, and he would find out at the end of the
  /// season that the work he thought he had filed was never filed.
  ///
  /// The network failing is the one case where there is nothing to tell him,
  /// because nothing has been decided yet. That is the case this keeps.
  ///
  /// [send] may be replayed in full afterwards; see [OutboxFile] for why that
  /// is safe for the operations queued here.
  Future<bool> sendOrQueue({
    required Future<void> Function() send,
    required String kind,
    required Map<String, dynamic> payload,
    String? label,
    List<PendingAttachment> attachments = const [],
  }) async {
    try {
      await send();
      return true;
    } catch (error) {
      if (!looksLikeNetworkFailure(error)) rethrow;
      AppLogger.info('outbox', 'no network — keeping $kind');
      await add(
        kind: kind,
        payload: payload,
        label: label,
        attachments: attachments,
      );
      return false;
    }
  }

  /// Sends everything that is due, oldest first.
  ///
  /// Order matters and is not merely tidy: a duty moved to قيد التنفيذ and then
  /// to منجز must arrive in that order or the board ends up showing the earlier
  /// of the two.
  Future<void> drain() {
    if (_closed) return Future<void>.value();
    final running = _draining;
    if (running != null) {
      // It will make another pass before it finishes, so waiting on it is
      // waiting for this caller's entries too.
      _drainAgain = true;
      return running;
    }
    return _draining = _drainLoop();
  }

  Future<void> _drainLoop() async {
    try {
      bool offline;
      do {
        _drainAgain = false;
        offline = await _drainOnce();
        // Stopping the PASS on a dead network would be pointless if the loop
        // then started another one: whatever a second pass reached would fail
        // in exactly the same way, one round trip later. The network coming
        // back is what starts the next drain, and until it does there is
        // nothing here worth spending a radio on.
      } while (_drainAgain && !offline);
    } finally {
      _draining = null;
      _scheduleWakeup();
    }
  }

  /// Returns whether it stopped because the network is gone.
  Future<bool> _drainOnce() async {
    final now = DateTime.now();
    final due = _entries.where((entry) => entry.isDue(now)).toList();

    for (final entry in due) {
      // It may have been discarded while an earlier one was in flight.
      if (!_entries.any((held) => held.id == entry.id)) continue;

      final handler = _handlers[entry.kind];
      if (handler == null) {
        // An entry written by a build that knew an operation this one does
        // not. Blocked rather than dropped: it is somebody's work, and the
        // person should be the one who decides to throw it away.
        await _block(entry, 'unknown operation "${entry.kind}"');
        continue;
      }

      _update(entry.copyWith(status: OutboxStatus.sending));
      try {
        await handler(entry);
        await _remove(entry.id);
        AppLogger.info('outbox', 'sent ${entry.kind} (${entry.label ?? entry.id})');
      } catch (error, stack) {
        await _recordFailure(entry, error, stack);
        // A network failure means the network is gone, and the entries behind
        // this one are about to fail the same way. Stop, and let the reconnect
        // or the timer bring the whole queue back at once.
        if (looksLikeNetworkFailure(error)) return true;
      }
    }
    return false;
  }

  Future<void> _recordFailure(OutboxEntry entry, Object error, StackTrace stack) async {
    final attempts = entry.attempts + 1;
    final network = looksLikeNetworkFailure(error);

    if (!network) {
      // The server answered, and what it said was no. Reported: a refusal that
      // happens to one person is his own business, but the same refusal on
      // forty phones at once is a permission or a migration that went out
      // wrong, and nobody would otherwise find out until the season ended.
      CrashReporting.record(
        error,
        stack,
        reason: 'outbox refused: ${entry.kind}',
      );
    }

    if (attempts >= maxAttempts) {
      await _block(entry, error.toString(), attempts: attempts);
      return;
    }

    final wait = backoff[(attempts - 1).clamp(0, backoff.length - 1)];
    AppLogger.info(
      'outbox',
      '${entry.kind} failed ($attempts/$maxAttempts) — retrying in '
      '${wait.inSeconds}s',
    );
    _update(
      entry.copyWith(
        status: OutboxStatus.waiting,
        attempts: attempts,
        nextAttemptAt: DateTime.now().add(wait),
        lastError: error.toString(),
      ),
    );
    await _persist();
  }

  Future<void> _block(OutboxEntry entry, String reason, {int? attempts}) async {
    AppLogger.error('outbox', '${entry.kind} blocked — $reason', null, null);
    _update(
      entry.copyWith(
        status: OutboxStatus.blocked,
        attempts: attempts ?? entry.attempts,
        lastError: reason,
      ),
    );
    await _persist();
  }

  /// Puts a blocked entry back in the queue, at a person's word.
  Future<void> retry(String id) async {
    final entry = _entries.firstWhereOrNull((held) => held.id == id);
    if (entry == null) return;
    _update(
      entry.copyWith(
        status: OutboxStatus.waiting,
        attempts: 0,
        clearNextAttempt: true,
        clearError: true,
      ),
    );
    await _persist();
    await drain();
  }

  /// Throws a piece of work away, at a person's word and nobody else's.
  Future<void> discard(String id) async {
    await _remove(id);
  }

  /// The next time anything in the queue becomes due.
  ///
  /// A timer rather than polling: most of the time there is nothing waiting and
  /// nothing to wake up for, and a phone in a bag in Mina is a phone whose
  /// battery has to last until the evening.
  void _scheduleWakeup() {
    _wakeup?.cancel();
    _wakeup = null;

    final now = DateTime.now();
    DateTime? soonest;
    for (final entry in _entries) {
      if (entry.isBlocked) continue;
      final at = entry.nextAttemptAt ?? now;
      if (soonest == null || at.isBefore(soonest)) soonest = at;
    }
    if (soonest == null) return;

    final wait = soonest.difference(now);
    _wakeup = Timer(wait.isNegative ? Duration.zero : wait, () {
      unawaited(drain());
    });
  }

  void _update(OutboxEntry entry) {
    final index = _entries.indexWhere((held) => held.id == entry.id);
    if (index < 0) return;
    _entries[index] = entry;
    _emit();
  }

  Future<void> _remove(String id) async {
    _entries.removeWhere((entry) => entry.id == id);
    await _persist();
    await _store.discardFiles(id);
  }

  Future<void> _persist() async {
    if (_closed) return;
    // Never persisted as `sending`: nothing is in flight once the process is
    // gone, and an entry restored in that state would sit unpicked forever.
    await _store.save([
      for (final entry in _entries)
        entry.status == OutboxStatus.sending
            ? entry.copyWith(status: OutboxStatus.waiting)
            : entry,
    ]);
    _emit();
  }

  void _emit() {
    if (_changes.isClosed) return;
    _changes.add(List.unmodifiable(_entries));
  }

  /// Stops the queue. What is on disk stays on disk; the next [start] picks it
  /// up. Used by tests, and by anything that has to tear the app down cleanly.
  Future<void> close() async {
    _closed = true;
    _wakeup?.cancel();
    _wakeup = null;
    await _reconnectSub?.cancel();
    // Waits out whatever was already writing. A drain is started and not
    // awaited from several places, so at any moment there may be a rename in
    // progress that nobody is holding a future for.
    await _store.settled();
    await _changes.close();
  }
}

extension _FirstOrNull<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final item in this) {
      if (test(item)) return item;
    }
    return null;
  }
}
