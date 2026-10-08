import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/animations/animations.dart';
import '../../../core/l10n/error_text.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/creator_page.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/saved_copy_banner.dart';
import '../../../core/widgets/states.dart';
import '../application/my_check_ins_cubit.dart';
import '../data/check_in_repository.dart';
import '../domain/check_in.dart';
import 'check_in_screen.dart';

/// A person's own arrivals.
///
/// The right to read this has existed since 0098 — `place_check_ins`'s policy
/// opens with `profile_id = auth.uid()`, and §30.3 puts it in words: "your own
/// check-ins, always, without a grant". The app had nowhere to spend it. The
/// only screen that read the table was the operations room's board, behind
/// `checkin.board`, so the man who scanned the code could file his arrival and
/// could never afterwards see that he had.
///
/// Which is the one thing he might reasonably want to check — and precisely
/// what he is asked to account for when somebody disputes whether he was there.
class MyCheckInsScreen extends StatelessWidget {
  const MyCheckInsScreen({super.key, this.compose = false});

  /// Open the scanner as soon as the screen is up — see [TasksScreen].
  ///
  /// Set by the button on the home card, which now asks for the RECORD and the
  /// act in that order rather than for the act alone. It used to point straight
  /// at the scanner, which is why a man who scanned a code was handed back the
  /// home page: the list his arrival had just been written onto was never on
  /// the stack to return to.
  final bool compose;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => MyCheckInsCubit(CheckInRepository()),
    child: _View(compose: compose),
  );
}

class _View extends StatefulWidget {
  const _View({this.compose = false});

  final bool compose;

  @override
  State<_View> createState() => _ViewState();
}

class _ViewState extends State<_View> {
  @override
  void initState() {
    super.initState();
    // Not on a device that cannot scan — see [isPlaceScannerSupported]. The
    // request arrives in the URL and the URL does not know what it is opening
    // on, so honouring it on the operations-room desktop would open a camera
    // screen that throws before it draws.
    if (widget.compose && isPlaceScannerSupported) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _record();
      });
    }
  }

  /// The act, above the record. Filing an arrival is a page like writing a task
  /// or a complaint is a page — see [CreatorPage] — and it ends where the other
  /// two end: back on the list, with the new line on it.
  Future<void> _record() async {
    final cubit = context.read<MyCheckInsCubit>();
    final filed = await Navigator.of(context).push<bool>(
      fadeThroughRoute((_) => const CheckInScreen()),
    );
    if (filed == true) await cubit.load();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Scaffold(
      appBar: GlassAppBar(title: Text(l.myCheckInsTitle)),
      // Absent, not disabled, where there is no camera to open: a greyed button
      // says "yours, but broken" about a thing that was never available on this
      // device. The record below it is readable everywhere, which is the whole
      // distinction — reading where you have been is not filing that you are
      // here.
      floatingActionButton: isPlaceScannerSupported
          ? CreateFab(
              label: l.checkInAction,
              // The one place the verb is not "add": what this button opens is
              // a camera, and the barcode says so before it is pressed.
              icon: AppIcons.qrCode,
              onPressed: _record,
            )
          : null,
      body: SafeArea(
        child: BlocBuilder<MyCheckInsCubit, MyCheckInsState>(
          builder: (context, state) {
            final cubit = context.read<MyCheckInsCubit>();

            if (state.status == MyCheckInsStatus.loading) {
              return const SkeletonList(
                count: 6,
                height: 84,
                width: PageWidth.reading,
              );
            }
            if (state.status == MyCheckInsStatus.error) {
              return EmptyState(
                icon: AppIcons.checkIn,
                title: friendlyError(context, state.error),
                action: FilledButton(
                  onPressed: cubit.load,
                  child: Text(l.commonRetry),
                ),
              );
            }

            final shown = state.shown;

            return ResponsivePage(
              width: PageWidth.reading,
              builder: (context, size) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      size.gutter,
                      AppSpacing.md,
                      size.gutter,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SavedCopyBanner(savedAt: state.savedAt),
                        _Filters(state: state, cubit: cubit),
                      ],
                    ),
                  ),
                  Expanded(
                    child: shown.isEmpty
                        ? EmptyState(
                            icon: AppIcons.checkIn,
                            title: l.myCheckInsEmpty,
                            message: l.myCheckInsEmptyHint,
                          )
                        : RefreshIndicator(
                            onRefresh: cubit.load,
                            child: ListView.builder(
                              padding: EdgeInsets.fromLTRB(
                                size.gutter,
                                AppSpacing.md,
                                size.gutter,
                                // Room for the button that sits over the list.
                                AppSpacing.xxl * 2 +
                                    MediaQuery.viewPaddingOf(context).bottom,
                              ),
                              itemCount: shown.length,
                              itemBuilder: (context, i) => FadeSlideIn(
                                delay: Duration(
                                  milliseconds: 30 * (i < 8 ? i : 8),
                                ),
                                child: _CheckInRow(line: shown[i]),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// How far back, and where.
///
/// The window is a segmented control and the place is a dropdown, because they
/// are different kinds of choice: three fixed periods that are always the same
/// three, against a list whose contents depend on where this person has been.
class _Filters extends StatelessWidget {
  const _Filters({required this.state, required this.cubit});

  final MyCheckInsState state;
  final MyCheckInsCubit cubit;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final places = state.places;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<CheckInWindow>(
          segments: [
            ButtonSegment(
              value: CheckInWindow.day,
              label: Text(l.myCheckInsWindowDay),
            ),
            ButtonSegment(
              value: CheckInWindow.week,
              label: Text(l.myCheckInsWindowWeek),
            ),
            ButtonSegment(
              value: CheckInWindow.all,
              label: Text(l.myCheckInsWindowAll),
            ),
          ],
          selected: {state.window},
          showSelectedIcon: false,
          onSelectionChanged: (s) => cubit.setWindow(s.first),
        ),
        // Only when there is a choice to make. One place is not a filter, and a
        // dropdown holding a single entry is a control that cannot do anything.
        if (places.length > 1) ...[
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String?>(
            initialValue: state.place,
            isExpanded: true,
            decoration: const InputDecoration(
              isDense: true,
              prefixIcon: Icon(AppIcons.checkIn, size: 18),
            ),
            items: [
              DropdownMenuItem(value: null, child: Text(l.myCheckInsAllPlaces)),
              for (final place in places)
                DropdownMenuItem(
                  value: place.id,
                  child: Text(place.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: cubit.setPlace,
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        Text(
          l.myCheckInsCount(state.shown.length),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// One arrival: where, when, and how close the phone said it was.
class _CheckInRow extends StatelessWidget {
  const _CheckInRow({required this.line});

  final PresenceLine line;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: GlassCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            // The framed glyph every card leads with — an arrival is a place,
            // and the row should read as one at a glance.
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
              child: Icon(AppIcons.checkIn, size: 19, color: scheme.primary),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    line.placeName,
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat(
                      'EEEE d MMMM · HH:mm',
                      locale,
                    ).format(line.createdAt),
                    style: text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // The distance is kept because it is what the row MEANS: the
            // database accepted this arrival by measuring it, and a record that
            // hid the measurement would be asking to be taken on trust — which
            // is the one thing 0098 built this table not to require. Muted,
            // though: it is evidence, not an alert.
            GlassBadge(
              label: '${line.distanceM.round()} m',
              icon: AppIcons.checkIn,
              color: scheme.onSurfaceVariant,
              dense: true,
            ),
          ],
        ),
      ),
    );
  }
}
