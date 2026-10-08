import '../../../core/offline/outbox.dart';
import '../../../core/offline/outbox_entry.dart';
import 'incidents_repository.dart';

/// An emergency that could not be sent, kept until it can be.
///
/// The most uncomfortable entry in the queue, and it is here for one reason:
/// the alternative is losing it. A man in a dead spot who reports a broken-down
/// bus and gets an error has nothing — he closes the app, and whatever he
/// writes later he will write from memory, if he writes it at all.
///
/// But keeping it must never be mistaken for sending it. Everywhere else in
/// this app the queue is a quiet convenience the person need not think about;
/// here the person MUST be told, in plain words, that nobody has been alerted
/// and that he should reach the operations room another way. That is what
/// [IncidentOutcome.waitingForNetwork] exists to force at every call site — the
/// queue cannot say it for itself, because by the time it runs he has put the
/// phone away.
///
/// Replaying is safe in the sense that matters: sending the same emergency
/// twice puts two rows in front of the operations room, which costs them a
/// second look and costs nobody anything else. Sending it none times is the
/// failure this exists to prevent.
abstract final class IncidentsOutbox {
  static const kind = 'incident.raise';

  static void register(Outbox outbox) => outbox.register(kind, _send);

  static Map<String, dynamic> payload({
    required String body,
    String? moduleId,
    String? nodeId,
    String? subjectProfileId,
    String? appRoute,
    String? appLabel,
    double? latitude,
    double? longitude,
    double? accuracy,
  }) => {
    'body': body,
    'module_id': moduleId,
    'node_id': nodeId,
    'subject_profile_id': subjectProfileId,
    'app_route': appRoute,
    // The label as well as the route, because a queued report is drained by a
    // background isolate with no localisations loaded and no way to name a
    // screen. It is what the reporter saw when he wrote it, which is the only
    // honest answer anyway — see 0120.
    'app_label': appLabel,
    'lat': latitude,
    'lng': longitude,
    'accuracy': accuracy,
  };

  static Future<void> _send(OutboxEntry entry) async {
    final payload = entry.payload;
    await IncidentsRepository().raise(
      body: payload['body'] as String,
      moduleId: payload['module_id'] as String?,
      nodeId: payload['node_id'] as String?,
      subjectProfileId: payload['subject_profile_id'] as String?,
      appRoute: payload['app_route'] as String?,
      appLabel: payload['app_label'] as String?,
      // The position recorded when the button was pressed, not wherever the
      // phone is now — which by the time this drains may be a different camp.
      latitude: (payload['lat'] as num?)?.toDouble(),
      longitude: (payload['lng'] as num?)?.toDouble(),
      accuracy: (payload['accuracy'] as num?)?.toDouble(),
      attachments: [for (final file in entry.files) file.pending],
    );
  }
}
