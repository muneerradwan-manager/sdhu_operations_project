import 'package:flutter/material.dart';

import '../../../../core/animations/animations.dart';
import '../../../../core/l10n/error_text.dart';
import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/glass_tokens.dart';
import '../../../../core/widgets/glass.dart';
import '../../../../core/widgets/info_section.dart';
import '../../data/complaints_repository.dart';
import '../../domain/complaint.dart';
import '../complaint_thread_screen.dart';

/// What was filed about one person, at the foot of their page.
///
/// Two readers, two questions, one section:
///
///   * **The person themself** ([profileId] null) gets the complaints — the
///     words, the files, and the way in to answer them. Read through
///     `complaints_against_me`, which takes no argument and returns no name:
///     they see everything that was said and never who said it.
///   * **Somebody looking at their page** gets the standing — how many, from
///     how many different people, and whether the account is suspended by the
///     rule rather than by a decision. Only for a reader holding
///     `complaints.view`; for anyone else the section is not drawn at all.
///
/// The difference is not cosmetic. The first list cannot be handed to the
/// second reader without handing over the accusers with it.
class ComplaintsAgainstSection extends StatefulWidget {
  const ComplaintsAgainstSection({
    super.key,
    this.profileId,
    this.canReadRegister = false,
  });

  /// Whose page this is. Null means "mine", which is the only case that shows
  /// the complaints themselves.
  final String? profileId;

  /// Whether this reader may see the register — the difference between being
  /// shown the numbers and being shown nothing.
  final bool canReadRegister;

  bool get isMine => profileId == null;

  @override
  State<ComplaintsAgainstSection> createState() =>
      _ComplaintsAgainstSectionState();
}

class _ComplaintsAgainstSectionState extends State<ComplaintsAgainstSection> {
  final _repo = ComplaintsRepository();
  late Future<_Against> _future = _load();

  Future<_Against> _load() async {
    if (widget.isMine) {
      return _Against(complaints: await _repo.fetchAgainstMe());
    }
    // The counts always; the complaints only for a reader who may read them.
    final standing = await _repo.fetchStanding(widget.profileId!);
    final complaints = widget.canReadRegister
        ? await _repo.fetchList(all: true, targetId: widget.profileId)
        : const <Complaint>[];
    return _Against(standing: standing, complaints: complaints);
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    // Somebody else's page, and this reader has no business with the register:
    // draw nothing rather than an empty box that says so.
    if (!widget.isMine && !widget.canReadRegister) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<_Against>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final waiting = snapshot.connectionState == ConnectionState.waiting;

        // Nothing was ever filed and nothing is loading — say nothing. An
        // empty "complaints" heading on a clean record reads as an accusation
        // in itself.
        if (!waiting &&
            !snapshot.hasError &&
            (data?.isEmpty ?? true) &&
            !widget.isMine) {
          return const SizedBox.shrink();
        }

        return InfoSection(
          title: widget.isMine
              ? l.complaintsAgainstMeTitle
              : l.complaintsSectionAgainst,
          icon: AppIcons.complaints,
          maxColumns: 1,
          children: [
            if (waiting)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (snapshot.hasError)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text(
                  friendlyError(context, '${snapshot.error}'),
                  style: text.bodySmall,
                ),
              )
            else ...[
              if (data!.standing != null) _Standing(standing: data.standing!),
              if (data.complaints.isEmpty && data.standing == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                  child: Text(
                    l.complaintsAgainstMeEmpty,
                    style: text.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              for (final complaint in data.complaints)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: _Row(complaint: complaint, onChanged: _reload),
                ),
            ],
          ],
        );
      },
    );
  }
}

/// One complaint, opening into its thread — which is where the reply is.
class _Row extends StatelessWidget {
  const _Row({required this.complaint, required this.onChanged});

  final Complaint complaint;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final muted = complaint.isDismissed;

    return GlassCard(
      onTap: () async {
        final changed = await Navigator.of(context).push<bool>(
          fadeThroughRoute(
            (_) => ComplaintThreadScreen(
              complaintId: complaint.id,
              known: complaint,
            ),
          ),
        );
        if (changed == true) onChanged();
      },
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  complaint.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodyMedium?.copyWith(
                    color: muted ? scheme.onSurfaceVariant : null,
                    decoration: muted ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.xs,
                  children: [
                    GlassBadge(
                      label: l.complaintFiledOn(formatDate(complaint.createdAt)),
                      dense: true,
                    ),
                    GlassBadge(
                      label: l.complaintReplyCount(complaint.replyCount),
                      dense: true,
                    ),
                    if (complaint.isLocked)
                      GlassBadge(
                        label: l.complaintLocked,
                        icon: AppIcons.complaintLocked,
                        color: scheme.onSurfaceVariant,
                        dense: true,
                      ),
                    if (complaint.isDismissed)
                      GlassBadge(
                        label: l.complaintDismissed,
                        icon: AppIcons.complaintDismissed,
                        color: scheme.error,
                        dense: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const NavChevron(),
        ],
      ),
    );
  }
}

/// The numbers a manager needs before deciding anything: how many people, not
/// how many complaints, because that is what the rule counts.
class _Standing extends StatelessWidget {
  const _Standing({required this.standing});
  final ComplaintStanding standing;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: [
          GlassBadge(
            label: l.complaintsAgainstCount(standing.openComplaints),
            icon: AppIcons.complaints,
            dense: true,
          ),
          GlassBadge(
            label: l.complaintsDistinctComplainants(
              standing.distinctComplainants,
            ),
            icon: AppIcons.employees,
            dense: true,
          ),
          if (standing.dismissedComplaints > 0)
            GlassBadge(
              label: l.complaintsDismissedCount(standing.dismissedComplaints),
              icon: AppIcons.complaintDismissed,
              color: scheme.onSurfaceVariant,
              dense: true,
            ),
          // Why the switch on this page moves by itself. Without it a manager
          // un-suspends an account, watches it suspend again, and concludes the
          // app is broken.
          if (standing.isAutoSuspended)
            GlassBadge(
              label: l.complaintsAutoSuspended,
              icon: AppIcons.suspend,
              color: scheme.error,
              dense: true,
            ),
          if (standing.isOneShortOfSuspension)
            GlassBadge(
              label: l.complaintsAutoSuspendNear,
              icon: AppIcons.pending,
              color: scheme.tertiary,
              dense: true,
            ),
        ],
      ),
    );
  }
}

class _Against {
  const _Against({this.standing, this.complaints = const []});

  final ComplaintStanding? standing;
  final List<Complaint> complaints;

  bool get isEmpty => complaints.isEmpty && (standing?.isEmpty ?? true);
}
