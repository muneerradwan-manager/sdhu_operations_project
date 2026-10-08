import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/animations/animations.dart';
import '../../../core/l10n/error_text.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/profile_avatar.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/selection_indicator.dart';
import '../../../core/widgets/states.dart';
import '../data/evaluations_repository.dart';
import '../domain/evaluation.dart';
import 'widgets/evaluation_labels.dart';

/// Choosing the subjects — several of them — for one batch of evaluations.
///
/// A page rather than a dropdown, and a page of its own rather than the
/// employee picker, because this list is not always people. The same screen
/// answers all six kinds that can be pointed at: employees, operational files,
/// reports, hotels, clusters, groups. What differs between them is only which
/// table `evaluation_targets` read, so one screen is one code path and six
/// screens would be five copies waiting to drift.
///
/// Search goes to the database, like everything else that narrows in this app.
/// The list is capped at 200 by the function; the search is how you reach past
/// it rather than a filter over what is in hand.
///
/// Pops the chosen options, or null when backed out of. The OPTIONS and not the
/// ids, for the reason the employee picker pops people: the caller has nowhere
/// to look a name up again.
Future<List<EvaluationPickerOption>?> showEvaluationTargetsPicker(
  BuildContext context, {
  required EvaluationTarget target,
  required List<EvaluationPickerOption> selected,
}) {
  return Navigator.of(context).push<List<EvaluationPickerOption>>(
    fadeThroughRoute(
      (_) => EvaluationTargetsPickerScreen(
        target: target,
        selected: selected,
      ),
      opaque: true,
    ),
  );
}

class EvaluationTargetsPickerScreen extends StatefulWidget {
  const EvaluationTargetsPickerScreen({
    super.key,
    required this.target,
    required this.selected,
  });

  final EvaluationTarget target;
  final List<EvaluationPickerOption> selected;

  @override
  State<EvaluationTargetsPickerScreen> createState() =>
      _EvaluationTargetsPickerScreenState();
}

class _EvaluationTargetsPickerScreenState
    extends State<EvaluationTargetsPickerScreen> {
  final _repo = EvaluationsRepository();
  final _controller = TextEditingController();

  /// Held by id so that a search which empties the list cannot lose what was
  /// already chosen — the same rule the employee picker keeps its selection by,
  /// and the reason the whole option is stored rather than the id alone.
  late final Map<String, EvaluationPickerOption> _picked = {
    for (final o in widget.selected) o.id: o,
  };

  List<EvaluationPickerOption> _options = const [];
  bool _loading = true;
  String? _error;
  Timer? _debounce;

  /// Guards against an older, slower search overwriting a newer one.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Typing is not a search. Each keystroke restarts the clock, and only the
  /// pause at the end of a word reaches the database.
  void _search(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _fetch);
    setState(() {});
  }

  Future<void> _fetch() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final options = await _repo.fetchTargets(
        widget.target,
        query: _controller.text.trim().isEmpty ? null : _controller.text.trim(),
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _options = options;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _toggle(EvaluationPickerOption option) {
    setState(() {
      if (_picked.remove(option.id) == null) _picked[option.id] = option;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(
        title: Text(evaluationTargetLabel(l, widget.target)),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(_picked.values.toList()),
            child: Text(l.commonSave),
          ),
        ],
      ),
      body: Column(
        children: [
          SearchFilterBar(
            hint: l.evaluationAssignPickSubject,
            controller: _controller,
            onChanged: _search,
          ),
          Expanded(
            child: switch (null) {
              _ when _loading => const SkeletonList(height: 84),
              _ when _error != null => EmptyState(
                icon: evaluationTargetIcon(widget.target),
                title: friendlyError(context, _error),
                action: FilledButton(
                  onPressed: _fetch,
                  child: Text(l.commonRetry),
                ),
              ),
              _ when _options.isEmpty => EmptyState(
                icon: AppIcons.search,
                title: _controller.text.trim().isEmpty
                    ? l.evaluationAssignNoTargets(
                        evaluationTargetLabel(l, widget.target),
                      )
                    : l.evaluationsNoMatches,
              ),
              _ => ResponsivePage(
                builder: (context, size) => AdaptiveGridView(
                  onRefresh: _fetch,
                  padding: EdgeInsets.fromLTRB(
                    size.gutter,
                    0,
                    size.gutter,
                    MediaQuery.viewPaddingOf(context).bottom + AppSpacing.xl,
                  ),
                  spacing: AppSpacing.sm,
                  itemCount: _options.length,
                  itemBuilder: (context, i) => _TargetTile(
                    option: _options[i],
                    target: widget.target,
                    isSelected: _picked.containsKey(_options[i].id),
                    onTap: () => _toggle(_options[i]),
                  ),
                ),
              ),
            },
          ),
        ],
      ),
      bottomNavigationBar: GlassSurface(
        radius: 0,
        strong: true,
        shadow: false,
        bordered: false,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: FilledButton.icon(
              onPressed: () =>
                  Navigator.of(context).pop(_picked.values.toList()),
              icon: const Icon(AppIcons.approve),
              label: Text(l.modulePickerConfirm(_picked.length)),
            ),
          ),
        ),
      ),
    );
  }
}

class _TargetTile extends StatelessWidget {
  const _TargetTile({
    required this.option,
    required this.target,
    required this.isSelected,
    required this.onTap,
  });

  final EvaluationPickerOption option;
  final EvaluationTarget target;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return GlassCard(
      emphasised: isSelected,
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          // A face where the kind has one, the section's own glyph where it
          // does not — the same pairing the register draws its cards by.
          if (option.photoUrl != null || target == EvaluationTarget.employee)
            ProfileAvatar(
              photoUrl: option.photoUrl,
              name: option.name,
              radius: 20,
            )
          else
            Icon(evaluationTargetIcon(target), color: scheme.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              option.name.isEmpty ? '—' : option.name,
              style: text.titleSmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SelectionIndicator(selected: isSelected, shape: SelectionShape.many),
        ],
      ),
    );
  }
}
