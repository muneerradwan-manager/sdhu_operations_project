import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/attachments/attachment_picker.dart';
import '../../../core/l10n/error_text.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/creator_page.dart';
import '../../../core/widgets/glass.dart';
import '../application/file_complaint_cubit.dart';
import '../data/complaints_repository.dart';
import '../domain/complaint.dart';
import 'widgets/complaint_labels.dart';

/// Filing one.
///
/// Opened cold it asks what the complaint is about; opened from a page that
/// already knows — an employee's, a file's — [target] and [targetId] come in
/// settled and the first question is not asked twice.
class FileComplaintScreen extends StatelessWidget {
  const FileComplaintScreen({
    super.key,
    this.target,
    this.targetId,
    this.targetName,
  });

  final ComplaintTarget? target;
  final String? targetId;
  final String? targetName;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => FileComplaintCubit(
      ComplaintsRepository(),
      target: target,
      targetId: targetId,
      targetName: targetName,
    ),
    child: _View(locked: target != null && targetId != null),
  );
}

class _View extends StatelessWidget {
  const _View({required this.locked});

  /// The target arrived with the screen and is not the reader's to change.
  final bool locked;

  Future<void> _submit(BuildContext context) async {
    final l = context.l10n;
    final cubit = context.read<FileComplaintCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final id = await cubit.submit();
    if (id == null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(friendlyErrorL(l, cubit.state.error)),
          ),
        );
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l.complaintSubmitted)));
    navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    // The same chrome the task editor and the arrival wear — title above, the
    // one decision pinned to the bottom of the window. See [CreatorPage].
    return BlocBuilder<FileComplaintCubit, FileComplaintState>(
      builder: (context, state) => CreatorPage(
        title: l.complaintsNew,
        submitLabel: l.complaintSubmit,
        submitIcon: AppIcons.send,
        busy: state.status == FileComplaintStatus.sending,
        onSubmit: state.canSubmit ? () => _submit(context) : null,
        children: [
          _TargetSection(state: state, locked: locked),
          const SizedBox(height: AppSpacing.lg),
          _BodySection(state: state),
          const SizedBox(height: AppSpacing.lg),
          _AttachmentsSection(state: state),
        ],
      ),
    );
  }
}

/// What the complaint is about: the kind, then the one.
class _TargetSection extends StatelessWidget {
  const _TargetSection({required this.state, required this.locked});
  final FileComplaintState state;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cubit = context.read<FileComplaintCubit>();
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.complaintTarget, style: text.titleMedium),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final target in ComplaintTarget.values)
                ChoiceChip(
                  label: Text(complaintTargetLabel(l, target)),
                  avatar: Icon(complaintTargetIcon(target), size: 16),
                  selected: state.target == target,
                  visualDensity: VisualDensity.compact,
                  onSelected: locked ? null : (_) => cubit.setTarget(target),
                ),
            ],
          ),
          if (state.needsTarget) ...[
            const SizedBox(height: AppSpacing.lg),
            if (locked)
              Text(
                l.complaintTargetPicked(state.targetName ?? ''),
                style: text.bodyMedium,
              )
            else if (state.status == FileComplaintStatus.loadingTargets)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            // Nothing to point at. Said out loud, because an empty dropdown is
            // read as a broken screen: since 0140 the list is the colleagues of
            // the files he is posted to and those files themselves, so a man in
            // no file has none — and «شكوى أخرى» is where his complaint goes.
            else if (state.options.isEmpty)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    AppIcons.emptyInbox,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      l.complaintTargetNone(
                        complaintTargetLabel(l, state.target!),
                      ),
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              )
            else
              DropdownButtonFormField<String>(
                initialValue: state.targetId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: l.complaintTargetPick,
                  prefixIcon: Icon(complaintTargetIcon(state.target!)),
                ),
                items: [
                  for (final option in state.options)
                    DropdownMenuItem(
                      value: option.id,
                      child: Text(
                        option.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  final picked = state.options.firstWhere((o) => o.id == value);
                  cubit.pick(picked.id, picked.name);
                },
              ),
          ],
          // Said before anything is typed, not after it is sent: whether the
          // other person will know who filed this changes what a person is
          // willing to write.
          if (state.target == ComplaintTarget.employee) ...[
            const SizedBox(height: AppSpacing.md),
            GlassSurface(
              subtle: true,
              blur: false,
              shadow: false,
              bordered: false,
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(AppIcons.shield, size: 18, color: scheme.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      l.complaintAnonymousNote,
                      style: text.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BodySection extends StatefulWidget {
  const _BodySection({required this.state});
  final FileComplaintState state;

  @override
  State<_BodySection> createState() => _BodySectionState();
}

class _BodySectionState extends State<_BodySection> {
  late final _controller = TextEditingController(text: widget.state.body);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cubit = context.read<FileComplaintCubit>();

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.complaintBody, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _controller,
            maxLines: 6,
            minLines: 4,
            textCapitalization: TextCapitalization.sentences,
            onChanged: cubit.setBody,
            decoration: InputDecoration(
              hintText: l.complaintBodyHint,
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }
}

/// The same five sources a notification offers — camera, photo, video, voice,
/// document — because a complaint is more often a photo than a paragraph.
class _AttachmentsSection extends StatelessWidget {
  const _AttachmentsSection({required this.state});
  final FileComplaintState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cubit = context.read<FileComplaintCubit>();
    final sending = state.status == FileComplaintStatus.sending;

    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: sending
                  ? null
                  : () async {
                      final picked = await pickAttachment(context);
                      if (picked != null) cubit.addAttachment(picked);
                    },
              icon: const Icon(AppIcons.attach, size: 18),
              label: Text(l.notificationAttach),
            ),
          ),
          for (var i = 0; i < state.attachments.length; i++)
            PendingAttachmentRow(
              attachment: state.attachments[i],
              onRemove: sending ? null : () => cubit.removeAttachment(i),
            ),
        ],
      ),
    );
  }
}
