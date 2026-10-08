import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/animations/animations.dart';
import '../../../core/constants/permission_codes.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/employee_tile.dart';
import '../../../core/widgets/responsive.dart';
import '../../auth/application/session_cubit.dart';
import '../../employees/presentation/employee_detail_screen.dart';
import '../../profile/domain/profile.dart';
import '../application/seasons_cubit.dart';
import '../data/seasons_repository.dart';
import '../domain/season.dart';
import 'season_participants_screen.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/states.dart';

class SeasonDetailScreen extends StatefulWidget {
  const SeasonDetailScreen({super.key, required this.season});
  final Season season;

  @override
  State<SeasonDetailScreen> createState() => _SeasonDetailScreenState();
}

class _SeasonDetailScreenState extends State<SeasonDetailScreen> {
  final _repo = SeasonsRepository();
  late Future<List<Profile>> _participants;

  @override
  void initState() {
    super.initState();
    _participants = _repo.fetchParticipants(widget.season.id);
  }

  void _reload() {
    setState(() {
      _participants = _repo.fetchParticipants(widget.season.id);
    });
  }

  Future<void> _manage() async {
    await Navigator.of(context).push(
      fadeThroughRoute((_) => SeasonParticipantsScreen(season: widget.season)),
    );
    _reload();
  }

  Future<void> _setCurrent() async {
    final l = context.l10n;
    await context.read<SeasonsCubit>().setCurrent(widget.season.id);
    if (mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.seasonSetCurrentDone)));
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final session = context.watch<SessionCubit>().state;
    final canManageParticipants = session.can(
      PermissionCodes.seasonsParticipantsManage,
    );
    final canSwitchSeason = session.can(PermissionCodes.seasonsSwitch);

    return Scaffold(
      appBar: GlassAppBar(
        title: Text(l.seasonHijriYear(widget.season.hijriYear)),
        actions: [
          if (canManageParticipants)
            IconButton(
              tooltip: l.seasonManageParticipants,
              onPressed: _manage,
              icon: const Icon(AppIcons.manageParticipants),
            ),
        ],
      ),
      body: SafeArea(
        child: ResponsivePage(
          builder: (context, size) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.season.gregorianLabel != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    size.gutter,
                    AppSpacing.md,
                    size.gutter,
                    0,
                  ),
                  // A date and a badge, held to the width of the two of them.
                  // Left to fill a monitor, the Spacer between them becomes a
                  // metre of nothing with a word at either end.
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: GlassCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            AppIcons.seasons,
                            size: 18,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(widget.season.gregorianLabel!),
                          const Spacer(),
                          if (widget.season.isCurrent)
                            GlassBadge(
                              label: l.seasonBadgeCurrent,
                              icon: AppIcons.current,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: FutureBuilder<List<Profile>>(
                  future: _participants,
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const SkeletonList(height: 132);
                    }
                    if (snap.hasError) {
                      return Center(child: Text('${snap.error}'));
                    }
                    final people = snap.data ?? [];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            size.gutter,
                            AppSpacing.lg,
                            size.gutter,
                            AppSpacing.sm,
                          ),
                          child: SectionHeader(
                            l.seasonParticipantsCount(people.length),
                            icon: AppIcons.participants,
                          ),
                        ),
                        Expanded(
                          child: people.isEmpty
                              ? EmptyState(
                                  icon: AppIcons.participants,
                                  title: l.seasonNoParticipants,
                                )
                              : AdaptiveGridView(
                                  padding: EdgeInsets.fromLTRB(
                                    size.gutter,
                                    0,
                                    size.gutter,
                                    AppSpacing.lg +
                                        MediaQuery.viewPaddingOf(
                                          context,
                                        ).bottom,
                                  ),
                                  itemCount: people.length,
                                  itemBuilder: (context, i) {
                                    final p = people[i];
                                    return FadeSlideIn(
                                      delay: Duration(
                                        milliseconds: 30 * (i < 8 ? i : 8),
                                      ),
                                      // A name on a roster is a person you can
                                      // open — same as the module rosters and
                                      // the directory.
                                      child: EmployeeTile(
                                        name: p.fullName,
                                        photoUrl: p.photoUrl,
                                        subtitle: p.jobTitleName?.of(context),
                                        isExternal: p.isExternal,
                                        onTap: () => Navigator.of(context).push(
                                          fadeThroughRoute(
                                            (_) => EmployeeDetailScreen(
                                              profile: p,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: (!widget.season.isCurrent && canSwitchSeason)
          ? GlassSurface(
              radius: 0,
              strong: true,
              shadow: false,
              bordered: false,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  child: FilledButton.icon(
                    onPressed: _setCurrent,
                    icon: const Icon(AppIcons.current),
                    label: Text(l.seasonSetCurrent),
                  ),
                ),
              ),
            )
          : null,
    );
  }
}
