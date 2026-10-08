import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/animations/animations.dart';
import '../../../core/l10n/error_text.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/widgets/profile_avatar.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/search_field.dart';
import '../application/season_participants_cubit.dart';
import '../data/seasons_repository.dart';
import '../domain/season.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/states.dart';

class SeasonParticipantsScreen extends StatelessWidget {
  const SeasonParticipantsScreen({super.key, required this.season});
  final Season season;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SeasonParticipantsCubit(SeasonsRepository(), season.id),
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
      appBar: GlassAppBar(title: Text(l.seasonSelectParticipants)),
      body: SafeArea(
        child: ResponsivePage(
          builder: (context, size) => Column(
            children: [
              SearchFilterBar(
                hint: l.commonSearch,
                onChanged: (v) =>
                    context.read<SeasonParticipantsCubit>().search(v),
              ),
              BlocBuilder<SeasonParticipantsCubit, SeasonParticipantsState>(
                builder: (context, state) {
                  if (state.status != ParticipantsStatus.ready ||
                      state.filtered.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  final cubit = context.read<SeasonParticipantsCubit>();
                  return CheckboxListTile(
                    value: cubit.allSelected,
                    onChanged: (_) => cubit.toggleAll(),
                    title: Text(
                      l.commonSelectAll,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                },
              ),
              Expanded(
                child:
                    BlocConsumer<
                      SeasonParticipantsCubit,
                      SeasonParticipantsState
                    >(
                      listenWhen: (p, c) =>
                          c.error != null && p.error != c.error,
                      listener: (context, state) {
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(SnackBar(content: Text(friendlyError(context, state.error))));
                      },
                      builder: (context, state) {
                        if (state.status == ParticipantsStatus.loading) {
                          return const SkeletonList(height: 84);
                        }
                        final items = state.filtered;
                        return AdaptiveGridView(
                          padding: EdgeInsets.fromLTRB(
                            size.gutter,
                            8,
                            size.gutter,
                            16 + MediaQuery.viewPaddingOf(context).bottom,
                          ),
                          spacing: 10,
                          itemCount: items.length,
                          itemBuilder: (context, i) {
                            final e = items[i];
                            final selected = state.participantIds.contains(
                              e.id,
                            );
                            final busy = state.busy.contains(e.id);
                            return FadeSlideIn(
                              // Cap the cascade so a row first built deep in the scroll doesn't
                              // sit invisible for seconds (same rule as the directory).
                              delay: Duration(milliseconds: 25 * (i < 8 ? i : 8)),
                              child: GlassCard(
                                child: CheckboxListTile(
                                  value: selected,
                                  onChanged: busy
                                      ? null
                                      : (_) => context
                                            .read<SeasonParticipantsCubit>()
                                            .toggle(e.id),
                                  secondary: busy
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                          ),
                                        )
                                      : ProfileAvatar(
                                          photoUrl: e.photoUrl,
                                          name: e.fullName,
                                          radius: 20,
                                        ),
                                  title: Text(
                                    e.fullName.isEmpty ? '—' : e.fullName,
                                  ),
                                  subtitle: e.jobTitleName == null
                                      ? null
                                      : Text(e.jobTitleName!.of(context)),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
