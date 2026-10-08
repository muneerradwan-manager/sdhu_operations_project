import 'package:flutter/material.dart';

import '../../../../core/animations/animations.dart';
import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/glass_tokens.dart';
import '../../../../core/widgets/info_section.dart';
import '../../data/travel_repository.dart';
import '../../domain/journey.dart';
import '../my_journey_screen.dart';
import '../travel_labels.dart';
import 'journey_header.dart';

/// This man's travel, on his own page.
///
/// Built the way [ComplaintsAgainstSection] and [EvaluationsAboutSection] are —
/// a widget that fetches its own data and is dropped into the employee page's
/// list of sections — because the alternative is threading a fourth cubit
/// through a screen that already carries three.
///
/// [canRead] is the whole gate. It is `travel.view`, and it is deliberately
/// separate from being able to see the employee at all: knowing who somebody
/// is and knowing when they fly home are different things to be trusted with.
class TravelSection extends StatefulWidget {
  const TravelSection({
    super.key,
    required this.profileId,
    required this.canRead,
  });

  final String profileId;
  final bool canRead;

  @override
  State<TravelSection> createState() => _TravelSectionState();
}

class _TravelSectionState extends State<TravelSection> {
  final _repo = TravelRepository();
  late Future<Journey?> _future = _load();

  Future<Journey?> _load() async {
    if (!widget.canRead) return null;
    final participantId = await _repo.participationOf(widget.profileId);
    if (participantId == null) return null;
    return _repo.fetchJourney(participantId);
  }

  @override
  void didUpdateWidget(TravelSection old) {
    super.didUpdateWidget(old);
    if (old.profileId != widget.profileId || old.canRead != widget.canRead) {
      setState(() => _future = _load());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (!widget.canRead) return const SizedBox.shrink();

    return FutureBuilder<Journey?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return InfoSection(
            title: l.travelSectionTitle,
            icon: AppIcons.travel,
            children: const [
              Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  ),
                ),
              ),
            ],
          );
        }

        final journey = snapshot.data;
        final scheme = Theme.of(context).colorScheme;

        // Not in the season, or in it with nothing recorded. Both are ordinary
        // and both are said in a sentence — an employee page that showed an
        // error here would be lying about a great many perfectly normal people.
        if (journey == null || journey.isEmpty) {
          return InfoSection(
            title: l.travelSectionTitle,
            icon: AppIcons.travel,
            children: [
              Text(
                journey == null ? l.travelNotInSeason : l.travelNoJourney,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          );
        }

        return InfoSection(
          title: l.travelSectionTitle,
          icon: AppIcons.travel,
          separated: false,
          maxColumns: 1,
          children: [
            JourneyStrip(journey: journey),
            const SizedBox(height: AppSpacing.md),
            InfoRow(
              icon: AppIcons.travelAir,
              label: l.travelRoleInbound,
              value: travelWhen(context, journey.arrivedAt, withTime: false),
            ),
            InfoRow(
              icon: AppIcons.location,
              label: l.travelCurrentLocation,
              value: journey.currentPlace?.of(context),
            ),
            // Where to find him tonight, which is the more useful half of the
            // answer once the city is known — and the whole reason 0135 made
            // the stay the spine rather than the terminal.
            if (journey.currentResidence != null)
              InfoRow(
                icon: AppIcons.organization,
                label: l.travelStayPlaceTitle,
                value: journey.currentResidence?.of(context),
              ),
            InfoRow(
              icon: AppIcons.travelReturn,
              label: l.travelRoleOutbound,
              // «لم تُحدَّد بعد» rather than a dash: a blank reads as missing
              // data, and this is not missing — it has not happened yet.
              value: journey.returnAt == null
                  ? l.travelNoReturnYet
                  : travelWhen(context, journey.returnAt, withTime: false),
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  fadeThroughRoute(
                    (_) => JourneyScreen(profileId: widget.profileId),
                  ),
                ),
                icon: const Icon(AppIcons.travel, size: 18),
                label: Text(l.travelViewFullJourney),
              ),
            ),
          ],
        );
      },
    );
  }
}
