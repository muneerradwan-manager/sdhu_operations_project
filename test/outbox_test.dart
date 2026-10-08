import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/attachments/attachment.dart';
import 'package:sdhu_operations_project/core/offline/outbox.dart';
import 'package:sdhu_operations_project/core/offline/outbox_entry.dart';
import 'package:sdhu_operations_project/core/offline/outbox_store.dart';

/// The queue exists for one situation: a man in a camp in Mina, on a network
/// that has gone away for hours, filing the report the whole season is read
/// back from. Everything below is a way that situation can go wrong.
void main() {
  late Directory temp;
  late OutboxStore store;
  final open = <Outbox>[];

  Outbox build({Stream<void>? reconnects}) {
    final outbox = Outbox(store: store, reconnects: reconnects);
    open.add(outbox);
    return outbox;
  }

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('outbox_test');
    store = OutboxStore(temp);
  });

  tearDown(() async {
    // Closed before the directory goes: a drain is started and not awaited from
    // several places, and one still running against a directory that has been
    // removed fails in a way that lands on whichever test happens to be next.
    for (final outbox in open) {
      await outbox.close();
    }
    open.clear();
    // Lets an in-flight write finish rather than racing its file handle.
    await Future<void>.delayed(const Duration(milliseconds: 10));
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  /// What a dead connection actually looks like coming out of the stack.
  Object networkDown() =>
      const SocketException('Failed host lookup: example.supabase.co');

  /// Waits for [condition], rather than for a fixed number of milliseconds.
  ///
  /// The one thing here that cannot be awaited directly is a reconnect: the
  /// stream listener starts the work and hands back nothing to hold. A fixed
  /// delay in its place passes on an idle machine and fails on a busy one,
  /// which is a test that reports the load on the machine rather than the
  /// behaviour of the queue.
  Future<void> waitUntil(bool Function() condition) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!condition()) {
      if (DateTime.now().isAfter(deadline)) fail('condition never became true');
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  group('what is kept and what is not', () {
    test('the network failing keeps the work', () async {
      final outbox = build();
      outbox.register('thing', (_) async {});

      final sent = await outbox.sendOrQueue(
        send: () async => throw networkDown(),
        kind: 'thing',
        payload: {'a': 1},
      );

      expect(sent, isFalse);
      expect(outbox.pendingCount, 1);
    });

    test('the server refusing does NOT keep the work — it is thrown on', () async {
      final outbox = build();
      outbox.register('thing', (_) async {});

      // A refusal is news the person needs. Swallowing it into a queue would
      // tell him his work was filed and let him find out in a month that it
      // was not.
      await expectLater(
        outbox.sendOrQueue(
          send: () async => throw StateError('new row violates row-level security'),
          kind: 'thing',
          payload: const {},
        ),
        throwsStateError,
      );
      expect(outbox.pendingCount, 0);
    });

    test('a write that goes through is never queued at all', () async {
      final outbox = build();
      outbox.register('thing', (_) async {});

      final sent = await outbox.sendOrQueue(
        send: () async {},
        kind: 'thing',
        payload: const {},
      );

      expect(sent, isTrue);
      expect(outbox.entries, isEmpty);
    });
  });

  group('sending what was kept', () {
    test('it goes out, with its payload, and leaves the queue', () async {
      final outbox = build();
      Map<String, dynamic>? received;
      outbox.register('thing', (entry) async => received = entry.payload);

      await outbox.add(kind: 'thing', payload: {'module_id': 'm1'});
      await outbox.drain();

      expect(received, {'module_id': 'm1'});
      expect(outbox.entries, isEmpty);
    });

    test('oldest first — two states of one duty must not arrive reversed', () async {
      final outbox = build();
      final order = <String>[];
      outbox.register('thing', (entry) async {
        order.add(entry.payload['state'] as String);
      });

      await outbox.add(kind: 'thing', payload: {'state': 'in_progress'});
      await outbox.add(kind: 'thing', payload: {'state': 'done'});
      await outbox.drain();

      expect(order, ['in_progress', 'done']);
    });

    test('one that fails on the network stops the run, and keeps its place', () async {
      final outbox = build();
      var calls = 0;
      outbox.register('thing', (_) async {
        calls++;
        throw networkDown();
      });

      await outbox.add(kind: 'thing', payload: const {});
      await outbox.add(kind: 'thing', payload: const {});
      await outbox.drain();

      // The second was not even attempted: the network is gone, and it was
      // about to fail the same way.
      expect(calls, 1);
      expect(outbox.pendingCount, 2);
    });
  });

  group('giving up, and who is allowed to', () {
    test('one failure backs off rather than hammering a congested cell', () async {
      final outbox = build();
      outbox.register('thing', (_) async => throw networkDown());

      await outbox.add(kind: 'thing', payload: const {});
      await outbox.drain();

      final entry = outbox.entries.single;
      expect(entry.attempts, 1);
      expect(entry.isDue(DateTime.now()), isFalse);
      expect(entry.nextAttemptAt, isNotNull);
    });

    test('the last allowed failure stops it trying and hands it to a person',
        () async {
      // Seeded at one short of the cap rather than driven there, so the test
      // states the rule instead of waiting out seven real backoffs.
      await store.save([
        OutboxEntry(
          id: '1',
          kind: 'thing',
          payload: const {},
          createdAt: DateTime.now(),
          attempts: Outbox.maxAttempts - 1,
        ),
      ]);

      final outbox = build();
      outbox.register('thing', (_) async => throw networkDown());
      await outbox.start();

      final entry = outbox.entries.single;
      expect(entry.isBlocked, isTrue, reason: 'it stopped trying');
      expect(outbox.blockedCount, 1);
      expect(
        outbox.pendingCount,
        0,
        reason: 'a blocked entry is not on its way and must not be counted as it',
      );
    });

    test('a person putting a blocked entry back clears its record of failure',
        () async {
      await store.save([
        OutboxEntry(
          id: '1',
          kind: 'thing',
          payload: const {},
          createdAt: DateTime.now(),
          status: OutboxStatus.blocked,
          attempts: Outbox.maxAttempts,
          lastError: 'refused',
        ),
      ]);

      final outbox = build();
      var sent = false;
      outbox.register('thing', (_) async => sent = true);
      await outbox.start();

      expect(sent, isFalse, reason: 'blocked means it does not go on its own');

      await outbox.retry('1');

      expect(sent, isTrue);
      expect(outbox.entries, isEmpty);
    });

    test('an operation this build does not know is blocked, never dropped', () async {
      final outbox = build();
      // Registered so `add` accepts it — but failing, so it is still on disk
      // to be read back by a queue that has no handler for it at all. That is
      // an entry written by a newer build than the one now running.
      outbox.register('gone', (_) async => throw networkDown());
      await outbox.add(kind: 'gone', payload: const {});
      await outbox.close();

      final reader = build();
      await reader.start();

      expect(reader.entries.single.isBlocked, isTrue);
      expect(reader.entries.single.kind, 'gone');
    });

    test('discarding is the only thing that throws work away', () async {
      final outbox = build();
      outbox.register('thing', (_) async => throw StateError('refused'));
      final entry = await outbox.add(kind: 'thing', payload: const {});

      await outbox.drain();
      expect(outbox.entries, hasLength(1), reason: 'a failure never deletes it');

      await outbox.discard(entry.id);
      expect(outbox.entries, isEmpty);
    });
  });

  group('surviving the app being closed', () {
    test('what was waiting is still waiting next time', () async {
      final first = build();
      first.register('thing', (_) async {});
      await first.add(kind: 'thing', payload: {'notes': 'الغرف ٤٠١ مغلقة'});

      final second = build();
      second.register('thing', (_) async => throw networkDown());
      await second.start();

      expect(second.entries.single.payload['notes'], 'الغرف ٤٠١ مغلقة');
    });

    test('nothing comes back as "sending" — nothing is in flight after a restart',
        () async {
      final first = build();
      // Hangs, so the entry is written to disk while marked as sending.
      first.register('thing', (_) => Completer<void>().future);
      await first.add(kind: 'thing', payload: const {});
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final reloaded = await store.load();
      expect(reloaded.single.status, isNot(OutboxStatus.sending));
    });
  });

  group('the photographs', () {
    late File original;

    setUp(() async {
      original = File('${temp.path}/camp.jpg')..writeAsBytesSync([1, 2, 3]);
    });

    PendingAttachment photo() => PendingAttachment(
      file: original,
      name: 'مخيم ٧.jpg',
      kind: AttachmentKind.image,
      mimeType: 'image/jpeg',
    );

    test('a copy is taken, so the camera roll being swept loses nothing', () async {
      final outbox = build();
      outbox.register('thing', (_) async {});

      final entry = await outbox.add(
        kind: 'thing',
        payload: const {},
        attachments: [photo()],
      );

      // The phone clears its temp directory, which is what phones do.
      await original.delete();

      final kept = entry.files.single;
      expect(kept.file.existsSync(), isTrue);
      expect(kept.file.readAsBytesSync(), [1, 2, 3]);
      expect(
        kept.name,
        'مخيم ٧.jpg',
        reason: 'the Arabic name is what the reader of the report sees',
      );
    });

    test('the copy is handed to the handler as an ordinary attachment', () async {
      final outbox = build();
      List<String>? names;
      outbox.register('thing', (entry) async {
        names = [for (final file in entry.files) file.pending.name];
      });

      await outbox.add(kind: 'thing', payload: const {}, attachments: [photo()]);
      await outbox.drain();

      expect(names, ['مخيم ٧.jpg']);
    });

    test('the copies are cleared once it has been sent', () async {
      final outbox = build();
      outbox.register('thing', (_) async {});

      final entry = await outbox.add(
        kind: 'thing',
        payload: const {},
        attachments: [photo()],
      );
      final copy = entry.files.single.file;
      expect(copy.existsSync(), isTrue);

      await outbox.drain();

      expect(
        copy.existsSync(),
        isFalse,
        reason: 'a queue that never lets go fills the phone by the third day',
      );
    });

    test('copies belonging to no entry are swept at start-up', () async {
      final orphan = Directory('${temp.path}/files/999')
        ..createSync(recursive: true);
      File('${orphan.path}/old.jpg').writeAsBytesSync([9]);

      final outbox = build();
      await outbox.start();

      expect(orphan.existsSync(), isFalse);
    });
  });

  group('the network coming back', () {
    test('a reconnect drains without waiting out the backoff', () async {
      final reconnects = StreamController<void>.broadcast();
      addTearDown(reconnects.close);

      final outbox = build(reconnects: reconnects.stream);
      var succeed = false;
      outbox.register('thing', (_) async {
        if (!succeed) throw networkDown();
      });

      await outbox.add(kind: 'thing', payload: const {});
      await outbox.start();
      expect(outbox.pendingCount, 1, reason: 'still no network');
      expect(
        outbox.entries.single.nextAttemptAt,
        isNotNull,
        reason: 'it has backed off, and the backoff is minutes long',
      );

      succeed = true;
      reconnects.add(null);
      await waitUntil(() => outbox.entries.isEmpty);

      expect(
        outbox.entries,
        isEmpty,
        reason: 'a live radio makes the backoff wrong — it must not be waited out',
      );
    });

    test('a network watcher that cannot start does not take the app down',
        () async {
      // Windows. `connectivity_plus` fails to start its listener there —
      // NetworkManager::StartListen answering E_INVALIDARG — and the error
      // arrives on the stream the moment anything subscribes. Unhandled, it
      // escapes into the framework and is reported as a crash at every
      // start-up, on a desktop build, because of a feature written for a phone
      // in Mina.
      final broken = StreamController<void>.broadcast();
      addTearDown(broken.close);

      final outbox = build(reconnects: broken.stream);
      var sent = false;
      outbox.register('thing', (_) async => sent = true);
      await outbox.start();

      broken.addError(Exception('NetworkManager::StartListen'));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // The queue is still alive and still sends: the hint is lost, the
      // machinery is not.
      await outbox.add(kind: 'thing', payload: const {});
      await outbox.drain();

      expect(sent, isTrue);
      expect(outbox.entries, isEmpty);
    });

    test('a reconnect does not disturb what has stopped trying', () async {
      await store.save([
        OutboxEntry(
          id: '1',
          kind: 'thing',
          payload: const {},
          createdAt: DateTime.now(),
          status: OutboxStatus.blocked,
          attempts: Outbox.maxAttempts,
          lastError: 'refused',
        ),
      ]);

      final outbox = build();
      var sent = false;
      outbox.register('thing', (_) async => sent = true);
      await outbox.start();
      await outbox.onReconnect();

      expect(
        sent,
        isFalse,
        reason: 'it is waiting on a person, not on a radio',
      );
      expect(outbox.entries.single.isBlocked, isTrue);
    });
  });

  group('where there is no queue at all', () {
    // The web. `path_provider` has no implementation in a browser, so the
    // store cannot be opened and `bootstrap` installs nothing — which took the
    // whole app down at start-up until it was allowed to fail. Everything
    // below is what has to keep working once it has.

    test('nothing is installed by default', () {
      expect(Outbox.isInstalled, isFalse);
      expect(() => Outbox.instance, throwsStateError);
    });

    test('a write still goes out, and reports itself sent', () async {
      var sent = false;

      final result = await sendOrQueue(
        send: () async => sent = true,
        kind: 'thing',
        payload: const {},
      );

      expect(sent, isTrue);
      expect(result, isTrue, reason: 'there is no queue for it to be waiting in');
    });

    test('a failure is thrown to the caller rather than swallowed', () async {
      // With no queue there is nowhere to put it, so the screen must be told —
      // including when the cause was the network. Silently reporting success
      // would lose the work outright.
      await expectLater(
        sendOrQueue(
          send: () async => throw networkDown(),
          kind: 'thing',
          payload: const {},
        ),
        throwsA(isA<SocketException>()),
      );
    });
  });

  test('a corrupt queue file costs the queue, not the app', () async {
    File('${temp.path}/queue.json').writeAsStringSync('{ this is not json');

    final outbox = build();
    await expectLater(outbox.start(), completes);
    expect(outbox.entries, isEmpty);
  });
}
