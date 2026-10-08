import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/animations/animations.dart';
import '../../../core/l10n/error_text.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/states.dart';
import '../../auth/application/session_cubit.dart';
import '../application/seasons_cubit.dart';
import '../data/seasons_repository.dart';
import '../domain/season.dart';
import 'season_detail_screen.dart';

class SeasonsScreen extends StatelessWidget {
  const SeasonsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.read<SessionCubit>().state.isAdmin;
    return BlocProvider(
      create: (_) => SeasonsCubit(SeasonsRepository(), isAdmin: isAdmin),
      child: const _View(),
    );
  }
}

class _View extends StatelessWidget {
  const _View();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      // Extended behind the bar so the list frosts as it scrolls under it.
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(title: Text(l.seasonsTitle)),
      body: BlocConsumer<SeasonsCubit, SeasonsState>(
        listenWhen: (p, c) => c.error != null && p.error != c.error,
        listener: (context, state) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(friendlyError(context, state.error))));
        },
        builder: (context, state) {
          if (state.status == SeasonsStatus.loading) {
            return const SkeletonList(
              count: 4,
              height: 88,
              panel: true,
            );
          }

          Future<void> reload() => context.read<SeasonsCubit>().load();

          return ResponsivePage(
            builder: (context, size) {
              // The season under way is this screen's anchor — every other row
              // on it is defined by being before or after that one — so on a
              // window with a column to spare it stands in that column and the
              // archive scrolls past it, rather than scrolling away itself.
              final standing = size.hasSidePanel && state.current != null;

              final lists = <Widget>[
                // Only shown when it has rows: a season later than the current
                // one exists whenever an earlier one is pinned.
                if (state.upcoming.isNotEmpty) ...[
                  FadeSlideIn(
                    child: SectionHeader(
                      l.seasonUpcomingLabel,
                      icon: AppIcons.seasons,
                    ),
                  ),
                  AdaptiveGrid(
                    children: staggered([
                      for (final s in state.upcoming)
                        _SeasonTile(season: s, onTap: () => _open(context, s)),
                    ]),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                FadeSlideIn(
                  child: SectionHeader(
                    l.seasonArchiveLabel,
                    icon: AppIcons.seasons,
                  ),
                ),
                if (state.archive.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xl),
                    child: EmptyState(
                      icon: AppIcons.seasons,
                      title: l.seasonArchiveEmpty,
                    ),
                  )
                else
                  AdaptiveGrid(
                    children: staggered([
                      for (final s in state.archive)
                        _SeasonTile(season: s, onTap: () => _open(context, s)),
                    ]),
                  ),
              ];

              final current = state.current == null
                  ? null
                  : FadeSlideIn(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SectionHeader(
                            l.seasonCurrentLabel,
                            icon: AppIcons.current,
                          ),
                          _CurrentSeasonCard(
                            season: state.current!,
                            stacked: standing,
                            onTap: () => _open(context, state.current!),
                          ),
                        ],
                      ),
                    );

              return standing
                  ? TwoPaneLayout(
                      gutter: size.gutter,
                      panel: current!,
                      onRefresh: reload,
                      children: lists,
                    )
                  : SinglePaneLayout(
                      gutter: size.gutter,
                      onRefresh: reload,
                      children: [
                        if (current != null) ...[
                          current,
                          const SizedBox(height: AppSpacing.xl),
                        ],
                        ...lists,
                      ],
                    );
            },
          );
        },
      ),
    );
  }

  void _open(BuildContext context, Season season) {
    final cubit = context.read<SeasonsCubit>();
    Navigator.of(context).push(
      fadeThroughRoute(
        (_) => BlocProvider.value(
          value: cubit,
          child: SeasonDetailScreen(season: season),
        ),
      ),
    );
  }
}

/// The hero of the screen: the season currently under way. Rendered as a
/// gold-washed pane with a luminous medallion so it clearly outranks the
/// archive rows below it.
class _CurrentSeasonCard extends StatelessWidget {
  const _CurrentSeasonCard({
    required this.season,
    required this.onTap,
    this.stacked = false,
  });

  final Season season;
  final VoidCallback onTap;

  /// Sphere above the year rather than beside it, for the standing panel: at
  /// three hundred pixels the row form leaves the year about a hundred and
  /// fifty to sit in, and a headline does not fit in a hundred and fifty.
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l = context.l10n;

    final sphere = Container(
      width: stacked ? 72 : 58,
      height: stacked ? 72 : 58,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppGradients.goldSphere,
        boxShadow: [
          BoxShadow(
            color: scheme.secondary.withValues(alpha: 0.4),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      // Dark ink, not white: the gold sphere is a light surface.
      child: Icon(
        AppIcons.current,
        color: AppColors.ink,
        size: stacked ? 34 : 28,
      ),
    );

    final label = Column(
      crossAxisAlignment: stacked
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        GlassBadge(
          label: l.seasonCurrentLabel,
          color: scheme.secondary,
          dense: true,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(l.seasonHijriYear(season.hijriYear), style: text.headlineSmall),
        if (season.gregorianLabel != null) ...[
          const SizedBox(height: 2),
          Text(
            season.gregorianLabel!,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            textAlign: stacked ? TextAlign.center : TextAlign.start,
          ),
        ],
      ],
    );

    return GlassCard(
      onTap: onTap,
      radius: AppRadius.xl,
      tint: scheme.secondary,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: sphere),
                const SizedBox(height: AppSpacing.lg),
                label,
                const SizedBox(height: AppSpacing.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      l.seasonsTitle,
                      style: text.labelSmall?.copyWith(color: scheme.secondary),
                    ),
                    NavChevron(color: scheme.secondary),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                sphere,
                const SizedBox(width: AppSpacing.lg),
                Expanded(child: label),
                const NavChevron(),
              ],
            ),
    );
  }
}

/// A season row in either list below the hero — upcoming or previous.
class _SeasonTile extends StatelessWidget {
  const _SeasonTile({required this.season, required this.onTap});

  final Season season;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final l = context.l10n;

    return GlassCard(
      onTap: onTap,
      // Repeated list item: skip the backdrop blur to keep scrolling smooth.
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          GlassSurface(
            radius: AppRadius.sm,
            width: 44,
            height: 44,
            blur: false,
            shadow: false,
            subtle: true,
            child: Icon(AppIcons.seasons, size: 20, color: scheme.primary),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.seasonHijriYear(season.hijriYear),
                  style: text.titleMedium,
                ),
                if (season.gregorianLabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    season.gregorianLabel!,
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const NavChevron(),
        ],
      ),
    );
  }
}
