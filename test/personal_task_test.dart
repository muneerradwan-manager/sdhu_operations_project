import 'package:flutter_test/flutter_test.dart';
import 'package:sdhu_operations_project/features/tasks/domain/personal_task.dart';

/// What a task is, once it stopped being a value and became an exchange.
///
/// The transition matrix itself is deliberately NOT tested here, because it is
/// deliberately not here: `personal_task_transition_allowed` (0117) is the one
/// place that decides what may be pressed, and [PersonalTask.actions] only
/// carries its answer. A Dart copy of those rules would be a second opinion,
/// and the first bug it produced would be a button the database refuses.
///
/// What IS worth pinning down is everything the screens derive on their own —
/// the shape of a row as it arrives, what counts as late, and the order a list
/// falls into. That last one has form: 0105's repository promised an ordering
/// in a comment and asked the database for a different one, and nothing failed.
Map<String, dynamic> row({
  String id = 'task-1',
  int seq = 142,
  String profileId = 'me',
  String createdBy = 'me',
  String state = 'not_started',
  String priority = 'normal',
  String? dueOn,
  List<String> actions = const [],
  int stepsTotal = 0,
  int stepsDone = 0,
}) => {
  'id': id,
  'seq': seq,
  'profile_id': profileId,
  'created_by': createdBy,
  'title': 'استلام كشوف الحجاج',
  'state': state,
  'priority': priority,
  'kind': 'task',
  'due_on': dueOn,
  'actions': actions,
  'steps_total': stepsTotal,
  'steps_done': stepsDone,
  'is_assigned': createdBy != profileId,
};

String dateOf(DateTime when) =>
    '${when.year.toString().padLeft(4, '0')}-'
    '${when.month.toString().padLeft(2, '0')}-'
    '${when.day.toString().padLeft(2, '0')}';

void main() {
  group('the one comparison the whole system rests on', () {
    test('written by its owner is a notebook, anything else was assigned', () {
      expect(PersonalTask.fromMap(row()).isAssigned, isFalse);
      expect(
        PersonalTask.fromMap(row(createdBy: 'somebody-else')).isAssigned,
        isTrue,
      );
    });

    test('a row with no actions offers nothing, and says so as an empty set', () {
      // Not null and not "everything": a finished task read by somebody with no
      // pen over it legitimately has no moves, and the screen draws no buttons
      // rather than grey ones.
      expect(PersonalTask.fromMap(row()).actions, isEmpty);
      expect(PersonalTask.fromMap(row()).can(TaskState.done), isFalse);
    });

    test('the permitted moves arrive from the server and are carried whole', () {
      final task = PersonalTask.fromMap(
        row(state: 'submitted', actions: ['done', 'returned']),
      );
      expect(task.can(TaskState.done), isTrue);
      expect(task.can(TaskState.returned), isTrue);
      expect(task.can(TaskState.inProgress), isFalse);
    });
  });

  group('states', () {
    test('the four new spellings survive the round trip', () {
      for (final state in TaskState.values) {
        expect(TaskState.fromDb(state.dbName), state);
      }
    });

    test('an unknown spelling reads as not started rather than throwing', () {
      // An older build meeting a value a newer migration added. Showing it as
      // «لم تبدأ» is wrong in a way a person can see and correct; throwing
      // takes the whole list down.
      expect(TaskState.fromDb('teleported'), TaskState.notStarted);
      expect(TaskState.fromDb(null), TaskState.notStarted);
    });

    test('open is neither finished nor withdrawn', () {
      expect(TaskState.notStarted.isOpen, isTrue);
      expect(TaskState.blocked.isOpen, isTrue);
      expect(TaskState.submitted.isOpen, isTrue);
      expect(TaskState.done.isOpen, isFalse);
      expect(TaskState.cancelled.isOpen, isFalse);
    });

    test('exactly two states are worthless without words', () {
      // Mirrors the `task_comment_required` check in `set_personal_task_state`.
      // If these two ever disagree, the screen offers a one-tap button that the
      // server refuses — which is the failure this pair of rules exists to
      // prevent.
      expect(
        TaskState.values.where((s) => s.needsComment).toSet(),
        {TaskState.blocked, TaskState.returned},
      );
    });
  });

  group('what a list falls into', () {
    test('what is wrong comes before what is merely unfinished', () {
      expect(TaskState.returned.bucket, TaskState.blocked.bucket);
      expect(
        TaskState.blocked.bucket,
        lessThan(TaskState.inProgress.bucket),
      );
    });

    test('work waiting on somebody else sits below work waiting on me', () {
      expect(
        TaskState.inProgress.bucket,
        lessThan(TaskState.submitted.bucket),
      );
    });

    test('finished sinks, and withdrawn sinks below it', () {
      expect(TaskState.submitted.bucket, lessThan(TaskState.done.bucket));
      expect(TaskState.done.bucket, lessThan(TaskState.cancelled.bucket));
    });

    test('the buckets match `personal_task_bucket` in 0118', () {
      // Written out rather than derived, so that changing one side of the pair
      // without the other fails here instead of in a list that quietly sorts
      // differently on the device than it did on the server.
      expect(
        {for (final s in TaskState.values) s.dbName: s.bucket},
        {
          'returned': 0,
          'blocked': 0,
          'in_progress': 1,
          'not_started': 1,
          'submitted': 2,
          'done': 3,
          'cancelled': 4,
        },
      );
    });
  });

  group('priority', () {
    test('is declared high to low, so the enum order IS the sort order', () {
      expect(TaskPriority.values, [
        TaskPriority.high,
        TaskPriority.normal,
        TaskPriority.low,
      ]);
    });

    test('only the two ends are worth drawing', () {
      // A badge on nine rows in ten labels nothing and crowds out the one row
      // that is urgent.
      expect(TaskPriority.normal.isNotable, isFalse);
      expect(TaskPriority.high.isNotable, isTrue);
      expect(TaskPriority.low.isNotable, isTrue);
    });
  });

  group('lateness', () {
    final today = DateTime.now();
    final yesterday = today.subtract(const Duration(days: 1));
    final lastWeek = today.subtract(const Duration(days: 7));
    final tomorrow = today.add(const Duration(days: 1));

    test('a task due yesterday and still owed is late', () {
      final task = PersonalTask.fromMap(row(dueOn: dateOf(yesterday)));
      expect(task.isOverdue, isTrue);
      expect(task.daysLate, 1);
    });

    test('a task due today is not late', () {
      final task = PersonalTask.fromMap(row(dueOn: dateOf(today)));
      expect(task.isOverdue, isFalse);
      expect(task.daysLate, 0);
    });

    test('a task with no date is never late', () {
      expect(PersonalTask.fromMap(row()).isOverdue, isFalse);
    });

    test('a finished task is not late, however long ago it was due', () {
      final task = PersonalTask.fromMap(
        row(dueOn: dateOf(lastWeek), state: 'done'),
      );
      expect(task.isOverdue, isFalse);
      expect(task.daysLate, 0);
    });

    test('a withdrawn task is not late either', () {
      final task = PersonalTask.fromMap(
        row(dueOn: dateOf(lastWeek), state: 'cancelled'),
      );
      expect(task.isOverdue, isFalse);
    });

    test('a task due tomorrow is not late', () {
      expect(
        PersonalTask.fromMap(row(dueOn: dateOf(tomorrow))).isOverdue,
        isFalse,
      );
    });
  });

  group('progress', () {
    test('withdrawn work is not counted against the total', () {
      // Otherwise a section that withdrew two of six reads 4/6 forever and can
      // never be finished, which is a bar that never fills for a reason nobody
      // on the screen can see.
      final tasks = [
        PersonalTask.fromMap(row(id: 'a', state: 'done')),
        PersonalTask.fromMap(row(id: 'b', state: 'done')),
        PersonalTask.fromMap(row(id: 'c', state: 'in_progress')),
        PersonalTask.fromMap(row(id: 'd', state: 'cancelled')),
      ];
      expect(PersonalTask.progressOf(tasks), (2, 3));
    });

    test('an empty list is zero of zero rather than a division', () {
      expect(PersonalTask.progressOf(const []), (0, 0));
    });

    test('steps are carried as counts on the list and as rows on the page', () {
      final listed = PersonalTask.fromMap(row(stepsTotal: 4, stepsDone: 2));
      expect(listed.hasSteps, isTrue);
      expect(listed.steps, isEmpty);

      final opened = PersonalTask.fromMap({
        ...row(),
        'steps': [
          {'id': 's1', 'label': 'أ', 'is_done': true, 'sort_order': 0},
          {'id': 's2', 'label': 'ب', 'is_done': false, 'sort_order': 1},
        ],
      });
      expect(opened.steps.map((s) => s.label), ['أ', 'ب']);

      // Ticking one recomputes both counters, so an optimistic tap moves the
      // bar without waiting for the read that confirms it.
      final ticked = opened.copyWith(
        steps: [opened.steps.first, opened.steps.last.toggled(true)],
      );
      expect(ticked.stepsDone, 2);
      expect(ticked.stepsTotal, 2);
    });
  });

  group('the said number', () {
    test('a row missing its seq reads as zero rather than throwing', () {
      // A queued write replayed against a build that predates 0118, or a
      // snapshot written before it. Nothing on screen depends on the number
      // being right; everything depends on the list drawing.
      final map = row()..remove('seq');
      expect(PersonalTask.fromMap(map).seq, 0);
    });
  });

  group('batches', () {
    test('progress is a fraction, and complete means all of it', () {
      const batch = TaskBatch(id: 'b', title: 'الكشوف', total: 6, done: 4);
      expect(batch.progress, closeTo(0.666, 0.01));
      expect(batch.isComplete, isFalse);

      const finished = TaskBatch(id: 'b', title: 'الكشوف', total: 6, done: 6);
      expect(finished.isComplete, isTrue);
    });

    test('an empty batch does not divide by zero', () {
      const batch = TaskBatch(id: 'b', title: 'الكشوف', total: 0, done: 0);
      expect(batch.progress, 0);
      expect(batch.isComplete, isFalse);
    });
  });
}
