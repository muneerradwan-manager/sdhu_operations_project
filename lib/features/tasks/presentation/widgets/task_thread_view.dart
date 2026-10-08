import 'package:flutter/material.dart';

import '../../../../core/attachments/attachment_picker.dart';
import '../../../../core/attachments/attachments_view.dart';
import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/glass_tokens.dart';
import '../../../../core/widgets/info_section.dart';
import '../../domain/personal_task.dart';
import '../../domain/task_thread.dart';
import 'task_state_widgets.dart';

/// What went on with a task, in one column, oldest first.
///
/// Said and happened together, and that is the whole design of it. Under 0105
/// there was one `note` field and each state change overwrote it, so the
/// commonest thing a person needed — «لماذا تأخّرت؟» — was answered by whatever
/// sentence happened to be last. Here every line stays, and a transition that
/// carried words is drawn as ONE line rather than two, because «أعادها وقال:
/// الكشف ناقص» is one act.
class TaskThreadView extends StatelessWidget {
  const TaskThreadView({
    super.key,
    required this.entries,
    required this.signer,
  });

  final List<TaskThreadEntry> entries;
  final Future<String> Function(String path, {bool download, String? downloadName})
  signer;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Text(
          context.l10n.taskThreadEmpty,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < entries.length; i++)
          _Entry(
            entry: entries[i],
            isLast: i == entries.length - 1,
            signer: signer,
          ),
      ],
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({
    required this.entry,
    required this.isLast,
    required this.signer,
  });

  final TaskThreadEntry entry;
  final bool isLast;
  final Future<String> Function(String path, {bool download, String? downloadName})
  signer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l = context.l10n;
    final colour = _colour(scheme);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The spine: a dot per line, and a rule joining it to the next. Drawn
          // rather than indented, because what this column has to say first is
          // that these things happened IN ORDER.
          SizedBox(
            width: 20,
            child: Column(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  margin: const EdgeInsets.only(top: 5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: entry.isSpeech ? colour : scheme.surface,
                    border: Border.all(color: colour, width: 1.5),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: scheme.outlineVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          entry.actorName ?? l.taskBySystem,
                          style: text.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: entry.actorName == null
                                ? scheme.onSurfaceVariant
                                : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        formatDateTime(entry.createdAt),
                        style: text.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),

                  Text(
                    _what(context),
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),

                  // The words, in a surface of their own. Everything above this
                  // is the system describing an act; this is a person speaking,
                  // and the two must not read as one paragraph.
                  if (entry.isSpeech) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: colour.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: BorderDirectional(
                          start: BorderSide(color: colour, width: 2),
                        ),
                      ),
                      child: Text(
                        entry.body!.trim(),
                        style: text.bodyMedium?.copyWith(height: 1.6),
                      ),
                    ),
                  ],

                  if (entry.attachments.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    AttachmentsView(
                      attachments: entry.attachments,
                      signer: signer,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _colour(ColorScheme scheme) {
    final to = entry.toState;
    if (to != null) return taskStateColor(scheme, to);
    return switch (entry.kind) {
      TaskEntryKind.escalated => scheme.error,
      TaskEntryKind.comment => scheme.primary,
      _ => scheme.onSurfaceVariant,
    };
  }

  /// One line saying what this was. The state's own label is reused rather than
  /// a second vocabulary invented for the log — a person reading «نقلها إلى:
  /// بانتظار القبول» here and seeing «بانتظار القبول» on the chip above is
  /// reading the same words about the same thing.
  String _what(BuildContext context) {
    final l = context.l10n;
    return switch (entry.kind) {
      TaskEntryKind.created => l.taskEventCreated,
      TaskEntryKind.state => l.taskEventStateTo(
        taskStateLabel(context, entry.toState ?? TaskState.notStarted),
      ),
      TaskEntryKind.reassigned => l.taskEventReassigned,
      TaskEntryKind.due =>
        entry.payload['to'] == null
            ? l.taskEventDueCleared
            : l.taskEventDue(
                formatDate(DateTime.tryParse(entry.payload['to'] as String)),
              ),
      TaskEntryKind.priority => l.taskEventPriority(
        taskPriorityLabel(
          context,
          TaskPriority.fromDb(entry.payload['to'] as String?),
        ),
      ),
      TaskEntryKind.escalated => l.taskEventEscalated,
      TaskEntryKind.comment => '',
    };
  }
}

/// The box a person types into, with whatever they are attaching to it.
///
/// Sits at the foot of the detail page rather than behind a button: the
/// commonest thing anybody does on that page after reading it is answer, and a
/// reply hidden behind a plus is a reply that does not get written.
class TaskCommentBox extends StatefulWidget {
  const TaskCommentBox({
    super.key,
    required this.onSend,
    required this.onAttach,
    this.attachments = const [],
    this.onRemoveAttachment,
    this.busy = false,
  });

  final Future<void> Function(String body) onSend;
  final VoidCallback onAttach;
  final List<PendingAttachment> attachments;
  final void Function(int index)? onRemoveAttachment;
  final bool busy;

  @override
  State<TaskCommentBox> createState() => _TaskCommentBoxState();
}

class _TaskCommentBoxState extends State<TaskCommentBox> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty && widget.attachments.isEmpty) return;
    await widget.onSend(body);
    if (mounted) _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < widget.attachments.length; i++)
          PendingAttachmentRow(
            attachment: widget.attachments[i],
            onRemove: widget.busy || widget.onRemoveAttachment == null
                ? null
                : () => widget.onRemoveAttachment!(i),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              tooltip: l.taskEvidence,
              onPressed: widget.busy ? null : widget.onAttach,
              icon: const Icon(AppIcons.attach, size: 20),
            ),
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: !widget.busy,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: l.taskCommentHint,
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton.filled(
              tooltip: l.taskCommentSend,
              onPressed: widget.busy ? null : _send,
              icon: const Icon(AppIcons.send, size: 18),
            ),
          ],
        ),
      ],
    );
  }
}
