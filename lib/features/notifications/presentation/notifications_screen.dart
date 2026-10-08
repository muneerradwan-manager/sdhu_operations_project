import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/animations/animations.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/states.dart';
import '../../auth/application/session_cubit.dart';
import '../../../core/constants/permission_codes.dart';
import '../../incidents/presentation/incidents_screen.dart';
import '../../modules/data/modules_repository.dart';
import '../../modules/domain/operational_module.dart';
import '../../modules/presentation/module_detail_screen.dart';
import '../application/notifications_cubit.dart';
import '../data/notifications_repository.dart';
import '../data/push_service.dart';
import '../domain/app_notification.dart';
import 'send_notification_sheet.dart';
import '../../../core/attachments/attachments_view.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = NotificationsRepository();
    return BlocProvider(
      create: (_) => NotificationsCubit(repo),
      // The same instance the cubit reads through: signing an attachment URL
      // goes through it too, and it holds nothing worth having twice.
      child: _View(repo: repo),
    );
  }
}

class _View extends StatefulWidget {
  const _View({required this.repo});

  final NotificationsRepository repo;

  @override
  State<_View> createState() => _ViewState();
}

class _ViewState extends State<_View> {
  NotificationsRepository get repo => widget.repo;

  @override
  void initState() {
    super.initState();

    // Arriving here from a notification tapped in the phone's own tray. The
    // tap named a file, so opening the inbox is only half of what was asked
    // for — the reader pressed a sentence about a place.
    //
    // A listener and not a one-time read: a tap can land while the inbox is
    // ALREADY on screen, in which case `go(notifications)` changes nothing and
    // initState never runs again. Read once in initState only, the tap did
    // nothing then — and stayed parked, flinging the reader into that file the
    // next time the inbox happened to be opened.
    PushService.instance.pendingTap.addListener(_onPendingTap);
    _onPendingTap();
  }

  @override
  void dispose() {
    PushService.instance.pendingTap.removeListener(_onPendingTap);
    super.dispose();
  }

  void _onPendingTap() {
    if (!mounted) return;
    final tap = PushService.instance.takePendingTap();
    if (tap == null) return;

    // The same two journeys the inbox rows make, from the phone's own tray.
    // A push carrying an alarm used to land on the inbox and stop there, which
    // is the one notification in this app where the extra tap costs something.
    final incidentId = AppNotification.incidentIdIn(tap);
    final moduleId = AppNotification.moduleIdIn(tap);
    if (incidentId == null && moduleId == null) return;

    // Waited for a frame because opening it may fail: the file can have been
    // deleted since, and saying so needs a Scaffold that exists.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (incidentId != null) {
        Navigator.of(context).push(
          fadeThroughRoute((_) => IncidentsScreen(focusIncidentId: incidentId)),
        );
        return;
      }
      _openModule(context, moduleId!);
    });
  }

  /// Mark it read, and take the reader to what it is about.
  ///
  /// "تم إسنادك إلى ملف تشغيلي" is a sentence about a place, and the reader's
  /// next move is always to go and look at it. So the tap goes there — but only
  /// after asking whether it is still there to go to.
  ///
  /// The file may be gone: deleted since, or deactivated, or the reader taken
  /// off it. All three come back as nothing, and all three mean the same thing
  /// to whoever is tapping — so they get one honest sentence rather than a
  /// screen that opens onto an error. The notification itself stays; it is a
  /// record of something that happened, and it happened.
  Future<void> _open(BuildContext context, AppNotification n) async {
    final cubit = context.read<NotificationsCubit>();
    if (!n.isRead) cubit.markRead(n.id);

    switch (n.destination) {
      case NotificationDestination.none:
        return;
      // The register, opened ON this report. Everything a person woken by an
      // alarm needs is there and nowhere else — the reporter's number, the
      // subject's, the map pin, the photographs, and the button that says
      // somebody is going. The card in the inbox is the announcement; this is
      // the thing itself.
      case NotificationDestination.incident:
        Navigator.of(context).push(
          fadeThroughRoute(
            (_) => IncidentsScreen(focusIncidentId: n.incidentId),
          ),
        );
      case NotificationDestination.module:
        await _openModule(context, n.moduleId!);
    }
  }

  /// Opens a file a notification pointed at, from either door: a row tapped in
  /// this list, or the notification tapped in the phone's tray that opened the
  /// app on this list. Both are the same act and must not drift apart.
  Future<void> _openModule(BuildContext context, String moduleId) async {
    final l = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final OperationalModule? module;
    try {
      module = await ModulesRepository().fetchModule(moduleId);
    } catch (_) {
      // A network error is not "the file is gone" — say what actually failed
      // instead of letting the tap die in silence.
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.commonConnectionErrorTitle)));
      return;
    }
    if (module == null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.notificationTargetGone)));
      return;
    }
    // Not `fromOffice`: arriving from an inbox is not arriving through إدارة
    // الملفات, so the file opens to be read rather than to be edited.
    navigator.push(
      fadeThroughRoute((_) => ModuleDetailScreen(moduleId: moduleId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      floatingActionButton:
          context.watch<SessionCubit>().state.canSendAnyNotification
          ? Builder(
              builder: (context) => FloatingActionButton.extended(
                onPressed: () async {
                  final cubit = context.read<NotificationsCubit>();
                  await showSendNotificationSheet(context);
                  // A broadcast reaches the sender too, and it should appear
                  // without waiting to be told about it.
                  await cubit.refresh();
                },
                icon: const Icon(AppIcons.send),
                label: Text(l.notificationSend),
              ),
            )
          : null,
      appBar: GlassAppBar(
        title: Text(l.navNotifications),
        actions: [
          BlocBuilder<NotificationsCubit, NotificationsState>(
            builder: (context, state) {
              // Counted over what is on screen, because that is what the button
              // now clears. Over the alarms with none unread it has nothing to
              // do, whatever is waiting in the other half.
              final unread = state.visible.where((n) => !n.isRead).length;
              if (unread == 0) return const SizedBox.shrink();
              return IconButton(
                tooltip: l.notificationMarkAllRead,
                icon: const Icon(AppIcons.selected),
                onPressed: () =>
                    context.read<NotificationsCubit>().markAllRead(),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: BlocBuilder<NotificationsCubit, NotificationsState>(
          builder: (context, state) {
            if (state.loading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.items.isEmpty) {
              return _Empty(message: l.notificationsEmpty);
            }

            // The chips only where they govern something. A reader who does
            // not receive urgent reports never has one in this list — the
            // alarm is sent to holders of `incidents.receive` and nobody else
            // — so for everybody else this is a two-position control with one
            // position permanently empty.
            final canFilter =
                state.hasIncidents &&
                context.select<SessionCubit, bool>(
                  (s) => s.state.can(PermissionCodes.incidentsReceive),
                );

            final items = canFilter ? state.visible : state.items;
            final days = NotificationDay.byDay(items);

            final body = items.isEmpty
                ? _Empty(
                    message: switch (state.filter) {
                      NotificationFilter.incidents =>
                        l.notificationsEmptyIncidents,
                      _ => l.notificationsEmptyMessages,
                    },
                  )
                : _Days(days: days, repo: repo, onOpen: _open);

            if (!canFilter) return body;

            return Column(
              children: [
                _FilterBar(state: state),
                Expanded(child: body),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Announcements, or emergencies.
///
/// Two things arrive in one list and are not read for the same reason: an
/// announcement is read when there is a minute, an urgent report is read
/// because somebody is standing in منى waiting for an answer. Mixed together at
/// three in the morning the second is found by scrolling past the first, and
/// this is the control that stops that.
///
/// The counts are UNREAD counts and they are on the chips rather than in a
/// heading, because the number is the reason to press the chip: "بلاغات
/// عاجلة (٣)" is a sentence about what is waiting, and a bare label is not.
class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.state});

  final NotificationsState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final cubit = context.read<NotificationsCubit>();

    String label(String text, int unread) =>
        unread == 0 ? text : l.notificationFilterCount(text, unread);

    return ResponsivePage(
      builder: (context, size) => Padding(
        padding: EdgeInsets.fromLTRB(
          size.gutter,
          AppSpacing.md,
          size.gutter,
          AppSpacing.sm,
        ),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              ChoiceChip(
                label: Text(label(l.notificationFilterAll, state.unread)),
                selected: state.filter == NotificationFilter.all,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => cubit.setFilter(NotificationFilter.all),
              ),
              ChoiceChip(
                label: Text(
                  label(l.notificationFilterMessages, state.unreadMessages),
                ),
                selected: state.filter == NotificationFilter.messages,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => cubit.setFilter(NotificationFilter.messages),
              ),
              // Drawn in the error colour when there is one unread, and only
              // then. A chip permanently painted red is a decoration; a chip
              // that turns red the minute something is waiting is the screen
              // telling the room to look.
              ChoiceChip(
                avatar: Icon(
                  AppIcons.warning,
                  size: 16,
                  color: state.unreadIncidents > 0 ? scheme.error : null,
                ),
                label: Text(
                  label(l.notificationFilterIncidents, state.unreadIncidents),
                ),
                labelStyle: state.unreadIncidents > 0
                    ? TextStyle(
                        color: state.filter == NotificationFilter.incidents
                            ? null
                            : scheme.error,
                        fontWeight: FontWeight.w700,
                      )
                    : null,
                selected: state.filter == NotificationFilter.incidents,
                visualDensity: VisualDensity.compact,
                onSelected: (_) =>
                    cubit.setFilter(NotificationFilter.incidents),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The inbox cut into days, each day's cards under its name.
class _Days extends StatelessWidget {
  const _Days({required this.days, required this.repo, required this.onOpen});

  final List<NotificationDay> days;
  final NotificationsRepository repo;
  final Future<void> Function(BuildContext context, AppNotification n) onOpen;

  @override
  Widget build(BuildContext context) {
    // Two columns at most, and the page stops at 1200 — narrower than any
    // other list here. These cards hold sentences somebody wrote, not fields; a
    // notification stretched across a monitor is a line of prose two feet long,
    // and the eye loses the next one on the way back. Twice as many messages on
    // the screen is the whole gain available, and it is worth having.
    return ResponsivePage(
      builder: (context, size) => AdaptiveGridView.sectioned(
        padding: EdgeInsets.fromLTRB(
          size.gutter,
          12,
          size.gutter,
          24 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        onRefresh: () => context.read<NotificationsCubit>().refresh(),
        spacing: 10,
        sections: [
          for (var d = 0; d < days.length; d++)
            GridSection(
              header: Padding(
                // Room above every heading but the first: without it a
                // day's name sits as close to the last card of the day
                // before as to the first card of its own, and the cut
                // it is there to mark stops reading as a cut.
                padding: EdgeInsets.only(top: d == 0 ? 0 : AppSpacing.md),
                child: SectionHeader(_dayLabel(context, days[d].day)),
              ),
              itemCount: days[d].items.length,
              itemBuilder: (context, i) {
                final n = days[d].items[i];
                return FadeSlideIn(
                  // Cap the cascade so a row first built deep in the
                  // scroll doesn't sit invisible for seconds (same rule
                  // as the directory).
                  delay: Duration(milliseconds: 25 * (i < 8 ? i : 8)),
                  child: _NotificationCard(
                    notification: n,
                    repo: repo,
                    // Tappable whenever there is something to do —
                    // opening what it is about, marking it read, or
                    // both. A notice already read still points at its
                    // file, so being read must not make it inert.
                    onTap: (n.isRead && !n.hasTarget)
                        ? null
                        : () => onOpen(context, n),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// What to call a day at the head of its cards.
///
/// "اليوم" and "أمس" first, because those two are how a reader actually holds
/// the last forty-eight hours — a date printed over this morning's messages
/// makes them look filed rather than new. Past that the day is named: the
/// weekday and the month spelled out, since by then the question has stopped
/// being "how long ago" and become "which day was that".
///
/// The year appears only when it is not this one. Carrying it on every heading
/// costs the same four characters on every line to answer a question that is
/// asked once a year.
String _dayLabel(BuildContext context, DateTime day) {
  final l = context.l10n;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final days = today.difference(day).inDays;
  if (days == 0) return l.commonToday;
  if (days == 1) return l.commonYesterday;
  return DateFormat(
    day.year == today.year ? 'EEEE d MMMM' : 'EEEE d MMMM y',
    Localizations.localeOf(context).toString(),
  ).format(day);
}

/// One notification.
///
/// The card used to draw everything identically: the same bell, the same
/// colour, the same weight for a bus that has overturned and for an
/// announcement that a form was published. And half of them went nowhere when
/// tapped, with nothing on the card to say which half — so the reader learned
/// that tapping was not worth trying.
///
/// Three things fixed, in the order they matter:
///
///   * the KIND is drawn — a tinted medallion carrying the right glyph, and the
///     error colour reserved for the one kind that means somebody is waiting;
///   * where the tap GOES is written on the card, in words, above a chevron.
///     A destination the reader can read is a destination they will use;
///   * the time moved up beside the title, which leaves the foot of the card
///     free for that line instead of stacking two muted rows.
class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.repo,
    this.onTap,
  });

  final AppNotification notification;
  final NotificationsRepository repo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final n = notification;
    final unread = !n.isRead;
    final urgent = n.isIncident;

    // The error colour is spent on emergencies alone. An unread announcement is
    // worth the primary; a read one is worth neither, and going grey is how a
    // list of forty says which four still want reading.
    final accent = urgent
        ? scheme.error
        : unread
        ? scheme.primary
        : scheme.onSurfaceVariant;

    final glyph = switch (n.kind) {
      NotificationKind.incident => AppIcons.warning,
      NotificationKind.module => AppIcons.modules,
      NotificationKind.broadcast => AppIcons.notifications,
    };

    return GlassCard(
      onTap: onTap,
      // An alarm keeps its tint after it has been read. The others drop theirs:
      // being read is the end of an announcement and is not the end of an
      // emergency, and the register — not the inbox — is where that ends.
      tint: urgent ? scheme.error : (unread ? scheme.primary : null),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Medallion(icon: glyph, color: accent, filled: urgent || unread),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          n.title,
                          style: text.titleSmall?.copyWith(
                            fontWeight: unread
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: urgent ? scheme.error : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      // Beside the title rather than under the body. The eye
                      // reads title-then-time as one line the way it reads a
                      // message header, and the foot of the card is worth more
                      // to the destination row than to four digits.
                      Text(
                        _fmt(n.createdAt),
                        style: text.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (unread) ...[
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 4),
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (n.body case final body? when body.trim().isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      body,
                      // Capped, and this is the card that needed it: an alarm's
                      // body is the first 120 characters of what somebody typed
                      // while running, and one card five lines tall pushes the
                      // next three off the screen.
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium?.copyWith(height: 1.35),
                    ),
                  ],
                  AttachmentsView(
                    attachments: n.attachments,
                    // Not always this repository's own bucket: a "بلاغ عاجل"
                    // shows the report's photographs, and those are signed for
                    // against `incidents`.
                    signer: repo.signerFor(n),
                  ),
                  // Where the tap goes, said in words. Without it the only way
                  // to find out was to press and see, and an alarm that went
                  // nowhere at all taught the reader not to bother pressing.
                  if (n.destination case final destination
                      when destination != NotificationDestination.none) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Text(
                          switch (destination) {
                            NotificationDestination.incident =>
                              l.notificationOpenIncident,
                            _ => l.notificationOpenModule,
                          },
                          style: text.labelMedium?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        NavChevron(color: accent),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The time alone. The date used to be here because nothing else on the
  /// screen said it; the heading above the card says it now, and printing it
  /// again on all ninety cards under that heading is ninety repetitions of one
  /// fact.
  String _fmt(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

/// The glyph in its own tinted disc.
///
/// A bare icon floating beside a title reads as decoration; a disc reads as a
/// stamp on a piece of paper, which is what a notification is. Filled while the
/// thing still wants attention and outlined once it does not — so a screenful
/// of read announcements goes quiet without going invisible.
class _Medallion extends StatelessWidget {
  const _Medallion({
    required this.icon,
    required this.color,
    required this.filled,
  });

  final IconData icon;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: filled ? 0.16 : 0.08),
        border: Border.all(color: color.withValues(alpha: filled ? 0.38 : 0.2)),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: FadeSlideIn(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.notifications, size: 64, color: scheme.outline),
            const SizedBox(height: 16),
            Text(message, style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}
