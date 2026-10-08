import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/animations/animations.dart';
import '../../../core/l10n/error_text.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/states.dart';
import '../application/check_in_cubit.dart';
import '../data/check_in_repository.dart';
import '../domain/check_in.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/widgets/info_section.dart';

/// Who is present, across the whole season.
///
/// One board rather than one per file, and that is the point of it. Presence
/// used to be read inside an operational file, which meant a supervisor
/// answering "is anybody at the camps tonight" opened a file, read a list,
/// went back, opened another. Since 0098 an arrival is a fact about a PLACE,
/// so the natural screen is the season's places — and a hotel in المدينة, which
/// belongs to no file at all, finally appears on it.
///
/// Grouped by PLACE, not by person. The room's question is "who is in this
/// hotel"; a flat list of names sorted by time answers a question nobody asked.
class PresenceBoardScreen extends StatelessWidget {
  const PresenceBoardScreen({super.key, this.itemId, this.placeName});

  /// Set when the board was opened from one place — a pin on the map, a hotel's
  /// page — rather than from the shelf.
  final String? itemId;
  final String? placeName;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => PresenceCubit(CheckInRepository(), itemId: itemId),
    child: _View(title: placeName),
  );
}

class _View extends StatelessWidget {
  const _View({this.title});

  final String? title;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Scaffold(
      appBar: GlassAppBar(title: Text(title ?? l.presenceTitle)),
      body: BlocBuilder<PresenceCubit, PresenceState>(
        builder: (context, state) {
          final cubit = context.read<PresenceCubit>();

          if (state.status == PresenceStatus.loading) {
            return const SkeletonList(height: 84);
          }
          if (state.status == PresenceStatus.error) {
            return EmptyState(
              icon: AppIcons.warning,
              title: friendlyError(context, state.error),
            );
          }

          final places = state.byPlace;
          final gaps = state.shownGaps;

          return ResponsivePage(
            builder: (context, size) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    size.gutter,
                    AppSpacing.md,
                    size.gutter,
                    0,
                  ),
                  child: _Filters(state: state, cubit: cubit),
                ),
                // The board turns over rather than opening a second screen.
                // "Who is in this hotel" and "who should be and is not" are
                // asked one after the other, by the same person, about the same
                // place, inside the same minute — and the count rides on the
                // tab because seeing that it is zero is often the whole errand.
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    size.gutter,
                    AppSpacing.sm,
                    size.gutter,
                    0,
                  ),
                  child: _SideToggle(state: state, cubit: cubit),
                ),
                Expanded(
                  child: state.showingGaps
                      ? _GapsList(
                          gaps: gaps,
                          gutter: size.gutter,
                          onRefresh: cubit.load,
                        )
                      : places.isEmpty
                      ? EmptyState(
                          icon: AppIcons.checkIn,
                          title: l.presenceEmpty,
                          message: l.presenceEmptyHint,
                        )
                      // A grid, like every other list in the app. This was a
                      // [ListView] — one place per row at every width — so a
                      // season with fourteen hotels and camps came out as a
                      // single column of cards down the middle of a monitor
                      // with two thirds of it blank, and a supervisor asking
                      // "is anybody at the camps tonight" scrolled past four
                      // places to reach the fifth. At [CardWidth.list] the same
                      // fourteen are four across and read at a glance, which is
                      // what a board is for.
                      : AdaptiveGridView(
                          padding: EdgeInsets.fromLTRB(
                            size.gutter,
                            AppSpacing.md,
                            size.gutter,
                            AppSpacing.xxl +
                                MediaQuery.viewPaddingOf(context).bottom,
                          ),
                          onRefresh: cubit.load,
                          spacing: AppSpacing.md,
                          // Natural heights, and this is the one list in the
                          // app that has to say so. A place card is as tall as
                          // the number of people standing in that place: منى
                          // with thirty names beside a hotel with one. Held to
                          // a shared height, the row would be four cards the
                          // depth of the tallest, three of them mostly empty
                          // glass — the equal-height rule earns its keep on
                          // cards that differ by a badge, not by a factor of
                          // thirty.
                          equalHeights: false,
                          itemCount: places.length,
                          itemBuilder: (context, i) => FadeSlideIn(
                            delay: Duration(milliseconds: 30 * (i < 8 ? i : 8)),
                            child: _PlaceCard(group: places[i]),
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  const _Filters({required this.state, required this.cubit});

  final PresenceState state;
  final PresenceCubit cubit;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final groups = state.groups;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSearchField(hint: l.commonSearch, onChanged: cubit.setQuery),
        const SizedBox(height: AppSpacing.sm),
        // How far back "now" reaches. A shift is what the word means to the
        // room, and which shift is the reader's to choose — an evening
        // inspection wants today, a night in منى wants the last few hours.
        SegmentedButton<Duration>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: const Duration(hours: 4),
              label: Text(l.presenceWindow4h),
            ),
            ButtonSegment(
              value: const Duration(hours: 12),
              label: Text(l.presenceWindow12h),
            ),
            ButtonSegment(
              value: const Duration(hours: 24),
              label: Text(l.presenceWindow24h),
            ),
          ],
          selected: {state.window},
          onSelectionChanged: (s) => cubit.setWindow(s.first),
        ),
        if (groups.length > 1) ...[
          const SizedBox(height: AppSpacing.sm),
          // The same four the map shows — فنادق مكة, فنادق المدينة, مخيمات منى,
          // مخيمات عرفات — and for the same reason nothing here names them:
          // they fall out of each entry's own dividing reference, so a fifth
          // appears the day a fifth exists.
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final group in groups)
                FilterChip(
                  selected: !state.hiddenGroups.contains(group),
                  label: Text(group),
                  onSelected: (_) => cubit.toggleGroup(group),
                ),
              if (state.hiddenGroups.isNotEmpty)
                TextButton(
                  onPressed: cubit.showAllGroups,
                  child: Text(l.seasonMapShowAll),
                ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        Text(
          l.presenceCounts(state.showing, state.byPlace.length),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.group});

  final PresenceGroup group;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // No bottom margin of its own: the grid around it spaces the rows, and a
    // card carrying its own gap as well would double it between rows and leave
    // it out between columns.
    return GlassCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.18),
                  ),
                ),
                child: Icon(AppIcons.location, size: 19, color: scheme.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.placeName,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (group.groupName != null)
                      Text(
                        group.groupName!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              // The headcount as a pill rather than a bare digit — it is the
              // answer the room opened this board for.
              GlassBadge(label: '${group.lines.length}', dense: true),
            ],
          ),
          const Divider(height: AppSpacing.lg),
          for (final line in group.lines) _Line(line: line),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.line});

  final PresenceLine line;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.fullName,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  // Distance is shown plainly and without a warning beside it.
                  // Every row on this board was measured against the place's
                  // own radius and passed, by construction — the flag that used
                  // to live here could not fire any more, and a warning that
                  // never fires teaches a room to stop reading warnings.
                  l.checkInDistance(line.distanceM.round().toString()),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if ((line.note ?? '').isNotEmpty)
                  Text(
                    line.note!,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
              ],
            ),
          ),
          Text(
            DateFormat.jm().format(line.createdAt),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Which side of the board is showing.
///
/// A segmented control rather than tabs: there are exactly two, they are
/// answers to one question, and the count on the second is the reason anybody
/// presses it. Tabs would put that count in a bar the reader has to look up at;
/// here it is on the thing they are deciding whether to press.
class _SideToggle extends StatelessWidget {
  const _SideToggle({required this.state, required this.cubit});

  final PresenceState state;
  final PresenceCubit cubit;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final gaps = state.gapCount;

    return SegmentedButton<bool>(
      segments: [
        ButtonSegment(
          value: false,
          icon: const Icon(AppIcons.checkIn, size: 16),
          label: Text(l.presenceTabPresent),
        ),
        ButtonSegment(
          value: true,
          // Coloured only when there is something to colour. A permanent red
          // badge reading zero teaches the reader that the colour means
          // nothing, which is exactly what it must not mean the morning it
          // reads eleven.
          icon: Icon(
            AppIcons.warning,
            size: 16,
            color: gaps > 0 ? scheme.error : null,
          ),
          label: Text(
            gaps > 0 ? '${l.presenceTabGaps} ($gaps)' : l.presenceTabGaps,
          ),
        ),
      ],
      selected: {state.showingGaps},
      showSelectedIcon: false,
      onSelectionChanged: (s) => cubit.showGaps(s.first),
    );
  }
}

/// The posts nobody has confirmed, worst first.
///
/// Ordered by the database — never seen, then longest quiet — and left in that
/// order here. The top of this list is where the room starts telephoning.
class _GapsList extends StatelessWidget {
  const _GapsList({
    required this.gaps,
    required this.gutter,
    required this.onRefresh,
  });

  final List<PresenceGap> gaps;
  final double gutter;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    if (gaps.isEmpty) {
      return EmptyState(
        icon: AppIcons.checkIn,
        title: l.presenceGapsEmpty,
        message: l.presenceGapsEmptyHint,
      );
    }

    // The same grid as the other side of the board, so turning the toggle over
    // does not also change how many cards a row holds. These are uniform — a
    // name, a place, a time and two telephone buttons — so they keep the shared
    // height that the place cards opposite cannot.
    return AdaptiveGridView(
      padding: EdgeInsets.fromLTRB(
        gutter,
        AppSpacing.md,
        gutter,
        AppSpacing.xxl + MediaQuery.viewPaddingOf(context).bottom,
      ),
      onRefresh: onRefresh,
      spacing: AppSpacing.md,
      itemCount: gaps.length,
      itemBuilder: (context, i) => FadeSlideIn(
        delay: Duration(milliseconds: 30 * (i < 8 ? i : 8)),
        child: _GapCard(gap: gaps[i]),
      ),
    );
  }
}

/// One unconfirmed post, and the telephone that answers it.
class _GapCard extends StatelessWidget {
  const _GapCard({required this.gap});

  final PresenceGap gap;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    // Never seen is the sharper of the two and is coloured as such. A man nine
    // hours quiet may be asleep after a night shift; a man who has never
    // checked in at all may never have been given the code, which is a thing
    // somebody has to go and fix rather than a thing to wonder about.
    final never = gap.neverSeen;
    final when = never
        ? l.presenceGapNeverSeen
        : l.presenceGapLastSeen(
            DateFormat(
              'MM/dd HH:mm',
              Localizations.localeOf(context).toString(),
            ).format(gap.lastSeen!),
          );

    final phone = gap.phoneSa?.trim().isNotEmpty == true
        ? gap.phoneSa!
        : (gap.phoneSy ?? '');

    // Spaced by the grid, not by the card — see [_PlaceCard].
    return GlassCard(
      // A man never seen at all washes his card red the way an open incident
      // does: on a board of gaps, the sharpest gap must be findable before it
      // is readable.
      tint: never ? scheme.error : null,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  gap.fullName,
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    gap.placeName,
                    if (gap.roleName case final r? when r.isNotEmpty) r,
                  ].join(' · '),
                  style: text.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  when,
                  style: text.labelSmall?.copyWith(
                    color: never ? scheme.error : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          // The telephone, because every row here is a name somebody is about
          // to ring. Absent when there is no number rather than drawn dead:
          // a button that does nothing is worse than no button.
          if (phone.isNotEmpty) ...[
            const SizedBox(width: AppSpacing.sm),
            if (InfoAction.whatsAppUri(phone) case final uri?)
              IconButton(
                tooltip: context.l10n.contactWhatsApp,
                onPressed: () =>
                    launchUrl(uri, mode: LaunchMode.externalApplication),
                icon: const Icon(AppIcons.whatsApp),
                color: scheme.primary,
              ),
            IconButton(
              tooltip: l.incidentCall,
              onPressed: () => launchUrl(InfoAction.call.uriFor(phone)),
              icon: const Icon(AppIcons.phoneSy),
              color: scheme.primary,
            ),
          ],
        ],
      ),
    );
  }
}
