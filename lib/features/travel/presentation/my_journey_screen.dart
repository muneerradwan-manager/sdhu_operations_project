import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/animations/animations.dart';
import '../../../core/l10n/error_text.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/states.dart';
import '../application/journey_cubit.dart';
import '../data/travel_repository.dart';
import '../domain/journey_leg.dart';
import 'travel_labels.dart';
import 'widgets/journey_header.dart';
import 'widgets/journey_season_chart.dart';
import 'widgets/journey_timeline.dart';
import 'widgets/record_leg_sheet.dart';

/// One man's journey, from home and back.
///
/// Opened by the traveller for himself (مساري) and by whoever holds
/// `travel.view` for somebody else — the same screen either way, because the
/// question is the same and the only difference is whose name is on it. What
/// differs is what may be DONE here, and that is decided by the database: a
/// confirmation the reader is not allowed to make comes back as a refusal
/// rather than being predicted and hidden.
class JourneyScreen extends StatelessWidget {
  const JourneyScreen({
    super.key,
    this.participantId,
    this.profileId,
    this.title,
  });

  /// Whose journey. Both null means the reader's own.
  final String? participantId;
  final String? profileId;

  /// The person's name, when this was opened from their page.
  final String? title;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => JourneyCubit(
      TravelRepository(),
      participantId: participantId,
      profileId: profileId,
    ),
    child: _View(title: title),
  );
}

class _View extends StatelessWidget {
  const _View({this.title});

  final String? title;

  Future<void> _record(BuildContext context) async {
    final cubit = context.read<JourneyCubit>();
    final draft = await showRecordLegSheet(
      context,
      points: cubit.state.points,
      // What he already has. The sheet offers an internal movement only out
      // of the city these legs leave him in — see [showRecordLegSheet].
      legs: cubit.state.journey?.legs ?? const [],
    );
    if (draft == null) return;
    await cubit.recordSelfLeg(draft);
  }

  /// Confirming a movement is two questions, not one: did it happen, or did he
  /// not travel on it? Both are offered, because a board that can only say
  /// "yes" quietly turns every no-show into a permanent unanswered row.
  Future<void> _confirm(BuildContext context, JourneyLeg leg) async {
    final l = context.l10n;
    final cubit = context.read<JourneyCubit>();
    final choice = await showDialog<LegStatus>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(legRoleLabel(dialogContext, leg.role)),
        content: Text(l.travelConfirmArrival),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(LegStatus.missed),
            child: Text(l.travelLegMissed),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(LegStatus.completed),
            child: Text(l.travelLegCompleted),
          ),
        ],
      ),
    );
    if (choice == null) return;
    await cubit.confirm(leg.id, status: choice);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Scaffold(
      appBar: GlassAppBar(title: Text(title ?? l.travelMyJourneyTitle)),
      body: SafeArea(
        child: BlocConsumer<JourneyCubit, JourneyState>(
          listenWhen: (p, c) => c.error != null && p.error != c.error,
          listener: (context, state) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(content: Text(friendlyError(context, state.error))),
              );
          },
          builder: (context, state) {
            if (state.status == JourneyStatus.loading) {
              return const SkeletonList(height: 96);
            }

            final journey = state.journey;
            if (journey == null || journey.isEmpty) {
              // Not a broken screen and not an error — most of the roster looks
              // like this until the flights are entered.
              return EmptyState(
                icon: AppIcons.travel,
                title: l.travelNoJourney,
                message: l.travelNoJourneyHint,
              );
            }

            return ResponsivePage(
              builder: (context, size) => SinglePaneLayout(
                gutter: size.gutter,
                bottom:
                    AppSpacing.xl + MediaQuery.viewPaddingOf(context).bottom,
                children: staggered([
                  JourneyHeader(journey: journey),
                  const SizedBox(height: AppSpacing.lg),
                  // The shape of the season before its detail: two cities and
                  // how the days fell between them, answered by the length of
                  // a bar rather than by subtracting one date from another in
                  // your head. Draws nothing until there are two cities to
                  // compare.
                  JourneySeasonChart(journey: journey),
                  // No pane around it any more: every stay is its own card
                  // now, and a card inside a card is a border the page does
                  // not need.
                  JourneyTimeline(
                    journey: journey,
                    busyLegId: state.busyLegId,
                    onConfirm: (leg) => _confirm(context, leg),
                  ),
                  // Offered wherever the journey is still open, not only
                  // where the line shows a gap — a man may need to record a
                  // movement the app has no reason to expect at all. Once
                  // العودة has actually happened ([Journey.isHome]) there is
                  // nothing left to travel for, and the button disappears
                  // with the question it answers rather than sitting there
                  // unanswerable.
                  if (!journey.isHome) ...[
                    const SizedBox(height: AppSpacing.lg),
                    OutlinedButton.icon(
                      onPressed: () => _record(context),
                      icon: const Icon(AppIcons.add),
                      label: Text(l.travelRecordTransfer),
                    ),
                  ],
                ]),
              ),
            );
          },
        ),
      ),
    );
  }
}
