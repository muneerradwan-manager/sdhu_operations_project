import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/error_text.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/offline/outbox.dart';
import '../../../core/offline/outbox_entry.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/states.dart';
import '../../modules/data/module_outbox.dart';
import '../../tasks/data/tasks_outbox.dart';

/// What the app is holding on the person's behalf, and the two things he is
/// allowed to decide about it.
///
/// He may **try again** — for the entry that gave up after eight failures and
/// is now waiting on a human rather than on a radio — and he may **throw it
/// away**. Nothing else: the queue sends itself, and a screen offering to send
/// it would be offering to do what is already happening.
///
/// The right to discard is the important one and belongs to him alone. It is
/// his work; if the app decided when to give up on it, the app would be
/// deciding that a camp went uninspected.
class OutboxScreen extends StatelessWidget {
  const OutboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    // Where there is no disk there is no queue — see `_installOutbox`. The
    // badge that opens this screen is already hidden there, so this is the
    // route being typed or restored rather than anybody arriving by tapping.
    if (!Outbox.isInstalled) {
      return Scaffold(
        // Glass, like every other bar — this screen was the one still wearing
        // the Material default.
        appBar: GlassAppBar(title: Text(l.outboxTitle)),
        body: EmptyState(
          icon: AppIcons.outbox,
          title: l.outboxEmpty,
          message: l.outboxEmptyHint,
        ),
      );
    }
    final outbox = Outbox.instance;

    return Scaffold(
      appBar: GlassAppBar(title: Text(l.outboxTitle)),
      body: StreamBuilder<List<OutboxEntry>>(
        stream: outbox.changes,
        initialData: outbox.entries,
        builder: (context, snap) {
          final entries = snap.data ?? const <OutboxEntry>[];
          if (entries.isEmpty) {
            return EmptyState(
              icon: AppIcons.outbox,
              title: l.outboxEmpty,
              message: l.outboxEmptyHint,
            );
          }
          return ResponsivePage(
            builder: (context, size) => SinglePaneLayout(
              gutter: size.gutter,
              children: [
                for (final entry in entries)
                  _EntryCard(entry: entry, outbox: outbox),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({required this.entry, required this.outbox});

  final OutboxEntry entry;
  final Outbox outbox;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final kind = switch (entry.kind) {
      TasksOutbox.state => l.outboxKindTaskState,
      // The pre-0105 name, kept matchable: an entry queued by last week's
      // build still deserves its label even though nothing writes it now.
      'module.task_state' => l.outboxKindTaskState,
      ModuleOutbox.report => l.outboxKindReport,
      // A kind this build does not know — an entry written by a newer one, or
      // an operation since removed. Named by its key rather than hidden: the
      // person can still see that something of his is here and throw it away.
      _ => entry.kind,
    };

    final stateLabel = switch (entry.status) {
      OutboxStatus.sending => l.outboxStateSending,
      OutboxStatus.blocked => l.outboxStateBlocked,
      OutboxStatus.waiting => l.outboxStateWaiting,
    };
    final tone = entry.isBlocked ? scheme.error : scheme.tertiary;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // The framed glyph every card leads with, in the entry's own
                  // state colour — a blocked entry is findable down the edge of
                  // the list before a word is read.
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: tone.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                      border: Border.all(color: tone.withValues(alpha: 0.18)),
                    ),
                    child: Icon(
                      entry.isBlocked ? AppIcons.warning : AppIcons.outbox,
                      size: 19,
                      color: tone,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.label == null ? kind : '$kind — ${entry.label}',
                          style: text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$stateLabel · '
                          '${DateFormat.yMd().add_jm().format(entry.createdAt)}',
                          style: text.bodySmall?.copyWith(
                            color: entry.isBlocked
                                ? scheme.error
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (entry.files.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    l.notificationAttachmentsCount(entry.files.length),
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              // Only for an entry that has stopped trying. While it is merely
              // waiting, the last error is the network being down, and saying
              // so to a man who can see his own signal bars is noise.
              if (entry.isBlocked && entry.lastError != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    friendlyError(context, entry.lastError),
                    style: text.bodySmall?.copyWith(color: scheme.error),
                  ),
                ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (entry.isBlocked)
                    TextButton.icon(
                      onPressed: () => outbox.retry(entry.id),
                      icon: const Icon(AppIcons.retry, size: 16),
                      label: Text(l.outboxRetry),
                    ),
                  TextButton.icon(
                    onPressed: () => _confirmDiscard(context),
                    icon: const Icon(AppIcons.delete, size: 16),
                    label: Text(l.outboxDiscard),
                    style: TextButton.styleFrom(foregroundColor: scheme.error),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDiscard(BuildContext context) async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.outboxDiscardTitle),
        content: Text(l.outboxDiscardBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l.outboxDiscard),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await outbox.discard(entry.id);
  }
}
