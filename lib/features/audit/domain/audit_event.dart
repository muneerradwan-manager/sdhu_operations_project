import 'package:equatable/equatable.dart';

/// What kind of act a line records. Mirrors the CHECK constraint on
/// `audit_log.action` (migration 0077).
enum AuditAction {
  insert,
  update,
  delete,
  login,
  logout;

  static AuditAction fromName(String? name) => AuditAction.values.firstWhere(
    (a) => a.name == name,
    orElse: () => AuditAction.update,
  );
}

/// One line of the log: who did what, to which row, and what exactly moved.
///
/// The actor arrives twice over: [actorName] is resolved server-side to the
/// CURRENT profile when it still exists, falling back to the snapshot taken
/// when the event happened — so a deleted account keeps its name in history.
class AuditEvent extends Equatable {
  const AuditEvent({
    required this.id,
    required this.occurredAt,
    required this.action,
    required this.tableName,
    this.actorId,
    this.actorName,
    this.actorPhotoUrl,
    this.recordId,
    this.recordLabel,
    this.oldData,
    this.newData,
    this.changedFields = const [],
  });

  final int id;
  final DateTime occurredAt;
  final AuditAction action;
  final String tableName;
  final String? actorId;
  final String? actorName;
  final String? actorPhotoUrl;
  final String? recordId;
  final String? recordLabel;
  final Map<String, dynamic>? oldData;
  final Map<String, dynamic>? newData;
  final List<String> changedFields;

  /// Account-level acts (sign-in/out, and what the Edge Functions do under
  /// the service role) are filed under the pseudo-table `auth`.
  bool get isAuthEvent => tableName == 'auth';

  /// Which account act this is: `create_user`, `delete_user`, `set_password`,
  /// `set_email` — or null for a plain login/logout.
  String? get authOp =>
      (newData?['op'] ?? oldData?['op']) as String?;

  /// How many inboxes a notification insert landed in (statement-level line).
  int? get recipients => (newData?['recipients'] as num?)?.toInt();

  static AuditEvent fromMap(Map<String, dynamic> map) {
    return AuditEvent(
      id: (map['id'] as num).toInt(),
      occurredAt: DateTime.parse(map['occurred_at'] as String).toLocal(),
      action: AuditAction.fromName(map['action'] as String?),
      tableName: (map['table_name'] as String?) ?? '',
      actorId: map['actor_id'] as String?,
      actorName: map['actor_name'] as String?,
      actorPhotoUrl: map['actor_photo_url'] as String?,
      recordId: map['record_id'] as String?,
      recordLabel: map['record_label'] as String?,
      oldData: (map['old_data'] as Map?)?.cast<String, dynamic>(),
      newData: (map['new_data'] as Map?)?.cast<String, dynamic>(),
      changedFields:
          (map['changed_fields'] as List?)?.cast<String>() ?? const [],
    );
  }

  @override
  List<Object?> get props => [id];
}

/// Somebody who appears in the log — the option list of the "by person"
/// filter.
class AuditActor extends Equatable {
  const AuditActor({required this.id, this.name, this.photoUrl});

  final String id;
  final String? name;
  final String? photoUrl;

  static AuditActor fromMap(Map<String, dynamic> map) => AuditActor(
    id: map['actor_id'] as String,
    name: map['actor_name'] as String?,
    photoUrl: map['photo_url'] as String?,
  );

  @override
  List<Object?> get props => [id];
}

/// A season the log actually holds lines for — one option of the season filter.
///
/// Only the seasons with something in the log are offered. 0109 prunes the log
/// to two years, so a list built from `seasons` alone would offer 1445 and then
/// answer "nothing" — a choice whose only possible outcome is an empty page is
/// not a choice.
class AuditSeason extends Equatable {
  const AuditSeason({
    required this.id,
    required this.hijriYear,
    required this.count,
  });

  final String id;
  final int hijriYear;

  /// How many lines belong to it, shown beside the year so a reader choosing
  /// between two seasons knows which one the work is in.
  final int count;

  static AuditSeason fromMap(Map<String, dynamic> map) => AuditSeason(
    id: map['season_id'] as String,
    hijriYear: (map['hijri_year'] as num?)?.toInt() ?? 0,
    count: (map['n'] as num?)?.toInt() ?? 0,
  );

  @override
  List<Object?> get props => [id];
}
