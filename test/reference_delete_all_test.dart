import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/features/modules/application/reference_data_cubit.dart';
import 'package:sdhu_operations_project/features/modules/data/modules_repository.dart';
import 'package:sdhu_operations_project/features/modules/domain/reference_item.dart';
import 'package:sdhu_operations_project/features/seasons/data/seasons_repository.dart';
import 'package:sdhu_operations_project/features/seasons/domain/season.dart';

/// Emptying a list is not one delete repeated. A BEFORE DELETE trigger refuses
/// any entry a module — or another entry — still points at, so the question the
/// screen has to answer is how much of the list actually went, and the answer
/// changes as the list shrinks: a تكتل nothing points at any more is deletable
/// on the second pass and was not on the first.
///
/// These are the three outcomes an admin can hit, held against a repository
/// that refuses exactly what the trigger would.
class _FakeSeasons extends SeasonsRepository {
  @override
  Future<Season?> fetchCurrentSeason() async => null;
}

class _FakeModules extends ModulesRepository {
  _FakeModules({this.blockedBy = const {}, this.permanent = const {}});

  /// id -> the id whose presence blocks it, the way a مجموعة blocks its تكتل.
  final Map<String, String> blockedBy;

  /// Entries nothing will ever free: a module was built on them.
  final Set<String> permanent;

  final deleted = <String>[];
  var passes = 0;

  @override
  Future<List<ReferenceSet>> fetchReferenceSets({
    bool activeOnly = true,
  }) async => const [];

  @override
  Future<void> deleteReferenceItem(String id) async {
    passes++;
    final blocker = blockedBy[id];
    if (permanent.contains(id) ||
        (blocker != null && !deleted.contains(blocker))) {
      throw Exception('reference_item_in_use');
    }
    deleted.add(id);
  }
}

void main() {
  test('a list nothing points at goes entirely', () async {
    final repo = _FakeModules();
    final cubit = ReferenceDataCubit(repo, _FakeSeasons());

    final result = await cubit.deleteItems(['a', 'b', 'c']);

    expect(result.deleted, 3);
    expect(result.kept, 0);
    expect(result.message, isNull);
    expect(repo.deleted, ['a', 'b', 'c']);
  });

  test('an entry freed by an earlier delete is caught on a later pass', () async {
    // 'parent' is refused while 'child' stands, and 'child' is listed second —
    // so a single pass would leave it behind and report the list as half-emptied.
    final repo = _FakeModules(blockedBy: {'parent': 'child'});
    final cubit = ReferenceDataCubit(repo, _FakeSeasons());

    final result = await cubit.deleteItems(['parent', 'child']);

    expect(result.deleted, 2);
    expect(result.kept, 0);
    expect(repo.deleted, ['child', 'parent']);
  });

  test('what the guard keeps is counted, not silently dropped', () async {
    final repo = _FakeModules(permanent: {'used'});
    final cubit = ReferenceDataCubit(repo, _FakeSeasons());

    final result = await cubit.deleteItems(['a', 'used', 'b']);

    expect(result.deleted, 2);
    expect(result.kept, 1, reason: 'the admin is told one entry stayed');
    expect(
      result.message,
      isNull,
      reason: 'in-use is an outcome, not an error to show raw',
    );
  });

  test(
    'a list that is entirely in use stops instead of retrying forever',
    () async {
      final repo = _FakeModules(permanent: {'x', 'y'});
      final cubit = ReferenceDataCubit(repo, _FakeSeasons());

      final result = await cubit.deleteItems(['x', 'y']);

      expect(result.deleted, 0);
      expect(result.kept, 2);
      expect(
        repo.passes,
        2,
        reason: 'one pass that frees nothing is the end of it',
      );
    },
  );

  test(
    'a failure that is not the guard is carried out for the reader',
    () async {
      final repo = _FailingModules();
      final cubit = ReferenceDataCubit(repo, _FakeSeasons());

      final result = await cubit.deleteItems(['a']);

      expect(result.deleted, 0);
      expect(result.kept, 1);
      expect(result.message, contains('SocketException'));
    },
  );
}

class _FailingModules extends ModulesRepository {
  @override
  Future<List<ReferenceSet>> fetchReferenceSets({
    bool activeOnly = true,
  }) async => const [];

  @override
  Future<void> deleteReferenceItem(String id) async =>
      throw Exception('SocketException: connection failed');
}
