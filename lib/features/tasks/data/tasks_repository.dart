import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/snapshots.dart';
import '../../../core/supabase/storage_key.dart';
import '../../../core/supabase/supabase_client.dart';
import '../domain/personal_task.dart';
import '../domain/task_thread.dart';

/// Reads and writes one person's task list (`personal_tasks`, 0105; widened
/// 0117–0119).
///
/// No module id anywhere in the file: this system has no relation to the
/// operational files.
///
/// What changed in 0118 is HOW it is read. 0105 selected the whole table for a
/// person on every open and then fetched every attachment they had ever filed
/// in a second round trip — survivable at eleven rows, and not the first season
/// anybody uses this properly. Reading now goes through four functions that
/// filter, order and page on the server, and that carry the counts and the
/// permitted moves with each row, so a list of thirty is one call.
///
/// The ordering in particular is not the client's business and never was. 0105
/// promised "undone work first, then by due date, then newest" in a comment and
/// asked for `order('created_at')`; the promise now lives in
/// `personal_task_bucket` where it can be kept.
class TasksRepository {
  static const _bucket = 'tasks';

  // -------------------------------------------------------------- reading

  /// Everything on the caller's list, filtered by [view] and whatever else was
  /// asked. Readable with no signal, from the last good answer — see
  /// [Snapshots].
  ///
  /// This is the list a man checks standing somewhere, which is exactly where
  /// the network is not. Only the PLAIN read of a view is kept: a saved copy of
  /// "high priority, matching كشف, page 3" answers a question nobody asks with
  /// no signal, and every filter combination kept would be a directory of
  /// stale files on a phone.
  Future<Cached<List<PersonalTask>>> fetchMine({
    TaskView view = TaskView.open,
    TaskState? state,
    TaskPriority? priority,
    TaskKind? kind,
    String? query,
    int limit = 100,
    int offset = 0,
  }) async {
    final me = supabase.auth.currentUser?.id;
    if (me == null) return const Cached([]);

    final params = {
      'p_view': view.dbName,
      'p_state': state?.dbName,
      'p_priority': priority?.dbName,
      'p_kind': kind?.dbName,
      'p_query': query,
      'p_limit': limit,
      'p_offset': offset,
    };

    final plain =
        state == null &&
        priority == null &&
        kind == null &&
        (query == null || query.isEmpty) &&
        offset == 0;

    if (!plain) {
      return Cached(_parse(await supabase.rpc('my_personal_tasks', params: params)));
    }

    return readWithSnapshot(
      // Keyed by person AND view: a shared phone must not serve one man's list
      // to the next, and «المتأخرة» restored over «الكل» would be a lie with a
      // timestamp on it.
      key: 'tasks.mine.$me.${view.dbName}',
      fetch: () => supabase.rpc('my_personal_tasks', params: params),
      parse: _parse,
    );
  }

  /// What the caller wrote onto other people's lists — or, with
  /// `tasks.view_all`, every assigned task in the mission.
  ///
  /// Not kept on disk. Nobody assigns tasks standing in Mina, and a saved copy
  /// of what other people owe is a screen that cannot be acted on anyway.
  Future<List<PersonalTask>> fetchAssigned({
    bool everyone = false,
    TaskView view = TaskView.open,
    TaskState? state,
    TaskPriority? priority,
    String? query,
    int limit = 200,
    int offset = 0,
  }) async {
    if (supabase.auth.currentUser == null) return const [];
    return _parse(
      await supabase.rpc(
        'assigned_personal_tasks',
        params: {
          'p_scope': everyone ? 'all' : 'mine',
          'p_view': view.dbName,
          'p_state': state?.dbName,
          'p_priority': priority?.dbName,
          'p_query': query,
          'p_limit': limit,
          'p_offset': offset,
        },
      ),
    );
  }

  /// Work the caller asked for that somebody says is finished. Its own call
  /// rather than a filter the screen composes, because it is the one queue on
  /// that page that is a JOB — nothing moves until this person decides.
  Future<List<PersonalTask>> fetchReviewQueue({bool everyone = false}) =>
      fetchAssigned(everyone: everyone, view: TaskView.all, state: TaskState.submitted);

  /// One task, whole: the row, its steps, and the evidence filed against the
  /// task itself. What hangs off a comment travels in [fetchThread].
  Future<PersonalTask> fetchOne(String taskId) async {
    final row = await supabase.rpc(
      'personal_task_detail',
      params: {'p_task_id': taskId},
    );
    return PersonalTask.fromMap((row as Map).cast<String, dynamic>());
  }

  /// Said and happened, in one list, oldest first.
  Future<List<TaskThreadEntry>> fetchThread(String taskId) async {
    final rows = await supabase.rpc(
      'personal_task_thread',
      params: {'p_task_id': taskId},
    );
    return [
      for (final row in (rows as List?) ?? const [])
        TaskThreadEntry.fromMap((row as Map).cast<String, dynamic>()),
    ];
  }

  /// The decisions the caller made, each with what it adds up to.
  Future<List<TaskBatch>> fetchBatches({int limit = 50, int offset = 0}) async {
    final rows = await supabase.rpc(
      'my_task_batches',
      params: {'p_limit': limit, 'p_offset': offset},
    );
    return [
      for (final row in (rows as List?) ?? const [])
        TaskBatch.fromMap((row as Map).cast<String, dynamic>()),
    ];
  }

  /// One decision and everyone carrying a piece of it.
  Future<List<PersonalTask>> fetchBatchTasks(String batchId) async =>
      _parse(await supabase.rpc('task_batch_tasks', params: {'p_batch_id': batchId}));

  /// The four numbers on the home card.
  Future<TaskStats> fetchStats() async {
    final rows = await supabase.rpc('my_task_stats');
    final first = ((rows as List?) ?? const []).firstOrNull;
    if (first == null) return const TaskStats();
    return TaskStats.fromMap((first as Map).cast<String, dynamic>());
  }

  /// Every read of a task returns the same shape (`personal_task_row_json`),
  /// which is why there is one parser here and not four.
  List<PersonalTask> _parse(dynamic rows) => [
    for (final row in (rows as List?) ?? const [])
      // The list functions return a single `task` column; the batch and detail
      // reads return the object itself. Unwrapped here so the caller never has
      // to know which shape it asked for.
      PersonalTask.fromMap(
        ((row as Map)['task'] as Map?)?.cast<String, dynamic>() ??
            row.cast<String, dynamic>(),
      ),
  ];

  // -------------------------------------------------------------- writing

  /// Writes a task — onto the caller's own list when [profileIds] is empty,
  /// onto everybody it names otherwise (which the database allows only to
  /// `tasks.assign`).
  ///
  /// Several people, one statement, and since 0118 one DECISION: the batch row
  /// and its six task rows are written by `create_personal_tasks` in a single
  /// transaction. Assigning "استلام كشوف الحجاج" to six supervisors is one act,
  /// and it now leaves one thing behind that can be followed up as one.
  ///
  /// Returns the new rows' ids, in the order they were written; evidence is
  /// stored under them.
  Future<List<String>> create({
    required String title,
    String? description,
    DateTime? dueOn,
    Set<String> profileIds = const {},
    TaskPriority priority = TaskPriority.normal,
    TaskKind kind = TaskKind.task,
    List<String> steps = const [],
  }) async {
    final rows = await supabase.rpc(
      'create_personal_tasks',
      params: {
        'p_title': title,
        'p_description': description == null || description.isEmpty
            ? null
            : description,
        'p_due_on': dueOn == null ? null : _asDate(dueOn),
        'p_profile_ids': profileIds.isEmpty ? null : profileIds.toList(),
        'p_priority': priority.dbName,
        'p_kind': kind.dbName,
        'p_steps': steps.isEmpty ? null : steps,
      },
    );
    return [
      for (final row in (rows as List?) ?? const [])
        (row as Map)['id'] as String,
    ];
  }

  /// Corrects a task the caller has full control of — their own, or one they
  /// assigned. The owner of an ASSIGNED task never reaches here; the database
  /// refuses them, and the screen does not offer it.
  Future<void> update({
    required String id,
    required String title,
    String? description,
    DateTime? dueOn,
    TaskPriority? priority,
    TaskKind? kind,
  }) async {
    await supabase
        .from('personal_tasks')
        .update({
          'title': title,
          'description': (description == null || description.isEmpty)
              ? null
              : description,
          'due_on': dueOn == null ? null : _asDate(dueOn),
          if (priority != null) 'priority': priority.dbName,
          if (kind != null) 'kind': kind.dbName,
        })
        .eq('id', id);
  }

  /// Removes a task, its evidence rows (`cascade`) and their files.
  ///
  /// Only ever a task somebody wrote for THEMSELVES: 0117 closed deletion of
  /// assigned work, because a row vanishing from another man's list overnight
  /// is not a decision he can read. Withdrawing one is [TaskState.cancelled].
  Future<void> delete(PersonalTask task) async {
    if (task.attachments.isNotEmpty) {
      await supabase.storage.from(_bucket).remove([
        for (final a in task.attachments) a.path,
      ]);
    }
    await supabase.from('personal_tasks').delete().eq('id', task.id);
  }

  /// Moves a task, with whatever was said about the move.
  ///
  /// Through an RPC rather than a plain update because the transition matrix
  /// (0117) is the server's to enforce, and because for an assigned task this
  /// is the one write its owner may make.
  ///
  /// The third parameter keeps the name `p_note` it was given in 0105 — entries
  /// written by an older build are sitting in outboxes on phones right now and
  /// name their arguments. What it MEANS is a comment appended to the thread.
  Future<void> setState({
    required String taskId,
    required TaskState state,
    String? note,
  }) async {
    await supabase.rpc(
      'set_personal_task_state',
      params: {'p_task_id': taskId, 'p_state': state.dbName, 'p_note': note},
    );
  }

  /// Saying something without moving anything. Returns the comment's id, so
  /// evidence can be filed under it rather than loose against the task.
  Future<String> addComment({
    required String taskId,
    required String body,
  }) async {
    final id = await supabase.rpc(
      'add_personal_task_comment',
      params: {'p_task_id': taskId, 'p_body': body},
    );
    return id as String;
  }

  /// Hands a task to somebody else without deleting it — the thread, the
  /// evidence and the fact that anybody worked on it all survive (0119).
  Future<void> reassign({
    required String taskId,
    required String profileId,
  }) async {
    await supabase.rpc(
      'reassign_personal_task',
      params: {'p_task_id': taskId, 'p_profile_id': profileId},
    );
  }

  /// Replaces the checklist wholesale. Ticks are preserved by label on the
  /// server, so reordering four boxes does not un-tick the two already done.
  Future<void> setSteps({
    required String taskId,
    required List<String> labels,
  }) async {
    await supabase.rpc(
      'set_personal_task_steps',
      params: {'p_task_id': taskId, 'p_labels': labels},
    );
  }

  /// The one-thumb write: ticking a box standing in front of the thing.
  Future<void> setStepDone({
    required String stepId,
    required bool isDone,
  }) async {
    await supabase
        .from('personal_task_steps')
        .update({'is_done': isDone})
        .eq('id', stepId);
  }

  /// Files evidence against a task — or against one thing said about it, when
  /// [commentId] is given — and takes back whatever was removed.
  Future<void> setAttachments({
    required String taskId,
    String? commentId,
    List<PendingAttachment> attachments = const [],
    List<StoredAttachment> removed = const [],
  }) async {
    for (final attachment in removed) {
      await supabase
          .from('personal_task_attachments')
          .delete()
          .eq('id', attachment.id);
      await supabase.storage.from(_bucket).remove([attachment.path]);
    }
    if (attachments.isEmpty) return;

    // Where the next one starts, so filing twice does not overwrite what is
    // already there — two photos off one camera roll can share a name.
    final existing = await supabase
        .from('personal_task_attachments')
        .select('sort_order')
        .eq('task_id', taskId)
        .order('sort_order', ascending: false)
        .limit(1);
    var next =
        ((existing as List).firstOrNull as Map<String, dynamic>?)?['sort_order']
            as int? ??
        -1;

    final rows = <Map<String, dynamic>>[];
    for (final attachment in attachments) {
      next++;
      final path =
          '$taskId/${next}_${storageKey(attachment.name, fallback: '$next')}';
      await supabase.storage
          .from(_bucket)
          .upload(
            path,
            attachment.file,
            fileOptions: FileOptions(
              upsert: true,
              contentType: attachment.mimeType,
            ),
          );
      rows.add({
        'task_id': taskId,
        'comment_id': commentId,
        'kind': attachment.kind.name,
        'path': path,
        'name': attachment.name,
        'mime_type': attachment.mimeType,
        'size_bytes': attachment.file.lengthSync(),
        'sort_order': next,
      });
    }
    await supabase.from('personal_task_attachments').insert(rows);
  }

  /// A short-lived link to an attachment. Signing goes through row security,
  /// so a link only ever comes back for a file the caller may see.
  Future<String> signedUrl(
    String path, {
    int expiresInSeconds = 600,
    bool download = false,
    String? downloadName,
  }) {
    return supabase.storage
        .from(_bucket)
        .createSignedUrl(path, expiresInSeconds)
        .then((url) {
          if (!download) return url;
          final separator = url.contains('?') ? '&' : '?';
          final name = Uri.encodeComponent(downloadName ?? '');
          return '$url${separator}download${name.isEmpty ? '' : '=$name'}';
        });
  }

  String _asDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
