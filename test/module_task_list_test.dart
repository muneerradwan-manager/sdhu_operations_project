import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/core/l10n/localized_name.dart';
import 'package:sdhu_operations_project/features/modules/domain/module_task.dart';

/// The duty lists of a file are DESCRIPTION (0105): two scopes, nothing to
/// press. What is worth testing is that the split cannot lie — a role duty
/// never leaks into the file's list, and each post's card carries exactly its
/// own lines, in the order they arrived.
void main() {
  ModuleTask task({
    required TaskScope scope,
    String id = 't1',
    String? roleId,
  }) => ModuleTask(
    id: id,
    scope: scope,
    roleId: roleId,
    title: LocalizedName(ar: id),
  );

  group('the two scopes come apart cleanly', () {
    final list = ModuleTaskList(
      tasks: [
        task(scope: TaskScope.file, id: 'f1'),
        task(scope: TaskScope.file, id: 'f2'),
        task(scope: TaskScope.role, id: 'r1', roleId: 'tower'),
        task(scope: TaskScope.role, id: 'r2', roleId: 'sector'),
        task(scope: TaskScope.role, id: 'r3', roleId: 'tower'),
      ],
    );

    test('file duties are only the file\'s', () {
      expect([for (final t in list.fileTasks) t.id], ['f1', 'f2']);
    });

    test('role duties group by post, keeping arrival order', () {
      final byRole = list.byRole;
      expect(byRole.keys, ['tower', 'sector']);
      expect([for (final t in byRole['tower']!) t.id], ['r1', 'r3']);
      expect([for (final t in byRole['sector']!) t.id], ['r2']);
    });

    test('a role row without a role id is dropped, not misfiled', () {
      final broken = ModuleTaskList(
        tasks: [task(scope: TaskScope.role, id: 'r0')],
      );
      expect(broken.byRole, isEmpty);
      expect(broken.fileTasks, isEmpty);
    });
  });

  group('scope round-trips through the db names', () {
    test('both scopes survive', () {
      for (final scope in TaskScope.values) {
        expect(TaskScope.fromDb(scope.dbName), scope);
      }
    });

    test('anything unknown falls back to file, the harmless reading', () {
      expect(TaskScope.fromDb(null), TaskScope.file);
      expect(TaskScope.fromDb('personal'), TaskScope.file);
    });
  });
}
