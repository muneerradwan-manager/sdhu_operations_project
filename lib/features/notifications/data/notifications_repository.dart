import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/attachments/attachments_view.dart' show AttachmentSigner;
import '../../../core/supabase/storage_key.dart';
import '../../../core/supabase/supabase_client.dart';
import '../domain/app_notification.dart';

class NotificationsRepository {
  static const _bucket = 'notifications';

  /// The other bucket this screen reads from. An urgent report's evidence stays
  /// with the report — see [AppNotification.incidentId] — and the inbox signs
  /// for it rather than having it copied over.
  static const _incidentsBucket = 'incidents';

  /// How much of the inbox one read carries. The table grows for as long as
  /// the account lives; without a ceiling every open of the inbox — and every
  /// Realtime emission — hauled the whole history over the wire.
  static const inboxLimit = 100;

  /// Realtime stream of the signed-in user's notifications, newest first.
  ///
  /// Attachments are not in it: a Supabase stream is a single table and cannot
  /// carry a joined one. [fetchAttachments] fills them in after each emission.
  Stream<List<AppNotification>> streamMine() {
    final uid = supabase.auth.currentUser?.id;
    return supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('recipient_id', uid ?? '')
        .order('created_at')
        .limit(inboxLimit)
        .map((rows) {
          final list = rows.map(AppNotification.fromMap).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// One read of the inbox, newest first.
  ///
  /// The stream is the usual source, but it only re-reads when Realtime says
  /// something changed. This is what pull-to-refresh and "I just sent that"
  /// call, so the list is right even when the socket is not.
  Future<List<AppNotification>> fetchMine() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return const [];
    final rows = await supabase
        .from('notifications')
        .select()
        .eq('recipient_id', uid)
        .order('created_at', ascending: false)
        .limit(inboxLimit);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(AppNotification.fromMap)
        .toList();
  }

  /// The attachments of [groupIds], keyed by group. One query for the whole
  /// inbox rather than one per row.
  ///
  /// Keyed on the GROUP because a broadcast is one upload read by everyone it
  /// went to — five hundred recipients share one file, not five hundred copies.
  Future<Map<String, List<NotificationAttachment>>> fetchAttachments(
    List<String> groupIds,
  ) => _attachmentsBy(
    table: 'notification_attachments',
    column: 'group_id',
    ids: groupIds,
  );

  /// The evidence of [incidentIds], keyed by incident. Same shape, another
  /// table: a "بلاغ عاجل" carries nothing of its own, and what the reader is
  /// meant to look at is filed under the report it announces.
  ///
  /// Readable without a migration, and by exactly the right people: the row
  /// policy on `incident_attachments` and the storage rule behind the bucket
  /// both admit whoever holds `incidents.receive` — which is who these
  /// notifications went to in the first place.
  Future<Map<String, List<NotificationAttachment>>> fetchIncidentAttachments(
    List<String> incidentIds,
  ) => _attachmentsBy(
    table: 'incident_attachments',
    column: 'incident_id',
    ids: incidentIds,
  );

  /// One query for a whole inbox's worth of files, grouped by what owns them.
  ///
  /// `ascending` is stated rather than left off: PostgREST's Dart client
  /// defaults `order` to DESCENDING, so the un-flagged call that used to be
  /// here handed back every set of photographs backwards — the last thing
  /// somebody photographed shown as the first thing they did.
  Future<Map<String, List<NotificationAttachment>>> _attachmentsBy({
    required String table,
    required String column,
    required List<String> ids,
  }) async {
    if (ids.isEmpty) return const {};
    final rows = await supabase
        .from(table)
        .select()
        .inFilter(column, ids)
        .order('sort_order', ascending: true);

    final byOwner = <String, List<NotificationAttachment>>{};
    for (final row in (rows as List).cast<Map<String, dynamic>>()) {
      (byOwner[row[column] as String] ??= []).add(
        NotificationAttachment.fromMap(row),
      );
    }
    return byOwner;
  }

  /// A short-lived link to an attachment. Signing goes through RLS, so nobody
  /// but the recipient can mint one.
  ///
  /// [download] asks storage to serve it as a download named [downloadName]
  /// rather than rendering it in place — which is the difference between
  /// "open the photo" and "save the photo".
  Future<String> signedUrl(
    String path, {
    int expiresInSeconds = 3600,
    bool download = false,
    String? downloadName,
  }) => _signedUrl(
    _bucket,
    path,
    expiresInSeconds: expiresInSeconds,
    download: download,
    downloadName: downloadName,
  );

  /// The same, for a file that belongs to an urgent report.
  Future<String> signedIncidentUrl(
    String path, {
    int expiresInSeconds = 3600,
    bool download = false,
    String? downloadName,
  }) => _signedUrl(
    _incidentsBucket,
    path,
    expiresInSeconds: expiresInSeconds,
    download: download,
    downloadName: downloadName,
  );

  /// Which bucket to sign [n]'s files against.
  ///
  /// Asked of the notification rather than of the path, because the two buckets
  /// lay their files out identically — `{id}/{i}_{name}` — and nothing in a
  /// path says which one it came out of. What the row is ABOUT is the only
  /// thing that knows.
  AttachmentSigner signerFor(AppNotification n) =>
      n.incidentId == null ? signedUrl : signedIncidentUrl;

  Future<String> _signedUrl(
    String bucket,
    String path, {
    required int expiresInSeconds,
    required bool download,
    required String? downloadName,
  }) {
    return supabase.storage
        .from(bucket)
        .createSignedUrl(path, expiresInSeconds)
        .then((url) {
          if (!download) return url;
          // Storage honours a `download` query parameter, and its value becomes
          // the file name the device saves it under.
          final separator = url.contains('?') ? '&' : '?';
          final name = Uri.encodeComponent(downloadName ?? '');
          return '$url${separator}download${name.isEmpty ? '' : '=$name'}';
        });
  }

  Future<void> markRead(String id) async {
    await supabase
        .from('notifications')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('id', id)
        .filter('read_at', 'is', null);
  }

  /// Marks a named set read, in one write.
  ///
  /// Exists because the inbox can now be looked at a half at a time. "تعليم
  /// الكل كمقروء" pressed while the alarms are on screen has to mean the alarms
  /// — marking the announcements too, silently, off a button labelled "الكل"
  /// while they are not visible, is the app clearing something the reader never
  /// saw.
  Future<void> markManyRead(List<String> ids) async {
    if (ids.isEmpty) return;
    await supabase
        .from('notifications')
        .update({'read_at': DateTime.now().toIso8601String()})
        .inFilter('id', ids)
        .filter('read_at', 'is', null);
  }

  Future<void> markAllRead() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    await supabase
        .from('notifications')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('recipient_id', uid)
        .filter('read_at', 'is', null);
  }

  /// Sends a notification to [recipientId], with whatever was attached to it.
  ///
  /// The row is created first: the files are filed under its id, so it has to
  /// exist before they can go anywhere. Also invokes the push Edge Function —
  /// best-effort, the inbox row is the source of truth.
  Future<void> send({
    required String recipientId,
    required String title,
    String? body,
    List<PendingAttachment> attachments = const [],
  }) async {
    final senderId = supabase.auth.currentUser?.id;
    final row = await supabase
        .from('notifications')
        .insert({
          'recipient_id': recipientId,
          'sender_id': senderId,
          'title': title,
          'body': body,
        })
        .select('id, group_id')
        .single();
    final id = row['group_id'] as String;

    if (attachments.isNotEmpty) {
      final rows = <Map<String, dynamic>>[];
      for (var i = 0; i < attachments.length; i++) {
        final attachment = attachments[i];
        // Prefixed with the index: two photos straight from a camera roll can
        // arrive with the same name, and the second must not replace the first.
        final path = '$id/${i}_${storageKey(attachment.name, fallback: '$i')}';
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
          'group_id': id,
          'kind': attachment.kind.name,
          'path': path,
          'name': attachment.name,
          'mime_type': attachment.mimeType,
          'size_bytes': attachment.file.lengthSync(),
          'sort_order': i,
        });
      }
      await supabase.from('notification_attachments').insert(rows);
    }
  }

  /// Sends to everyone holding a role anywhere in [moduleId].
  ///
  /// The inbox rows are written by one statement inside the database, and the
  /// push is one call to the file topic. Neither cost grows with the number of
  /// members, which at five hundred is the whole point.
  Future<void> broadcastToModule({
    required String moduleId,
    required String title,
    String? body,
    List<PendingAttachment> attachments = const [],
  }) async {
    final groupId =
        await supabase.rpc(
              'broadcast_to_module',
              params: {
                'p_module_id': moduleId,
                'p_title': title,
                'p_body': body,
              },
            )
            as String;

    await _uploadAttachments(groupId, attachments);
  }

  /// Sends to every working account, or to one season's participants.
  Future<void> broadcastToAll({
    required String title,
    String? body,
    String? seasonId,
    List<PendingAttachment> attachments = const [],
  }) async {
    final groupId =
        await supabase.rpc(
              'broadcast_to_all',
              params: {
                'p_title': title,
                'p_body': body,
                'p_season_id': seasonId,
              },
            )
            as String;

    await _uploadAttachments(groupId, attachments);
  }

  /// Uploads once, under the group. Every recipient reads the same file.
  Future<void> _uploadAttachments(
    String groupId,
    List<PendingAttachment> attachments,
  ) async {
    if (attachments.isEmpty) return;
    final rows = <Map<String, dynamic>>[];
    for (var i = 0; i < attachments.length; i++) {
      final attachment = attachments[i];
      // Prefixed with the index: two photos straight from a camera roll can
      // arrive with the same name, and the second must not replace the first.
      final path = '$groupId/${i}_${storageKey(attachment.name, fallback: '$i')}';
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
        'group_id': groupId,
        'kind': attachment.kind.name,
        'path': path,
        'name': attachment.name,
        'mime_type': attachment.mimeType,
        'size_bytes': attachment.file.lengthSync(),
        'sort_order': i,
      });
    }
    await supabase.from('notification_attachments').insert(rows);
  }

  // Nothing here pushes any more, and that is the point of migration 0107.
  //
  // This class used to call `send-notification` itself after each of the three
  // sends above. It worked, and it was the ONLY thing in the system that ever
  // reached a phone — so the nine places where the DATABASE writes a
  // notification (an incident, an escalation at 3am, a task assignment, a
  // complaint, an evaluation, a posting) woke nobody. The inbox filled and
  // waited to be found.
  //
  // A trigger on `notifications` now pushes every row, whoever wrote it, once
  // per `group_id` — so this had to go, or every manual send would ring twice.
  // Push became the server's job in full, which is what §17.3 always said it
  // should be.
  //
  // One consequence worth stating: the push is queued when the ROW is written,
  // which for a send carrying attachments is a moment before the upload
  // finishes. Nothing is lost by that — the notification names its group and
  // the inbox reads attachments when it opens, long after — but the order is no
  // longer "attachments, then tell". It is "tell, then attachments".
}

/// The FCM topics this app uses. Kept beside the sender so the name a broadcast
/// pushes to and the name a device subscribes to cannot drift apart.
class PushTopics {
  const PushTopics._();

  static const all = 'all';

  static String module(String moduleId) => 'module_$moduleId';
}
