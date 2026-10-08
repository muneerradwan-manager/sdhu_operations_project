import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/animations/animations.dart';
import '../../../core/l10n/error_text.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/creator_page.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/states.dart';
import '../application/complaints_cubit.dart';
import '../data/complaints_repository.dart';
import '../domain/complaint.dart';
import 'complaint_thread_screen.dart';
import 'file_complaint_screen.dart';
import 'widgets/complaint_card.dart';
import 'widgets/complaint_labels.dart';

/// The register, asked one of two ways.
///
/// [ComplaintsScope.mine] is عام ← شكاواي and is everybody's: it lists what this
/// person filed, and carries the button that files another. [ComplaintsScope.all]
/// is الإدارة ← الشكاوى and asks for `complaints.view`; the server refuses the
/// wider question to anyone who may not ask it, so the screen does not have to
/// be trusted to hide it.
///
/// What was filed ABOUT this person is not here. That list is on their own
/// profile, because it is the one place a man looks for what is being said about
/// him — and because it is read through the one function that redacts.
class ComplaintsScreen extends StatelessWidget {
  const ComplaintsScreen({
    super.key,
    this.scope = ComplaintsScope.mine,
    this.compose = false,
  });

  final ComplaintsScope scope;

  /// Open the filing form as soon as the screen is up — see [TasksScreen].
  ///
  /// Only ever set for [ComplaintsScope.mine]: the register scope is a reading
  /// of everybody's, and there is nothing to compose from it.
  final bool compose;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => ComplaintsCubit(ComplaintsRepository(), scope: scope),
    child: _View(scope: scope, compose: compose),
  );
}

class _View extends StatefulWidget {
  const _View({required this.scope, this.compose = false});

  final ComplaintsScope scope;
  final bool compose;

  @override
  State<_View> createState() => _ViewState();
}

class _ViewState extends State<_View> {
  ComplaintsScope get scope => widget.scope;

  @override
  void initState() {
    super.initState();
    if (widget.compose) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _file(context);
      });
    }
  }

  Future<void> _file(BuildContext context) async {
    final cubit = context.read<ComplaintsCubit>();
    final filed = await Navigator.of(
      context,
    ).push<bool>(fadeThroughRoute((_) => const FileComplaintScreen()));
    if (filed == true) await cubit.load();
  }

  Future<void> _open(BuildContext context, Complaint complaint) async {
    final cubit = context.read<ComplaintsCubit>();
    final changed = await Navigator.of(context).push<bool>(
      fadeThroughRoute(
        (_) =>
            ComplaintThreadScreen(complaintId: complaint.id, known: complaint),
      ),
    );
    if (changed == true) await cubit.load();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final mine = scope == ComplaintsScope.mine;

    return Scaffold(
      appBar: GlassAppBar(
        title: Text(mine ? l.complaintsMineTitle : l.complaintsTitle),
      ),
      // Only on شكاواي: الإدارة is where complaints are read and settled, not
      // where they are started. A manager who wants to file one files it as
      // anybody does.
      floatingActionButton: mine
          ? CreateFab(label: l.complaintsNew, onPressed: () => _file(context))
          : null,
      body: SafeArea(
        child: BlocBuilder<ComplaintsCubit, ComplaintsState>(
          builder: (context, state) {
            final cubit = context.read<ComplaintsCubit>();

            if (state.status == ComplaintsStatus.loading) {
              return ResponsivePage(
                builder: (context, size) => SkeletonList(
                  height: 132,
                  padding: context.scrollPadding(
                    horizontal: size.gutter,
                    bottom: AppSpacing.xl,
                  ),
                ),
              );
            }
            if (state.status == ComplaintsStatus.error) {
              return EmptyState(
                icon: AppIcons.complaints,
                title: friendlyError(context, state.error),
                action: FilledButton(
                  onPressed: cubit.load,
                  child: Text(l.commonRetry),
                ),
              );
            }

            final visible = state.visible;
            return Column(
              children: [
                _FilterBar(state: state),
                Expanded(
                  child: visible.isEmpty
                      // Icon, headline, one line under it — and no button. The
                      // way to add is the same button it is on every other
                      // list: the one standing over the bottom of the page.
                      // Narrowed to nothing is a different sentence from empty,
                      // and it is answered by the filters, not by filing
                      // another complaint.
                      ? EmptyState(
                          icon: AppIcons.complaints,
                          title: state.isNarrowed
                              ? l.complaintsNoMatches
                              : (mine
                                    ? l.complaintsEmpty
                                    : l.complaintsEmptyAll),
                          message: state.isNarrowed
                              ? l.complaintsNoMatchesHint
                              : (mine
                                    ? l.complaintsEmptyHint
                                    : l.complaintsEmptyAllHint),
                        )
                      : ResponsivePage(
                          builder: (context, size) => AdaptiveGridView(
                            padding: EdgeInsets.fromLTRB(
                              size.gutter,
                              AppSpacing.sm,
                              size.gutter,
                              // Room for the button that sits over the list.
                              AppSpacing.xxl * 2 +
                                  MediaQuery.viewPaddingOf(context).bottom,
                            ),
                            onRefresh: cubit.load,
                            spacing: AppSpacing.md,
                            itemCount: visible.length,
                            itemBuilder: (context, i) => FadeSlideIn(
                              delay: Duration(
                                milliseconds: 25 * (i < 8 ? i : 8),
                              ),
                              child: ComplaintCard(
                                complaint: visible[i],
                                onOpen: () => _open(context, visible[i]),
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FilterBar extends StatefulWidget {
  const _FilterBar({required this.state});
  final ComplaintsState state;

  @override
  State<_FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<_FilterBar> {
  late final _controller = TextEditingController(text: widget.state.query);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final cubit = context.read<ComplaintsCubit>();
    final s = widget.state;

    // Only the kinds actually present. Offering all seven over a list of two
    // complaints is a menu of dead ends.
    final kinds = <ComplaintTarget>{for (final c in s.complaints) c.target};

    return SearchFilterBar(
      hint: l.complaintsSearchHint,
      controller: _controller,
      onChanged: cubit.search,
      filters: kinds.length > 1 || s.isNarrowed
          ? Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ChoiceChip(
                  label: Text(l.complaintsFilterAll),
                  selected: s.target == null,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => cubit.setTarget(null),
                ),
                for (final kind in ComplaintTarget.values)
                  if (kinds.contains(kind))
                    ChoiceChip(
                      label: Text(complaintTargetLabel(l, kind)),
                      selected: s.target == kind,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => cubit.setTarget(kind),
                    ),
                FilterChip(
                  label: Text(l.complaintsShowDismissed),
                  selected: s.includeDismissed,
                  visualDensity: VisualDensity.compact,
                  onSelected: cubit.setIncludeDismissed,
                ),
                if (s.isNarrowed)
                  TextButton.icon(
                    onPressed: () {
                      _controller.clear();
                      cubit.clearFilters();
                    },
                    icon: const Icon(AppIcons.reject, size: 16),
                    label: Text(l.moduleRosterClear),
                  ),
              ],
            )
          : null,
    );
  }
}
