import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/animations/animations.dart';
import '../../../core/attachments/attachment_picker.dart';
import '../../../core/constants/permission_codes.dart';
import '../../../core/l10n/error_text.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/overflow_menu.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/states.dart';
import '../../auth/application/session_cubit.dart';
import '../application/complaint_thread_cubit.dart';
import '../data/complaints_repository.dart';
import '../domain/complaint.dart';
import 'widgets/complaint_message_bubble.dart';

/// The complaint and the conversation under it.
///
/// Three kinds of people stand here and the screen is the same for all of them:
/// whoever filed it, whoever it is about, and whoever oversees. What differs is
/// what the SERVER put in the thread — the employee complained about is handed
/// the words and the files with no name attached to them, and every bubble the
/// complainant wrote comes through unsigned. Nothing on this screen decides
/// that; by the time the thread is here, the redaction has already happened.
class ComplaintThreadScreen extends StatelessWidget {
  const ComplaintThreadScreen({
    super.key,
    required this.complaintId,
    this.known,
  });

  final String complaintId;

  /// What the list already knew, so the header is right before the thread
  /// arrives. Null when this was opened from a notification or a profile.
  final Complaint? known;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => ComplaintThreadCubit(
      ComplaintsRepository(),
      complaintId,
      known: known,
    ),
    child: _View(title: known?.targetLabel),
  );
}

class _View extends StatelessWidget {
  const _View({this.title});
  final String? title;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final session = context.watch<SessionCubit>().state;

    return BlocConsumer<ComplaintThreadCubit, ComplaintThreadState>(
      listenWhen: (p, c) => c.error != null && p.error != c.error,
      listener: (context, state) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(friendlyError(context, state.error))),
        ),
      builder: (context, state) {
        final cubit = context.read<ComplaintThreadCubit>();
        final canLock =
            session.isAdmin || session.can(PermissionCodes.complaintsLock);
        final canDismiss =
            session.isAdmin || session.can(PermissionCodes.complaintsDismiss);
        final canDelete =
            session.isAdmin || session.can(PermissionCodes.complaintsDelete);

        return Scaffold(
          appBar: GlassAppBar(
            title: Text(title ?? l.complaintsTitle),
            actions: [
              if (state.status == ThreadStatus.ready &&
                  (canLock || canDismiss || canDelete))
                OverflowMenu(
                  actions: [
                    if (canLock)
                      MenuAction(
                        icon: state.isLocked
                            ? AppIcons.complaintUnlock
                            : AppIcons.complaintLocked,
                        label: state.isLocked
                            ? l.complaintUnlock
                            : l.complaintLock,
                        onSelected: () => _setLocked(context, !state.isLocked),
                      ),
                    if (canDismiss)
                      MenuAction(
                        icon: AppIcons.complaintDismissed,
                        label: state.isDismissed
                            ? l.complaintUndismiss
                            : l.complaintDismiss,
                        onSelected: () =>
                            _setDismissed(context, !state.isDismissed),
                      ),
                    if (canDelete)
                      MenuAction(
                        icon: AppIcons.delete,
                        label: l.complaintDelete,
                        isDestructive: true,
                        onSelected: () => _delete(context),
                      ),
                  ],
                ),
            ],
          ),
          body: SafeArea(
            child: switch (state.status) {
              ThreadStatus.loading => ResponsivePage(
                width: PageWidth.reading,
                builder: (context, size) => SkeletonList(
                  width: PageWidth.reading,
                  maxColumns: 1,
                  height: 140,
                  padding: context.scrollPadding(
                    horizontal: size.gutter,
                    bottom: AppSpacing.xl,
                  ),
                ),
              ),
              ThreadStatus.missing => EmptyState(
                icon: AppIcons.complaints,
                title: l.complaintMissing,
              ),
              ThreadStatus.error => EmptyState(
                icon: AppIcons.complaints,
                title: friendlyError(context, state.error),
                action: FilledButton(
                  onPressed: cubit.load,
                  child: Text(l.commonRetry),
                ),
              ),
              ThreadStatus.ready => _Thread(state: state),
            },
          ),
          bottomNavigationBar: state.status == ThreadStatus.ready
              ? _Composer(state: state)
              : null,
        );
      },
    );
  }

  Future<void> _setLocked(BuildContext context, bool locked) =>
      context.read<ComplaintThreadCubit>().setLocked(locked);

  Future<void> _setDismissed(BuildContext context, bool dismissed) async {
    final l = context.l10n;
    final cubit = context.read<ComplaintThreadCubit>();

    if (dismissed) {
      // Worth a confirmation, because it is not only a label: a dismissed
      // complaint stops counting toward the automatic suspension, and dropping
      // the count below three lifts one already in force.
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          content: Text(l.complaintDismissConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(l.complaintDismiss),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await cubit.setDismissed(dismissed);
  }

  Future<void> _delete(BuildContext context) async {
    final l = context.l10n;
    final cubit = context.read<ComplaintThreadCubit>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final scheme = Theme.of(context).colorScheme;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(l.complaintDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: scheme.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l.commonDelete),
          ),
        ],
      ),
    );
    if (ok != true) return;

    if (await cubit.delete()) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.complaintDeleted)));
      navigator.pop(true);
    }
  }
}

class _Thread extends StatelessWidget {
  const _Thread({required this.state});
  final ComplaintThreadState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final cubit = context.read<ComplaintThreadCubit>();

    return ResponsivePage(
      width: PageWidth.reading,
      builder: (context, size) => SinglePaneLayout(
        gutter: size.gutter,
        onRefresh: cubit.load,
        children: [
          if (state.isDismissed)
            _Banner(
              icon: AppIcons.complaintDismissed,
              label: l.complaintDismissed,
              color: scheme.error,
            ),
          if (state.isLocked)
            _Banner(
              icon: AppIcons.complaintLocked,
              label: l.complaintLocked,
              color: scheme.onSurfaceVariant,
            ),
          ...staggered([
            for (final message in state.messages)
              ComplaintMessageBubble(
                message: message,
                signer: cubit.signedUrl,
              ),
          ]),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.md),
    child: GlassSurface(
      subtle: true,
      blur: false,
      shadow: false,
      bordered: false,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Where a reply is written, with the same five kinds of attachment the
/// complaint itself may carry.
///
/// It disappears entirely when the thread is locked or when this reader has no
/// standing to answer — a disabled field that never explains itself is worse
/// than no field, and the banner above has already said why.
class _Composer extends StatefulWidget {
  const _Composer({required this.state});
  final ComplaintThreadState state;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _controller = TextEditingController();
  final _attachments = <PendingAttachment>[];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final cubit = context.read<ComplaintThreadCubit>();
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    final sent = await cubit.reply(
      _controller.text,
      attachments: List.of(_attachments),
    );
    if (!mounted) return;
    if (sent) {
      _controller.clear();
      setState(_attachments.clear);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.complaintReplySent)));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.state.isLocked) return const SizedBox.shrink();

    final l = context.l10n;
    final sending = widget.state.sending;

    return GlassSurface(
      radius: 0,
      strong: true,
      shadow: false,
      bordered: false,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _attachments.length; i++)
                PendingAttachmentRow(
                  attachment: _attachments[i],
                  onRemove: sending
                      ? null
                      : () => setState(() => _attachments.removeAt(i)),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: l.notificationAttach,
                    onPressed: sending
                        ? null
                        : () async {
                            final picked = await pickAttachment(context);
                            if (picked != null && mounted) {
                              setState(() => _attachments.add(picked));
                            }
                          },
                    icon: const Icon(AppIcons.attach),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: l.complaintReplyHint,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconButton.filled(
                    tooltip: l.complaintReply,
                    onPressed: sending ? null : _send,
                    icon: sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2.2),
                          )
                        : const Icon(AppIcons.send),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
