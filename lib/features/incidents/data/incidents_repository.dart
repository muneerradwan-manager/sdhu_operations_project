import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/attachments/attachment.dart';
import '../../../core/supabase/storage_key.dart';
import '../../../core/supabase/supabase_client.dart';
import '../domain/incident.dart';

/// Raising urgent reports, and working through them.
class IncidentsRepository {
  static const _bucket = 'incidents';

  /// Raises one and alerts the operations room in the same transaction.
  ///
  /// The alarm is sent by the database rather than from here, and that is the
  /// point of the RPC: if the row exists, the room has been told. A client that
  /// wrote the row and then died before sending the notification would produce
  /// the one failure this feature cannot have — a recorded emergency nobody
  /// knows about.
  Future<String> raise({
    required String body,
    String? moduleId,
    String? nodeId,
    String? subjectProfileId,
    String? appRoute,
    String? appLabel,
    double? latitude,
    double? longitude,
    double? accuracy,
    List<PendingAttachment> attachments = const [],
  }) async {
    final id = await supabase.rpc(
      'raise_incident',
      params: {
        'p_body': body,
        'p_module_id': moduleId,
        'p_node_id': nodeId,
        'p_lat': latitude,
        'p_lng': longitude,
        'p_accuracy': accuracy,
        // What the report is about, when the reporter said. All three are
        // optional and the RPC drops a subject that is the caller himself; see
        // 0120.
        'p_subject_profile_id': subjectProfileId,
        'p_app_route': appRoute,
        'p_app_label': appLabel,
      },
    ) as String;

    // Attachments AFTER the alarm, never before. A photograph is worth having
    // and is worth nothing compared to the minute it would cost to upload
    // before anybody is told — and on a field network that minute can be five.
    if (attachments.isNotEmpty) {
      await _attach(id, attachments);
    }
    return id;
  }

  Future<void> _attach(
    String incidentId,
    List<PendingAttachment> attachments,
  ) async {
    final rows = <Map<String, dynamic>>[];
    var index = -1;
    for (final attachment in attachments) {
      index++;
      final path =
          '$incidentId/${index}_'
          '${storageKey(attachment.name, fallback: '$index')}';
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
        'incident_id': incidentId,
        'kind': attachment.kind.name,
        'path': path,
        'name': attachment.name,
        'mime_type': attachment.mimeType,
        'size_bytes': attachment.file.lengthSync(),
        'sort_order': index,
      });
    }
    await supabase.from('incident_attachments').insert(rows);
  }

  /// The register. Open ones first, oldest first within that.
  ///
  /// [mineOnly] asks a DIFFERENT question from the default, not a narrower
  /// one. Without it, what comes back depends on who is calling: the room
  /// sees everyone's, an ordinary reporter sees only their own — a fact of
  /// the predicate `incidents_list` has always evaluated, not a promise it
  /// made. `مين، بلاغاتي` needs the promise: a supervisor who both answers
  /// the register AND once raised a report of his own must get back exactly
  /// what he filed, not the whole season's register with his row somewhere
  /// inside it — see 0126.
  Future<List<Incident>> fetchList({
    bool includeClosed = false,
    int limit = 100,
    bool mineOnly = false,
  }) async {
    final rows = await supabase.rpc(
      'incidents_list',
      params: {
        'p_include_closed': includeClosed,
        'p_limit': limit,
        'p_mine_only': mineOnly,
      },
    );
    return ((rows as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map(Incident.fromRow)
        .toList();
  }

  Future<void> setState({
    required String incidentId,
    required IncidentState state,
    String? resolution,
  }) => supabase.rpc(
    'set_incident_state',
    params: {
      'p_incident_id': incidentId,
      'p_state': state.dbName,
      'p_resolution': resolution,
    },
  );

  /// Strikes one off the register (0121).
  ///
  /// The RPC hands back the storage paths its cascade orphaned, because nothing
  /// in Postgres owns objects in a bucket: the attachment ROWS go with the
  /// incident and the photographs would stay behind forever, in a private
  /// bucket, readable by nobody and paid for indefinitely.
  Future<void> delete(String incidentId) async {
    final paths = await supabase.rpc(
      'delete_incident',
      params: {'p_incident_id': incidentId},
    );
    await _sweep(paths);
  }

  /// Empties it. [onlyClosed] false takes the open ones too — see
  /// `delete_all_incidents`, where that is the argument the caller has to make
  /// deliberately. Returns how many rows went.
  Future<int> deleteAll({bool onlyClosed = true}) async {
    final rows = await supabase.rpc(
      'delete_all_incidents',
      params: {'p_only_closed': onlyClosed},
    );
    // A `returns table` RPC comes back as a list of one row.
    final row = ((rows as List?) ?? const []).cast<Map<String, dynamic>>();
    if (row.isEmpty) return 0;
    await _sweep(row.first['paths']);
    return (row.first['deleted'] as int?) ?? 0;
  }

  /// Removes the orphaned objects. Deliberately swallowed: the row is already
  /// gone and the register is already right, and a bucket call that failed is
  /// not something to put in front of somebody who just deleted a report.
  Future<void> _sweep(Object? paths) async {
    final list = ((paths as List?) ?? const []).cast<String>();
    if (list.isEmpty) return;
    try {
      await supabase.storage.from(_bucket).remove(list);
    } catch (_) {}
  }
}
