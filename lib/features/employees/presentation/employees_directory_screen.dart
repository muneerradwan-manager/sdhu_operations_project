import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/animations/animations.dart';
import '../../../core/constants/permission_codes.dart';
import '../../../core/l10n/error_text.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/glass_tokens.dart';
import '../../../core/utils/arabic_search.dart';
import '../../../core/widgets/employee_tile.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/saved_copy_banner.dart';
import '../../../core/widgets/states.dart';
import '../../auth/application/session_cubit.dart';
import '../../modules/presentation/widgets/picker_sheet.dart';
import '../../profile/domain/profile.dart';
import '../application/employees_directory_cubit.dart';
import '../../seasons/data/seasons_repository.dart';
import '../data/employees_repository.dart';
import 'create_employee_screen.dart';
import 'employee_detail_screen.dart';
import '../../../core/l10n/localized_name.dart';

class EmployeesDirectoryScreen extends StatelessWidget {
  const EmployeesDirectoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          EmployeesDirectoryCubit(EmployeesRepository(), SeasonsRepository()),
      child: const _View(),
    );
  }
}

class _View extends StatefulWidget {
  const _View();

  @override
  State<_View> createState() => _ViewState();
}

class _ViewState extends State<_View> {
  final _search = TextEditingController();
  String _query = '';

  // The narrowing knobs, keyed by the Arabic name — it is the half of a
  // [LocalizedName] that is always present, so the same choice keeps matching
  // when the reader flips the app's language.
  String? _jobTitle;
  String? _city;
  bool _suspendedOnly = false;

  bool get _isNarrowed => _jobTitle != null || _city != null || _suspendedOnly;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openCreate(BuildContext context) async {
    final cubit = context.read<EmployeesDirectoryCubit>();
    final created = await Navigator.of(
      context,
    ).push<bool>(fadeThroughRoute((_) => const CreateEmployeeScreen()));
    if (created == true) cubit.load();
  }

  /// Match across the fields a user would actually search by.
  ///
  /// The three parts of the name are offered separately as well as joined, so
  /// the father's name is searchable on its own and a query may name any two of
  /// the three in any order — "أحمد الحداد" finds "أحمد فتحي الحداد".
  ///
  /// Spelling is folded first (see [arabicMatchesAll]): أ إ آ and ا are one
  /// letter, so are ة and ه, and harakat are ignored. The mission's decisions
  /// spell the same man both ways in the same week, and a search that insists
  /// on one of them hides a record that is sitting right there.
  ///
  /// A job title is matched in BOTH languages, whichever the app is set to:
  /// someone reading an English list may still search "طبيب", and the two names
  /// are the same title.
  List<Profile> _filter(List<Profile> source) {
    return source.where((e) {
      // The knobs first — they are exact — and the words last.
      if (_suspendedOnly && !e.isSuspended) return false;
      if (_jobTitle != null && e.jobTitleName?.ar != _jobTitle) return false;
      if (_city != null && e.cityName?.ar != _city) return false;
      if (_query.isEmpty) return true;
      final title = e.jobTitleName;
      return arabicMatchesAll([
        e.firstName,
        e.fatherName,
        e.surname,
        e.fullName,
        title?.ar,
        title?.en,
        e.externalOrganization,
      ], _query);
    }).toList();
  }

  /// One knob: a pill naming what it narrows by, or the choice it is holding.
  ///
  /// A picker sheet rather than a row of chips, because a season's directory
  /// carries dozens of job titles and cities — a Wrap of forty chips is a wall,
  /// and the sheet is already the way every long list in this app is chosen
  /// from.
  Future<void> _pick({
    required String title,
    required Map<String, LocalizedName> options,
    required String? current,
    required ValueChanged<String?> onChanged,
  }) async {
    final entries = options.values.toList()
      ..sort((a, b) => a.of(context).compareTo(b.of(context)));
    final result = await showPickerSheet(
      context,
      title: title,
      options: [
        for (final name in entries)
          PickerOption(id: name.ar, label: name.of(context)),
      ],
      selected: {?current},
    );
    if (result == null || !mounted) return;
    setState(() => onChanged(result.isEmpty ? null : result.first));
  }

  /// The knobs, built from what is actually in the directory — a filter
  /// offering a title nobody holds is a menu of dead ends.
  Widget? _filters(EmployeesDirectoryState state) {
    final l = context.l10n;
    final all = [...state.permanent, ...state.external];

    final titles = <String, LocalizedName>{
      for (final e in all)
        if (e.jobTitleName != null) e.jobTitleName!.ar: e.jobTitleName!,
    };
    final cities = <String, LocalizedName>{
      for (final e in all)
        if (e.cityName != null) e.cityName!.ar: e.cityName!,
    };
    final anySuspended = all.any((e) => e.isSuspended);

    if (titles.length < 2 && cities.length < 2 && !anySuspended) return null;

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (titles.length > 1)
          _FilterPill(
            label: _jobTitle == null
                ? l.profileJobTitle
                : (titles[_jobTitle]?.of(context) ?? l.profileJobTitle),
            active: _jobTitle != null,
            onTap: () => _pick(
              title: l.profileJobTitle,
              options: titles,
              current: _jobTitle,
              onChanged: (v) => _jobTitle = v,
            ),
          ),
        if (cities.length > 1)
          _FilterPill(
            label: _city == null
                ? l.profileCity
                : (cities[_city]?.of(context) ?? l.profileCity),
            active: _city != null,
            onTap: () => _pick(
              title: l.profileCity,
              options: cities,
              current: _city,
              onChanged: (v) => _city = v,
            ),
          ),
        // Only once somebody in the list IS suspended — a switch that can
        // never match anybody is furniture.
        if (anySuspended)
          FilterChip(
            label: Text(l.employeesFilterSuspended),
            selected: _suspendedOnly,
            visualDensity: VisualDensity.compact,
            onSelected: (v) => setState(() => _suspendedOnly = v),
          ),
        if (_isNarrowed || _query.isNotEmpty)
          TextButton.icon(
            onPressed: () => setState(() {
              _search.clear();
              _query = '';
              _jobTitle = null;
              _city = null;
              _suspendedOnly = false;
            }),
            icon: const Icon(AppIcons.reject, size: 16),
            label: Text(l.moduleRosterClear),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: GlassAppBar(
          title: Text(l.navEmployees),
          actions: [
            Builder(
              builder: (context) {
                final canCreate = context.watch<SessionCubit>().state.can(
                  PermissionCodes.employeesCreate,
                );
                if (!canCreate) return const SizedBox.shrink();
                return IconButton(
                  tooltip: l.createEmployeeTitle,
                  icon: const Icon(AppIcons.addUser),
                  onPressed: () => _openCreate(context),
                );
              },
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: l.employeesPermanentSection),
              Tab(text: l.employeesExternalSection),
            ],
          ),
        ),
        body: SafeArea(
          child: BlocConsumer<EmployeesDirectoryCubit, EmployeesDirectoryState>(
            listenWhen: (p, c) => c.error != null && p.error != c.error,
            listener: (context, state) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(content: Text(friendlyError(context, state.error))),
                );
            },
            builder: (context, state) {
              if (state.status == DirectoryStatus.loading) {
                return const SkeletonList(count: 7, height: 70);
              }
              return ResponsivePage(
                builder: (context, size) => Column(
                  children: [
                    // Above the search box rather than inside the lists: it is
                    // true of the whole page, and both tabs are affected —
                    // the externals worst of all, since with no signal they
                    // cannot be read at all and the tab shows empty.
                    SearchFilterBar(
                      hint: l.commonSearch,
                      controller: _search,
                      onChanged: (v) => setState(() => _query = v.trim()),
                      above: SavedCopyBanner(savedAt: state.savedAt),
                      filters: _filters(state),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _EmployeeList(
                            employees: _filter(state.permanent),
                            emptyTitle: l.employeesEmpty,
                            searching: _query.isNotEmpty || _isNarrowed,
                            gutter: size.gutter,
                            onRefresh: () =>
                                context.read<EmployeesDirectoryCubit>().load(),
                          ),
                          _EmployeeList(
                            employees: _filter(state.external),
                            emptyTitle: l.employeesExternalEmpty,
                            searching: _query.isNotEmpty || _isNarrowed,
                            gutter: size.gutter,
                            onRefresh: () =>
                                context.read<EmployeesDirectoryCubit>().load(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A knob that opens a picker — the same face the audit log's filters wear, so
/// "this narrows the list and holds a choice" reads the same on both screens.
class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassCard(
      emphasised: active,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 8,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: active ? scheme.primary : scheme.onSurfaceVariant,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.arrow_drop_down,
            size: 18,
            color: active ? scheme.primary : scheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _EmployeeList extends StatelessWidget {
  const _EmployeeList({
    required this.employees,
    required this.emptyTitle,
    required this.searching,
    required this.gutter,
    required this.onRefresh,
  });

  final List<Profile> employees;
  final String emptyTitle;
  final bool searching;
  final double gutter;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    if (employees.isEmpty) {
      return EmptyState(
        icon: searching ? AppIcons.search : AppIcons.employees,
        title: searching ? context.l10n.commonSearch : emptyTitle,
        message: searching ? emptyTitle : null,
      );
    }
    // A directory is the longest list in the app — every employee of the
    // mission — so the rows are built as they are scrolled to. A name and a
    // face need about three hundred pixels and no more, which on a monitor is
    // four of them across instead of one and four fifths of a blank screen.
    return AdaptiveGridView(
      padding: EdgeInsets.fromLTRB(
        gutter,
        AppSpacing.md,
        gutter,
        AppSpacing.lg + MediaQuery.viewPaddingOf(context).bottom,
      ),
      onRefresh: onRefresh,
      itemCount: employees.length,
      itemBuilder: (context, i) {
        final e = employees[i];
        return FadeSlideIn(
          // Cap the cascade so row 40 doesn't wait a second to appear.
          delay: Duration(milliseconds: 30 * (i < 8 ? i : 8)),
          child: EmployeeTile(
            name: e.fullName,
            photoUrl: e.photoUrl,
            subtitle: e.isExternal
                ? e.externalOrganization
                : e.jobTitleName?.of(context),
            isExternal: e.isExternal,
            onTap: () => Navigator.of(
              context,
            ).push(fadeThroughRoute((_) => EmployeeDetailScreen(profile: e))),
          ),
        );
      },
    );
  }
}
