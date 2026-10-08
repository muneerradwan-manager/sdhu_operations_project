import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/glass_tokens.dart';
import '../../../../core/widgets/glass.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../../../../core/widgets/states.dart';
import '../../domain/audit_event.dart';
import '../../domain/audit_labels.dart';
import 'audit_style.dart';

/// The whole account of one event: who, when, and — field by field — what the
/// row looked like before and after.
Future<void> showAuditEventSheet(BuildContext context, AuditEvent event) {
  return showModalBottomSheet<void>(
    context: context,
    // Over the rail as well as the page — see [showAppSheet].
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _Sheet(event: event),
  );
}

/// Bookkeeping columns say nothing a reader of a CHANGE needs; they clutter
/// the before/after of everything else. (They still show on inserts and
/// deletes, where "when was this created" is part of the record.)
const _noiseOnUpdate = {'updated_at', 'created_at'};

class _Sheet extends StatelessWidget {
  const _Sheet({required this.event});

  final AuditEvent event;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final color = auditActionColor(context, event.action);

    final sections = _sections(context);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: ListView(
        shrinkWrap: true,
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.12),
                ),
                child: Icon(
                  auditActionIcon(event.action),
                  size: 20,
                  color: color,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(auditTitle(context, event), style: text.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      auditSubtitle(context, event),
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          GlassCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: ProfileAvatar(
                photoUrl: event.actorPhotoUrl,
                name: event.actorName ?? l.auditSystem,
                radius: 20,
              ),
              title: Text(event.actorName ?? l.auditSystem),
              subtitle: Text(
                '${l.auditActor} • ${auditFmtTime(event.occurredAt)}',
              ),
            ),
          ),
          if (sections.isEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              l.auditNoDetails,
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ] else
            ...sections,
        ],
      ),
    );
  }

  List<Widget> _sections(BuildContext context) {
    final l = context.l10n;
    switch (event.action) {
      case AuditAction.update:
        final fields = event.changedFields
            .where((f) => !_noiseOnUpdate.contains(f))
            .toList();
        if (fields.isEmpty) return const [];
        return [
          const SizedBox(height: AppSpacing.md),
          SectionHeader(l.auditChanges),
          for (final field in fields)
            _ChangeRow(
              label: AuditLabels.field(field).of(context),
              oldValue: event.oldData?[field],
              newValue: event.newData?[field],
            ),
        ];
      case AuditAction.insert:
      case AuditAction.login:
        return _dataSection(context, l.auditRecordData, event.newData);
      case AuditAction.delete:
      case AuditAction.logout:
        return _dataSection(context, l.auditDeletedData, event.oldData);
    }
  }

  List<Widget> _dataSection(
    BuildContext context,
    String title,
    Map<String, dynamic>? data,
  ) {
    if (data == null) return const [];
    // Raw ids resolve to nothing a reader can use; the row's own id and the
    // `op` marker are already told by the headline.
    final entries = data.entries
        .where((e) => e.value != null && e.key != 'id' && e.key != 'op')
        .toList();
    if (entries.isEmpty) return const [];
    return [
      const SizedBox(height: AppSpacing.md),
      SectionHeader(title),
      for (final entry in entries)
        _ValueRow(
          label: AuditLabels.field(entry.key).of(context),
          value: entry.value,
        ),
    ];
  }
}

/// A field that moved: its name, what it said, what it says now.
class _ChangeRow extends StatelessWidget {
  const _ChangeRow({
    required this.label,
    required this.oldValue,
    required this.newValue,
  });

  final String label;
  final dynamic oldValue;
  final dynamic newValue;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    // Both sides empty happens once: the `content` pseudo-field standing for
    // a report's rewritten rows. The name alone says what it needs to.
    final hasValues = oldValue != null || newValue != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: text.labelMedium?.copyWith(
              color: scheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (hasValues) ...[
            const SizedBox(height: 2),
            Text(
              auditFmtValue(context, oldValue),
              style: text.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                decoration: TextDecoration.lineThrough,
              ),
            ),
            Text(
              auditFmtValue(context, newValue),
              style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ],
      ),
    );
  }
}

/// A field of a created or deleted row: its name and what it held.
class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.label, required this.value});

  final String label;
  final dynamic value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: text.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              auditFmtValue(context, value),
              style: text.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
