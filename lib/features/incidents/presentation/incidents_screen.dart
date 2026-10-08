import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/animations/animations.dart';
import '../../../core/constants/permission_codes.dart';
import '../../../core/l10n/error_text.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/creator_page.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/overflow_menu.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/states.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/application/session_cubit.dart';
import '../../modules/presentation/module_detail_screen.dart';
import '../application/incidents_cubit.dart';
import '../data/incidents_repository.dart';
import '../domain/incident.dart';
import 'raise_incident_screen.dart';

/// The operations room's register, or one person's own — see [IncidentsScope].
///
/// Ordered OLDEST FIRST among the open ones, which is the opposite of every
/// other list in this app and is the whole point: an emergency that has been
/// sitting for forty minutes matters more than one raised a moment ago, and
/// putting the newest on top is exactly how the old one is never looked at
/// again.
class IncidentsScreen extends StatelessWidget {
  const IncidentsScreen({
    super.key,
    this.scope = IncidentsScope.all,
    this.compose = false,
    this.focusIncidentId,
  });

  final IncidentsScope scope;

  /// Open the reporting form as soon as the screen is up — see [TasksScreen].
  ///
  /// Only ever set for [IncidentsScope.mine]: the register scope is read by
  /// the room, and there is nothing to compose from it — raising one there
  /// would be an ops-room screen writing a report on nobody's behalf.
  final bool compose;

  /// Opened FOR one report, which is how the inbox arrives here: a reader who
  /// tapped "بلاغ عاجل" has that report in mind and nothing else. Null from the
  /// menu, where the register is a list to be watched. Only ever set for
  /// [IncidentsScope.all] — بلاغاتي is never reached from an alarm.
  final String? focusIncidentId;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => IncidentsCubit(
      IncidentsRepository(),
      scope: scope,
      focusId: focusIncidentId,
    ),
    child: _IncidentsView(scope: scope, compose: compose),
  );
}

class _IncidentsView extends StatefulWidget {
  const _IncidentsView({required this.scope, this.compose = false});

  final IncidentsScope scope;
  final bool compose;

  @override
  State<_IncidentsView> createState() => _IncidentsViewState();
}

class _IncidentsViewState extends State<_IncidentsView> {
  @override
  void initState() {
    super.initState();
    if (widget.compose) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _raise(context);
      });
    }
  }

  Future<void> _raise(BuildContext context) async {
    final cubit = context.read<IncidentsCubit>();
    final sent = await Navigator.of(
      context,
    ).push<bool>(fadeThroughRoute((_) => const RaiseIncidentScreen()));
    if (sent == true) await cubit.load();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final mine = widget.scope == IncidentsScope.mine;
    final canDelete = context.select<SessionCubit, bool>(
      (cubit) => cubit.state.can(PermissionCodes.incidentsDelete),
    );

    return Scaffold(
      appBar: GlassAppBar(
        title: Text(mine ? l.myIncidentsTitle : l.incidentsTitle),
        actions: [
          // The bulk wipe belongs to the room, not to بلاغاتي: it strikes
          // rows off EVERYONE's register, and a personal history is not
          // where that decision should live even for somebody who happens
          // to hold the permission.
          if (!mine && canDelete)
            OverflowMenu(
              actions: [
                MenuAction(
                  icon: AppIcons.delete,
                  label: l.incidentsClear,
                  isDestructive: true,
                  onSelected: () => _clear(context),
                ),
              ],
            ),
        ],
      ),
      // Only بلاغاتي writes from this screen — see [IncidentsScreen.compose].
      floatingActionButton: mine
          ? CreateFab(label: l.incidentTitle, onPressed: () => _raise(context))
          : null,
      body: BlocBuilder<IncidentsCubit, IncidentsState>(
        builder: (context, state) {
          if (state.status == IncidentsStatus.loading) {
            return const SkeletonList(height: 168);
          }
          if (state.status == IncidentsStatus.error) {
            return EmptyState(
              icon: AppIcons.warning,
              title: friendlyError(context, state.error),
            );
          }

          // ResponsivePage caps the column on a monitor, and SinglePaneLayout's
          // padding comes from `context.scrollPadding` — which adds the
          // window's own bottom viewPadding. That is what keeps the last card
          // clear of the Android 15 gesture bar, where edge-to-edge is no
          // longer opt-in and a hard-coded padding puts content underneath it.
          return ResponsivePage(
            builder: (context, size) => SinglePaneLayout(
              gutter: size.gutter,
              onRefresh: () => context.read<IncidentsCubit>().load(),
              children: [
                // Held to a width a switch row can actually be read at. A
                // ListTile puts its label at one end and its control at the
                // other, which is right on a phone and absurd at 1680 — the
                // word and the thing it governs end up a hand's width apart
                // with nothing between them.
                //
                // The whole row stands down on بلاغاتي: there is no alarm to
                // have arrived from, and `includeClosed` is fixed true for
                // that scope — see [IncidentsCubit]'s constructor. A switch
                // wired to a value that never changes is not a control, it is
                // a lie about what pressing it does.
                if (!mine)
                  // Arrived from an alarm: one report, and the door back to
                  // the register it came out of. The switch has nothing to
                  // govern here — a focused list is one row long — so it
                  // stands down.
                  if (state.focusId != null)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: TextButton.icon(
                          onPressed: context.read<IncidentsCubit>().showAll,
                          icon: const Icon(AppIcons.warning, size: 16),
                          label: Text(l.incidentsShowAll),
                        ),
                      ),
                    )
                  else
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 360),
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l.incidentsShowClosed),
                          value: state.includeClosed,
                          onChanged: context
                              .read<IncidentsCubit>()
                              .setIncludeClosed,
                        ),
                      ),
                    ),
                // "There is no such report" and "there are no emergencies" are
                // opposite sentences, and a reader who just tapped an alarm
                // must not be told the second when the first is what happened.
                if (state.focusMissing)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xxl),
                    child: EmptyState(
                      icon: AppIcons.warning,
                      title: l.incidentNotInRegister,
                      action: FilledButton(
                        onPressed: context.read<IncidentsCubit>().showAll,
                        child: Text(l.incidentsShowAll),
                      ),
                    ),
                  )
                else if (state.visible.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xxl),
                    child: EmptyState(
                      icon: AppIcons.warning,
                      title: mine ? l.myIncidentsEmpty : l.incidentsEmpty,
                      message: mine
                          ? l.myIncidentsEmptyHint
                          : l.incidentsEmptyHint,
                    ),
                  ),
                // Columned like every other list in this app, and this is the
                // screen that gains most by it. An incident card is a state
                // chip, two short lines and a row of buttons; one to a row on a
                // monitor stretched each of them across a metre of glass and
                // fitted four emergencies on a screen that had room for a
                // dozen. In an operations room, how many of these are visible
                // at once IS the feature.
                //
                // Row-major, so the oldest is still first: the register is
                // ordered oldest-first on purpose — an emergency that has been
                // sitting forty minutes outranks one raised a moment ago — and
                // reading order carries that across the columns unchanged.
                AdaptiveGrid(
                  children: [
                    for (final incident in state.visible)
                      _IncidentCard(incident: incident, mine: mine),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Emptying the register.
///
/// Asks WHAT rather than merely "are you sure", because the two answers are not
/// the same act and a yes/no dialog cannot tell them apart. Clearing the closed
/// ones is housekeeping — the season is over, the list is six hundred rows of
/// finished business, and nobody loses anything. Clearing everything takes an
/// OPEN emergency off the screen of every other person watching the register,
/// possibly while somebody is driving towards it, and that has to be chosen in
/// so many words rather than arrived at by pressing the confirming button twice.
///
/// The safe answer is the primary one and the dangerous one is a plain button
/// in the error colour, which is the opposite of how a confirmation usually
/// reads and is the point.
Future<void> _clear(BuildContext context) async {
  final l = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final cubit = context.read<IncidentsCubit>();

  final onlyClosed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l.incidentsClear),
      content: Text(l.incidentsClearWhat),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l.commonCancel),
        ),
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(dialogContext).colorScheme.error,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l.incidentsClearAll),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l.incidentsClearClosed),
        ),
      ],
    ),
  );
  if (onlyClosed == null) return;

  final result = await cubit.deleteAll(onlyClosed: onlyClosed);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          result.error == null
              ? l.incidentsCleared(result.deleted)
              : friendlyErrorL(l, result.error),
        ),
      ),
    );
}

/// Striking one off, with the warning that it is final.
Future<void> _delete(BuildContext context, Incident incident) async {
  final l = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final cubit = context.read<IncidentsCubit>();

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l.incidentDelete),
      content: Text(l.incidentDeleteConfirm),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l.commonCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
          ),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l.commonDelete),
        ),
      ],
    ),
  );
  if (confirmed != true) return;

  final error = await cubit.delete(incident);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          error == null ? l.incidentDeleted : friendlyErrorL(l, error),
        ),
      ),
    );
}

/// What a report is about, when the reporter said so — one quiet line under
/// the one that says who sent it.
///
/// It carries its own action rather than adding a button to the row at the foot
/// of the card, and that is the whole reason it is a widget: the thing you do
/// about a subject is telephone HIM, and the thing you do about a screen is
/// open it, and neither belongs beside "أتولّاه" — those are what you do about
/// the REPORT.
class _AboutLine extends StatelessWidget {
  const _AboutLine({
    required this.icon,
    required this.label,
    this.actionIcon,
    this.actionHint,
    this.onAction,
  });

  final IconData icon;
  final String label;
  final IconData? actionIcon;
  final String? actionHint;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final line = Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              context.l10n.incidentAboutLabel(label),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          if (actionIcon case final glyph? when onAction != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Icon(glyph, size: 16, color: scheme.primary),
          ],
        ],
      ),
    );

    if (onAction == null) return line;
    return Tooltip(
      message: actionHint ?? '',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.xs),
        onTap: onAction,
        child: line,
      ),
    );
  }
}

/// "40 د" / "3 س". Short because it sits beside a name on a crowded card, and
/// what matters is the order of magnitude, not the seconds.
String waitedLabel(AppLocalizations l, Duration waited) {
  final minutes = waited.inMinutes;
  if (minutes < 60) return l.durationMinutes(minutes < 0 ? 0 : minutes);
  return l.durationHours(waited.inHours);
}

class _IncidentCard extends StatelessWidget {
  const _IncidentCard({required this.incident, required this.mine});
  final Incident incident;

  /// Whether this card is drawn on بلاغاتي rather than on the register.
  ///
  /// بلاغاتي is a status check, full stop — not a thinner register. Every
  /// button below that DOES something to the report or to a person named on
  /// it — take it on, close it, reopen it, delete it, telephone the
  /// reporter, find him on a map — stays on the register and never draws
  /// here, independent of what the reader may otherwise hold. Even an
  /// ops-room member reading their own report through this door sees only
  /// what happened to it; acting on it means opening the register, the same
  /// as for anybody else's. What survives on بلاغاتي is what a status check
  /// actually is: the state, the wait, who (if anybody) took it on, and the
  /// words of the report itself.
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final cubit = context.read<IncidentsCubit>();
    final canDelete =
        !mine &&
        context.select<SessionCubit, bool>(
          (session) => session.state.can(PermissionCodes.incidentsDelete),
        );
    // Gates the three state buttons below. Not merely cosmetic: `incidents_
    // update` (0088) refuses the write to anybody without this — but the
    // `!mine` half is the one that matters most, since it is what keeps this
    // screen's own management off بلاغاتي regardless of what the reader may
    // hold. Drawing a button the database would refuse, or a button that
    // manages a report from the wrong screen, are the same mistake: a
    // control that does not mean what it looks like it means.
    final canHandle =
        !mine &&
        context.select<SessionCubit, bool>(
          (session) => session.state.can(PermissionCodes.incidentsHandle),
        );

    final stateLabel = switch (incident.state) {
      IncidentState.open => l.incidentStateOpen,
      IncidentState.inProgress => l.incidentStateInProgress,
      IncidentState.closed => l.incidentStateClosed,
    };

    // Colour carries the state at a glance. An open emergency is the only thing
    // in this app drawn in the error colour without being an error.
    final accent = switch (incident.state) {
      IncidentState.open => scheme.error,
      IncidentState.inProgress => scheme.tertiary,
      IncidentState.closed => scheme.onSurfaceVariant,
    };

    // No bottom padding of its own any more: the grid above spaces its rows,
    // and a card carrying its own margin inside a grid cell puts a gap under
    // every card in a row except the tallest one.
    return GlassCard(
      // An OPEN emergency washes its whole pane, the way the dashboard's alarm
      // cards do — in a register read across a room, the red must be findable
      // before it is readable.
      tint: incident.state.isOpen ? scheme.error : null,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GlassBadge(
                  label: stateLabel,
                  icon: switch (incident.state) {
                    IncidentState.open => AppIcons.warning,
                    IncidentState.inProgress => AppIcons.pending,
                    IncidentState.closed => AppIcons.approve,
                  },
                  color: accent,
                  dense: true,
                ),
                const Spacer(),
                // How long it has been sitting — beside the state, in the
                // state's own colour and a weight that can be read across the
                // room, because the wait is the whole reason this list is
                // ordered oldest-first.
                if (!incident.state.isClosed)
                  Text(
                    l.incidentWaited(waitedLabel(l, incident.waited)),
                    style: text.labelMedium?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                // In the header rather than beside "أتولّاه" below. That row is
                // what you do ABOUT the emergency — telephone him, take it on,
                // close it — and a button that erases the record has no business
                // standing in a line of them at 3am with one thumb.
                //
                // Absent rather than disabled for whoever may not: see
                // [OverflowMenu], and the same argument the file screens make.
                if (canDelete) ...[
                  const SizedBox(width: AppSpacing.sm),
                  OverflowMenu(
                    actions: [
                      MenuAction(
                        icon: AppIcons.delete,
                        label: l.incidentDelete,
                        isDestructive: true,
                        onSelected: () => _delete(context, incident),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(incident.body, style: text.bodyMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              [
                incident.reporterName,
                // The most specific place it knows: the tower if there is
                // one, otherwise the file, otherwise nothing at all.
                ?(incident.nodeLabel ?? incident.moduleName),
              ].join(' · '),
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
            // What the report is ABOUT, when the reporter said — a person or a
            // screen (0120). On its own line rather than appended to the one
            // above, because that line is about who SENT it: running "محمد ·
            // برج ٣ · أحمد" together makes two names read as one party, and the
            // whole reason the subject is recorded separately is that the room
            // has two different calls to make.
            if (incident.subjectName?.trim().isNotEmpty ?? false)
              _AboutLine(
                icon: AppIcons.employees,
                label: incident.subjectName!,
                // The subject's own number, on the line that names him rather
                // than in the row of buttons below. Two "اتصال" buttons on one
                // card is one too many: they are different calls to different
                // people, and only the position on the card can say which.
                //
                // And on بلاغاتي, neither call is drawn at all — see [mine] on
                // this widget. Telephoning the subject is the room's errand,
                // not something the reporter reading his own report does.
                actionIcon: mine
                    ? null
                    : switch (incident.subjectPhone?.trim()) {
                        final phone? when phone.isNotEmpty => AppIcons.phoneSy,
                        _ => null,
                      },
                actionHint: l.incidentCall,
                onAction: mine
                    ? null
                    : switch (incident.subjectPhone?.trim()) {
                        final phone? when phone.isNotEmpty => () =>
                            launchUrl(Uri.parse('tel:$phone')),
                        _ => null,
                      },
              )
            else if (incident.appLabel?.trim().isNotEmpty ?? false)
              _AboutLine(
                icon: AppIcons.layoutSidebar,
                label: incident.appLabel!,
                actionIcon: incident.appRoute == null ? null : AppIcons.link,
                actionHint: l.incidentOpenPage,
                onAction: switch (incident.appRoute) {
                  final route? when route.isNotEmpty => () => context.push(
                    route,
                  ),
                  _ => null,
                },
              )
            // The file, when the report named one and named nothing more
            // specific. Last of the four because it is the least specific: a
            // report about a man in a file is about the MAN, and the line above
            // has already said so.
            else if (incident.moduleId case final moduleId?
                when (incident.moduleName?.trim().isNotEmpty ?? false))
              _AboutLine(
                icon: AppIcons.modules,
                label: incident.nodeLabel ?? incident.moduleName!,
                actionIcon: AppIcons.link,
                actionHint: l.incidentOpenModule,
                onAction: () => Navigator.of(context).push(
                  fadeThroughRoute(
                    (_) => ModuleDetailScreen(moduleId: moduleId),
                  ),
                ),
              ),
            if (incident.handledByName case final name?
                when name.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  l.incidentHandledBy(name),
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                // The telephone first. Everything else on this card is
                // context; this is the action.
                //
                // Neither button here draws on بلاغاتي: telephoning the
                // reporter and locating him are the room's errands, and on
                // this screen the reporter IS the reader — a "call" button
                // that dials your own number is not a control, it is a bug
                // wearing the shape of one.
                if (!mine)
                  if (incident.reporterPhone case final phone?
                      when phone.trim().isNotEmpty)
                    TextButton.icon(
                      onPressed: () => launchUrl(Uri.parse('tel:$phone')),
                      icon: const Icon(AppIcons.phoneSy, size: 16),
                      label: Text(l.incidentCall),
                    ),
                if (!mine)
                  if (incident.mapUrl case final url?)
                    TextButton.icon(
                      onPressed: () => launchUrl(
                        Uri.parse(url),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(AppIcons.checkIn, size: 16),
                      label: Text(l.incidentOpenMap),
                    ),
                if (canHandle && incident.state.isOpen)
                  FilledButton.tonal(
                    onPressed: () =>
                        cubit.setState(incident, IncidentState.inProgress),
                    child: Text(l.incidentTake),
                  ),
                if (canHandle && incident.state == IncidentState.inProgress)
                  FilledButton.tonal(
                    onPressed: () =>
                        cubit.setState(incident, IncidentState.closed),
                    child: Text(l.incidentClose),
                  ),
                if (canHandle && incident.state.isClosed)
                  TextButton(
                    onPressed: () =>
                        cubit.setState(incident, IncidentState.open),
                    child: Text(l.incidentReopen),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
