import '../../../core/l10n/localized_name.dart';

/// What a duty on a file is attached to. Two, since 0105: a person is never
/// one of them — personal tasks live in their own system (`personal_tasks`),
/// outside the operational files entirely.
///
/// Mirrors the `module_task_scope` enum (0083; the `personal` value survives
/// in the type but no row may carry it).
enum TaskScope {
  /// The file's own work. Every member sees the same list, and the members
  /// divide it among themselves — off the record, which is the point: the
  /// list says what the work IS, not who is winning at it.
  file,

  /// The duties of a post. Whoever holds مشرف البرج carries them by holding
  /// it; replacing the person leaves the list exactly where it was.
  role;

  static TaskScope fromDb(String? value) =>
      value == 'role' ? TaskScope.role : TaskScope.file;

  String get dbName => switch (this) {
    TaskScope.file => 'file',
    TaskScope.role => 'role',
  };
}

/// One duty written on one file (`module_tasks`) — a DESCRIPTION, nothing to
/// press.
///
/// 0105 removed the tracker: no state, no note, no evidence. What people
/// actually track is their own list (see the tasks feature); what a file
/// needs is to say what its work is, and this is that sentence.
class ModuleTask {
  const ModuleTask({
    required this.id,
    required this.scope,
    required this.title,
    this.roleId,
    this.description,
    this.dueOn,
    this.sortOrder = 0,
  });

  final String id;
  final TaskScope scope;

  /// The post, for [TaskScope.role].
  final String? roleId;

  final LocalizedName title;
  final LocalizedName? description;

  /// When it is wanted by. Null for a duty with no date on it, which is most.
  final DateTime? dueOn;

  final int sortOrder;

  factory ModuleTask.fromMap(Map<String, dynamic> map) => ModuleTask(
    id: map['id'] as String,
    scope: TaskScope.fromDb(map['scope'] as String?),
    roleId: map['role_id'] as String?,
    title: LocalizedName.fromMap(map, prefix: 'title'),
    description: map['description_ar'] == null
        ? null
        : LocalizedName.fromMap(map, prefix: 'description'),
    dueOn: map['due_on'] == null
        ? null
        : DateTime.tryParse(map['due_on'] as String),
    sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
  );
}

/// The duties of one file, split the way the screen reads them: the file's
/// own list first, then each post's, in the order they were written.
class ModuleTaskList {
  const ModuleTaskList({this.tasks = const []});

  static const empty = ModuleTaskList();

  final List<ModuleTask> tasks;

  bool get isEmpty => tasks.isEmpty;

  List<ModuleTask> get fileTasks =>
      tasks.where((t) => t.scope == TaskScope.file).toList();

  /// The role duties, gathered by post, in the order the rows returned.
  Map<String, List<ModuleTask>> get byRole {
    final groups = <String, List<ModuleTask>>{};
    for (final task in tasks) {
      final roleId = task.roleId;
      if (task.scope != TaskScope.role || roleId == null) continue;
      (groups[roleId] ??= []).add(task);
    }
    return groups;
  }
}
