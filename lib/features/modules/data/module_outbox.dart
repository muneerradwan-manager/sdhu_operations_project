import '../../../core/attachments/attachment.dart';
import '../../../core/offline/outbox.dart';
import '../../../core/offline/outbox_entry.dart';
import 'modules_repository.dart';

/// The one write of an operational file that happens in the field, and what it
/// takes to send it again later: **filing the file's report**.
///
/// Everything else a file writes — building it, assigning its members, wording
/// its duty lists — is done sitting down, on a connection, by somebody who can
/// be told to try again. The report is done standing in a camp, and it carries
/// photographs a camp at eight in the evening will not pose for again at
/// eleven. (Moving a task along queues too, but tasks are personal since 0105
/// and their entry lives with the tasks feature.)
///
/// The knowledge of how to send it lives here rather than in the queue,
/// because the queue must not know what a module is; and beside the repository
/// rather than in the cubit, because a cubit belongs to a screen and this has
/// to run when there is no screen.
abstract final class ModuleOutbox {
  /// Named, never renamed: an entry written by last week's build is read by
  /// this one, and a kind it cannot match is work it cannot send.
  static const report = 'module.report';

  static void register(Outbox outbox) {
    outbox.register(report, _sendReport);
  }

  // ----------------------------------------------------------------- reports

  static Map<String, dynamic> reportPayload({
    required String moduleId,
    String? notes,
    List<StoredAttachment> removed = const [],
  }) => {
    'module_id': moduleId,
    'notes': notes,
    'removed': [for (final attachment in removed) attachment.toMap()],
  };

  static Future<void> _sendReport(OutboxEntry entry) async {
    final repo = ModulesRepository();
    final payload = entry.payload;

    await repo.submitReport(
      moduleId: payload['module_id'] as String,
      notes: payload['notes'] as String?,
      attachments: [for (final file in entry.files) file.pending],
      removed: _removed(payload),
    );
  }

  static List<StoredAttachment> _removed(Map<String, dynamic> payload) => [
    for (final row in (payload['removed'] as List?) ?? const [])
      StoredAttachment.fromMap((row as Map).cast<String, dynamic>()),
  ];
}
