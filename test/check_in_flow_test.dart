import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/utils/device_position.dart';
import 'package:sdhu_operations_project/features/checkin/application/check_in_cubit.dart';
import 'package:sdhu_operations_project/features/checkin/data/check_in_outbox.dart';
import 'package:sdhu_operations_project/features/checkin/data/check_in_repository.dart';
import 'package:sdhu_operations_project/features/checkin/domain/check_in.dart';

/// The Kaaba, and a point nine kilometres off at منى.
const _here = (latitude: 21.422510, longitude: 39.826168, accuracy: 8.0);
const _far = (latitude: 21.421147, longitude: 39.914453, accuracy: 8.0);

/// A poster carrying the place's own position, as one printed since 0098 does.
const _pinned = PlaceCode(
  itemId: 'i-1',
  secret: 'abcdef0123456789',
  latitude: 21.422510,
  longitude: 39.826168,
  radiusM: 200,
);

/// A poster printed before the position was carried on it.
const _bare = PlaceCode(itemId: 'i-1', secret: 'abcdef0123456789');

/// A repository that answers however the test needs it to, and records whether
/// it was asked at all.
class _Repo implements CheckInRepository {
  _Repo({this.throws});

  final Object? throws;
  int calls = 0;

  @override
  Future<CheckInReceipt> checkIn({
    required String itemId,
    required String secret,
    required double latitude,
    required double longitude,
    double? accuracy,
    String? note,
  }) async {
    calls++;
    if (throws != null) throw throws!;
    return (
      id: 'c-1',
      placeName: 'فندق الأنصار',
      distanceM: 12.0,
      radiusM: 200.0,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

Future<Fix?> _fix(Fix? value) async => value;

void main() {
  // No Outbox is installed in these tests, which is itself the assertion in
  // several of them: `Outbox.isInstalled` is false, so anything that reaches
  // the queueing branch comes back `failed` rather than `queued`. A refusal
  // that queued would show up here as the wrong outcome.

  group('what may never be queued', () {
    test('no position is a refusal, and the server is never even asked', () async {
      // The most important rule in the feature. Since 0098 a positionless
      // check-in cannot be accepted at any later moment, so queueing one would
      // tell a man his arrival was kept and throw it away hours afterwards —
      // the exact failure the outbox exists to prevent, reintroduced from the
      // other end.
      final repo = _Repo();

      final result = await CheckIn.arrive(
        code: _pinned,
        repository: repo,
        fix: () => _fix(null),
      );

      expect(result.outcome.ok, isFalse);
      expect(result.outcome.queued, isFalse);
      expect(result.outcome.error, 'check_in_needs_a_position');
      expect(
        repo.calls,
        0,
        reason: 'a round trip that could only be refused was still made',
      );
    });

    test('too far, with the network gone, is a refusal and not a queue', () async {
      // Offline the phone has only the poster's numbers, and they are enough to
      // know this cannot succeed. Queueing it would be the same lie as above,
      // told nine kilometres from the place.
      final repo = _Repo(throws: const SocketException('no route to host'));

      final result = await CheckIn.arrive(
        code: _pinned,
        repository: repo,
        fix: () => _fix(_far),
      );

      expect(result.outcome.queued, isFalse);
      expect(result.outcome.error, 'check_in_too_far');
    });
  });

  group('what the poster\'s own numbers may do', () {
    test('a corrected pin does not make an old poster refuse a man standing in '
        'the right place', () async {
      // The rule the obvious design gets wrong. The coordinates on a sticker
      // are a COPY, and a copy goes stale the moment an administrator corrects
      // the pin in the master data. If the phone checked them before every
      // send, every sticker already on a wall would start refusing men standing
      // exactly where they should be — the poster's old numbers outvoting the
      // server's new ones.
      //
      // So online the server decides, always. Here the poster claims the place
      // is at the Kaaba and the man is at منى: a local check would refuse him,
      // and the call must go through regardless.
      final repo = _Repo();

      final result = await CheckIn.arrive(
        code: _pinned,
        repository: repo,
        fix: () => _fix(_far),
      );

      expect(repo.calls, 1, reason: 'the local copy vetoed an online send');
      expect(result.outcome.ok, isTrue);
      expect(result.receipt?.placeName, 'فندق الأنصار');
    });

    test('and an old poster with no numbers at all still queues', () async {
      // Printed before 0098 carried the position. There is nothing to check
      // against, so the arrival is kept and the server judges it when it
      // arrives — which is exactly the behaviour before this feature existed.
      final repo = _Repo(throws: const SocketException('offline'));

      final result = await CheckIn.arrive(
        code: _bare,
        repository: repo,
        fix: () => _fix(_far),
      );

      // No queue is installed in tests, so reaching the queueing branch shows
      // as `failed` carrying the network error rather than the refusal.
      expect(result.outcome.error, isNot('check_in_too_far'));
    });
  });

  group('what the server says goes', () {
    test('a refusal is shown, never swallowed', () async {
      // The same rule `Outbox.sendOrQueue` states for every other write: online
      // is the ordinary case and a refusal there should be SEEN. A queue that
      // swallowed "this code is no longer valid" would send a man away
      // believing he was recorded.
      final repo = _Repo(
        throws: Exception('PostgrestException(message: check_in_code_expired)'),
      );

      final result = await CheckIn.arrive(
        code: _pinned,
        repository: repo,
        fix: () => _fix(_here),
      );

      expect(result.outcome.queued, isFalse);
      expect(result.outcome.error, contains('check_in_code_expired'));
    });

    test('the receipt names the place and the distance', () async {
      // The only check against a poster fixed to the wrong gate — the one
      // mistake that makes the whole register lie, because it records people as
      // present somewhere they have never been. A confirmation that only says
      // "recorded" cannot catch it; one that says which place can.
      final repo = _Repo();

      final result = await CheckIn.arrive(
        code: _pinned,
        repository: repo,
        fix: () => _fix(_here),
      );

      expect(result.receipt, isNotNull);
      expect(result.receipt!.placeName, 'فندق الأنصار');
      expect(result.receipt!.distanceM, 12);
    });
  });

  test('the position is taken before anything is sent', () async {
    // Order, not politeness. What must be recorded is where the man was when he
    // pressed — not where the phone was when a queue finally drained, which may
    // be another camp or another city hours later, and against which the
    // database would then measure a distance and believe it.
    final order = <String>[];
    final repo = _Repo();

    await CheckIn.arrive(
      code: _pinned,
      repository: _RecordingRepo(repo, order),
      fix: () async {
        order.add('fix');
        return _here;
      },
    );

    expect(order, ['fix', 'send']);
  });

  test('an entry from an older build has nowhere to go', () async {
    // A queued check-in written before 0098 carries a module and a node, and
    // there is no longer anything to send it to. The kind is deliberately new,
    // so such an entry finds no handler and is BLOCKED rather than replayed
    // into one that would misread every field — and a person decides whether to
    // discard his own work.
    expect(CheckInOutbox.kind, isNot(CheckInOutbox.retiredKind));
  });
}

class _RecordingRepo implements CheckInRepository {
  _RecordingRepo(this._inner, this._order);

  final _Repo _inner;
  final List<String> _order;

  @override
  Future<CheckInReceipt> checkIn({
    required String itemId,
    required String secret,
    required double latitude,
    required double longitude,
    double? accuracy,
    String? note,
  }) {
    _order.add('send');
    return _inner.checkIn(
      itemId: itemId,
      secret: secret,
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      note: note,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}
