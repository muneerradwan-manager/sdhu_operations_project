import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/glass_tokens.dart';
import 'responsive.dart';

/// Where a search box stops growing.
///
/// A search box is the width of what gets typed into it, not the width of the
/// window. Nobody types a monitor's worth of name, and a box that wide parks
/// its own clear button a foot away from the text the reader is trying to
/// clear. Four-hundred-and-sixty is a long Arabic name with room to spare, and
/// it is the same number on every screen so the box does not move when the
/// screen does.
const kSearchFieldMaxWidth = 460.0;

/// How long the box waits before asking the server.
///
/// Only for the boxes that DO ask — the pickers and the audit log, where the
/// answer is a query and not a filter over rows already in hand. It was 400ms
/// on one screen and 350 on two others, which nobody could have felt but which
/// meant three timers to reason about instead of one.
///
/// Long enough that a name typed at speed is one request; short enough that the
/// list has moved by the time the eye comes back to it.
const kSearchDebounce = Duration(milliseconds: 350);

/// The list length at which a search box earns its place.
///
/// Under it the box is a second thing to read above a list short enough to read
/// whole. Over it, scanning starts costing more than typing. One number, so a
/// sheet of nine options and a roster of nine members answer the same way.
const kSearchWorthShowing = 8;

/// The app's one search box.
///
/// Every list that can be narrowed is narrowed through THIS widget, and that is
/// the point of it existing. Before it there were four search boxes in the app
/// — a pill in the directory, a dense box in التقارير, a bare one in الصلاحيات,
/// and one hiding behind an icon in المهام — and a reader who learned the
/// gesture on one screen had to learn it again on the next.
///
/// What it settles, once:
///
///   * the shape — dense, the theme's own border, a 20px lens at the start;
///   * the width — [kSearchFieldMaxWidth], held at the START edge, which is the
///     right in Arabic and the left in English without anyone naming a side;
///   * the clear button — present exactly when there is something to clear, and
///     it clears the field AND the query, because a box that empties itself
///     while the list stays narrowed is a lie about the list;
///   * the keyboard's action key, which says "search" rather than "return".
///
/// It filters as you type. The alternative — narrowing on submit — asks the
/// reader to commit to a spelling before seeing whether it found anything, and
/// on a directory of names half-written in two hands that is the wrong bet.
class AppSearchField extends StatefulWidget {
  const AppSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.controller,
    this.initialValue,
    this.autofocus = false,
  });

  /// What this box searches, in words — "ابحث في الشكاوى", not "بحث".
  ///
  /// A hint that only says "search" leaves the reader to guess whether the box
  /// reaches the whole archive or the twelve rows on screen.
  final String hint;

  final ValueChanged<String> onChanged;

  /// Supply one when something OUTSIDE the box also clears the query — a
  /// "مسح الفلاتر" button, a cubit that resets. Left null, the box keeps its
  /// own and disposes of it.
  final TextEditingController? controller;

  /// The query the box opens with, for a screen that rebuilds its filter bar
  /// from state. Ignored when [controller] is given — that controller's text
  /// is already the answer.
  final String? initialValue;

  final bool autofocus;

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  TextEditingController? _own;

  TextEditingController get _controller =>
      widget.controller ??
      (_own ??= TextEditingController(text: widget.initialValue));

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kSearchFieldMaxWidth),
        // Listening to the controller rather than taking the query as a
        // parameter: the clear button then appears on the first keystroke on
        // every screen, including the ones whose state object never hears
        // about the query at all.
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) => TextField(
            controller: _controller,
            autofocus: widget.autofocus,
            textInputAction: TextInputAction.search,
            onChanged: widget.onChanged,
            decoration: InputDecoration(
              isDense: true,
              hintText: widget.hint,
              prefixIcon: const Icon(AppIcons.search, size: 20),
              suffixIcon: value.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).deleteButtonTooltip,
                      icon: const Icon(AppIcons.reject, size: 18),
                      onPressed: _clear,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The band at the top of a searchable page.
///
/// The order in it is the whole rule: the search box FIRST, then whatever else
/// narrows the list. Not after the statistics, not after the tabs, not folded
/// behind an icon in the app bar. A reader arriving at a list of four hundred
/// rows is looking for one of them, and the box that finds it has to be in the
/// same place it was on the last screen — otherwise every screen costs a scan
/// before it costs a search.
///
/// Filters go UNDER the box rather than beside it. They wrap, and a row that
/// wraps beside a fixed-width field tears at exactly the width a phone is.
class SearchFilterBar extends StatelessWidget {
  const SearchFilterBar({
    super.key,
    required this.hint,
    required this.onChanged,
    this.controller,
    this.initialValue,
    this.autofocus = false,
    this.filters,
    this.above,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  final String? initialValue;
  final bool autofocus;

  /// Chips, segments, a date range — whatever else narrows this list.
  final Widget? filters;

  /// The rare thing that outranks search: a banner saying the page is showing
  /// a saved copy, which is true of the list before any question about it is.
  final Widget? above;

  @override
  Widget build(BuildContext context) {
    return ResponsivePage(
      builder: (context, size) => Padding(
        padding: EdgeInsets.fromLTRB(
          size.gutter,
          // The same idiom as [GlassThemeX.scrollPadding], and for the same
          // reason: on a screen using `extendBodyBehindAppBar` this already
          // reads as the bar's bottom edge, and on every other screen it is
          // zero because the Scaffold has spent it. One expression, no flag,
          // and no screen that adds `kToolbarHeight` a second time on top of
          // a number that was already the toolbar.
          MediaQuery.paddingOf(context).top + AppSpacing.md,
          size.gutter,
          AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (above != null) ...[
              above!,
              const SizedBox(height: AppSpacing.md),
            ],
            AppSearchField(
              hint: hint,
              onChanged: onChanged,
              controller: controller,
              initialValue: initialValue,
              autofocus: autofocus,
            ),
            if (filters != null) ...[
              const SizedBox(height: AppSpacing.sm),
              filters!,
            ],
          ],
        ),
      ),
    );
  }
}
