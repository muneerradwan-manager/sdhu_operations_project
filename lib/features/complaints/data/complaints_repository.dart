import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/storage_key.dart';
import '../../../core/supabase/supabase_client.dart';
import '../domain/complaint.dart';

/// Everything this feature asks of the server.
///
/// Almost all of it goes through RPCs rather than through `from('complaints')`,
/// and that is the point rather than an accident: the employee a complaint is
/// about has no read on the table at all — row security cannot hide a column,
/// so it hides the row — and reaches his own case only through functions that
/// return the words and the files and no name. See migration 0079.
class ComplaintsRepository {
  static const _bucket = 'complaints';

  /// How much of the register one read carries. The table grows for as long as
  /// the mission does, and neither the list nor a person needs all of it.
  static const listLimit = 100;

  // ------------------------------------------------------------------ reading

  /// The register. [all] is everyone's and asks for `complaints.view`; without
  /// it, this is what the caller filed.
  Future<List<Complaint>> fetchList({
    bool all = false,
    ComplaintTarget? target,
    String? targetId,
    bool includeDismissed = true,
    String? query,
  }) async {
    final rows = await supabase.rpc(
      'complaints_list',
      params: {
        'p_scope': all ? 'all' : 'mine',
        'p_target_type': target?.name,
        'p_target_id': targetId,
        'p_include_dismissed': includeDismissed,
        'p_query': query,
        'p_limit': listLimit,
      },
    );
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Complaint.fromListRow)
        .toList();
  }

  /// What was filed about the caller. Takes no id, because there is no other
  /// person it could be asked about — which is a stronger guarantee than a
  /// check that it is being asked about the right one.
  Future<List<Complaint>> fetchAgainstMe() async {
    final rows = await supabase.rpc(
      'complaints_against_me',
      params: {'p_limit': listLimit},
    );
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(Complaint.fromAgainstMeRow)
        .toList();
  }

  /// The complaint and every reply, in order, each bubble named only to a
  /// reader who may know it.
  Future<List<ComplaintMessage>> fetchThread(String complaintId) async {
    final rows = await supabase.rpc(
      'complaint_thread',
      params: {'p_complaint_id': complaintId},
    );
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(ComplaintMessage.fromMap)
        .toList();
  }

  /// Counts about one employee — never a name. Answers for the caller himself
  /// too, which is what the panel on his own page reads.
  Future<ComplaintStanding> fetchStanding(String profileId) async {
    final rows = await supabase.rpc(
      'complaints_against',
      params: {'p_profile_id': profileId},
    );
    final list = (rows as List).cast<Map<String, dynamic>>();
    if (list.isEmpty) return const ComplaintStanding();
    return ComplaintStanding.fromMap(list.first);
  }

  /// A short-lived link to an attachment. Signing goes through row security, so
  /// nobody outside the complaint can mint one.
  Future<String> signedUrl(
    String path, {
    int expiresInSeconds = 3600,
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

  // ------------------------------------------------------------------ writing

  /// Files one, and returns its id.
  ///
  /// The row is written first because the files are filed under it: the storage
  /// rule finds the complaint by the first folder of the path, so an upload
  /// that arrives before the row does is refused. Same order as a notification
  /// (see `notifications_repository.dart`).
  Future<String> file({
    required ComplaintTarget target,
    String? targetId,
    required String body,
    List<PendingAttachment> attachments = const [],
  }) async {
    final id =
        await supabase.rpc(
              'file_complaint',
              params: {
                'p_target_type': target.name,
                'p_target_id': target.needsTarget ? targetId : null,
                'p_body': body,
              },
            )
            as String;

    await _upload(complaintId: id, attachments: attachments);
    return id;
  }

  /// Replies, and returns the reply's id. Unbounded in number: nothing here or
  /// in the database counts them.
  Future<String> reply({
    required String complaintId,
    required String body,
    List<PendingAttachment> attachments = const [],
  }) async {
    final replyId =
        await supabase.rpc(
              'reply_to_complaint',
              params: {'p_complaint_id': complaintId, 'p_body': body},
            )
            as String;

    await _upload(
      complaintId: complaintId,
      replyId: replyId,
      attachments: attachments,
    );
    return replyId;
  }

  Future<void> setLocked(String complaintId, bool locked) async {
    await supabase.rpc(
      'set_complaint_lock',
      params: {'p_complaint_id': complaintId, 'p_locked': locked},
    );
  }

  Future<void> setDismissed(
    String complaintId,
    bool dismissed, {
    String? reason,
  }) async {
    await supabase.rpc(
      'set_complaint_dismissed',
      params: {
        'p_complaint_id': complaintId,
        'p_dismissed': dismissed,
        'p_reason': reason,
      },
    );
  }

  Future<void> delete(String complaintId) async {
    await supabase.from('complaints').delete().eq('id', complaintId);
  }

  /// Uploads under the complaint, and under the reply when there is one.
  ///
  /// The reply's folder nests inside the complaint's so that the first folder
  /// is always the complaint — one read rule then covers everything it owns.
  /// Nothing in the path names the person who uploaded it: a path is readable
  /// by the employee the complaint is about.
  Future<void> _upload({
    required String complaintId,
    String? replyId,
    required List<PendingAttachment> attachments,
  }) async {
    if (attachments.isEmpty) return;
    final folder = replyId == null
        ? complaintId
        : '$complaintId/replies/$replyId';

    final rows = <Map<String, dynamic>>[];
    for (var i = 0; i < attachments.length; i++) {
      final attachment = attachments[i];
      // Prefixed with the index: two photos straight from a camera roll can
      // arrive with the same name, and the second must not replace the first.
      final path = '$folder/${i}_${storageKey(attachment.name, fallback: '$i')}';
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
        'complaint_id': complaintId,
        'reply_id': replyId,
        'kind': attachment.kind.name,
        'path': path,
        'name': attachment.name,
        'mime_type': attachment.mimeType,
        'size_bytes': attachment.file.lengthSync(),
        'sort_order': i,
      });
    }
    await supabase.from('complaint_attachments').insert(rows);
  }

  // ------------------------------------------------------- what may be complained about

  /// What a complaint of this kind may be filed against — an id, a name, and a
  /// face where there is one.
  ///
  /// Through an RPC rather than off the tables, and for the reason this whole
  /// repository goes through RPCs: reading `profiles` gets an ordinary employee
  /// the people he shares a file with and nobody else, so the form offered him
  /// an empty list and no way to name the person he came to complain about.
  /// Filing takes no permission, and neither does this. Three columns come
  /// back — never the directory behind them. See migration 0082.
  Future<List<ComplaintTargetOption>> fetchTargets(
    ComplaintTarget target, {
    String? query,
  }) async {
    if (!target.needsTarget) return const [];
    final rows = await supabase.rpc(
      'complaint_targets',
      params: {
        'p_target_type': target.name,
        'p_query': query,
        'p_limit': listLimit,
      },
    );
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(
          (row) => (
            id: row['id'] as String,
            name: (row['name'] as String?) ?? '',
            photoUrl: row['photo_url'] as String?,
          ),
        )
        .toList();
  }
}
