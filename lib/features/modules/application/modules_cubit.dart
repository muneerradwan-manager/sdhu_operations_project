import 'package:equatable/equatable.dart';

import '../../../core/bloc/safe_cubit.dart';
import '../../../core/utils/arabic_search.dart';
import '../../../core/supabase/supabase_client.dart';
import '../../seasons/data/seasons_repository.dart';
import '../../seasons/domain/season.dart';
import '../data/modules_repository.dart';
import '../domain/module_type.dart';
import '../domain/operational_module.dart';

enum ModulesStatus { loading, ready, error }

/// Which question this screen is answering.
///
/// A person is two things at once here: somebody with permissions, and
/// somebody with work. The same man may hold `modules.manage` — every file of
/// the season is his to open, edit and release — and ALSO be one of the people
/// assigned to a tower in one of them. Those are different questions and they
/// deserve different screens, even though both list files.
///
/// [mine] is the work: the files this person was put into, and nothing else,
/// no matter what he is allowed to see.
/// [manage] is the office: every file of the season, drafts included, and the
/// button that opens a new one.
enum ModulesView { mine, manage }

/// Which files the list is showing, in a view that has both.
enum ModuleFilter { all, running, notRunning }

class ModulesState extends Equatable {
  const ModulesState({
    this.status = ModulesStatus.loading,
    this.modules = const [],
    this.types = const [],
    this.season,
    this.query = '',
    this.filter = ModuleFilter.all,
    this.error,
  });

  final ModulesStatus status;

  /// The files of [season] only. A file belongs to one season, and the season
  /// in force is a choice the admin makes — switching it should change what
  /// this screen is about.
  final List<OperationalModule> modules;

  /// The season everything here belongs to. Null when none is current, which is
  /// also when nothing can be created.
  final Season? season;

  /// Types available when creating — also the source of the "no types defined
  /// yet" message on an empty system.
  final List<ModuleType> types;

  /// What the reader is looking for. A file is named by its TYPE, so that is
  /// what a search matches — spelling folded, like everywhere else.
  final String query;
  final ModuleFilter filter;

  final String? error;

  bool get isNarrowed =>
      query.trim().isNotEmpty || filter != ModuleFilter.all;

  bool _matches(OperationalModule m) => arabicMatchesAll([
    m.moduleTypeName?.ar,
    m.moduleTypeName?.en,
  ], query);

  /// The files that are actually running: switched on, and not past their end
  /// date. A file that has run out is no more a working file than one nobody
  /// activated — which is the same answer the database gives its members.
  List<OperationalModule> get active => modules
      .where((m) => m.isRunning && filter != ModuleFilter.notRunning)
      .where(_matches)
      .toList();

  /// Everything else — never activated, switched off, or finished. Each card
  /// says WHICH of those it is; the section only says it is not running.
  ///
  /// Only managers ever receive these rows; RLS filters them out for everyone
  /// else, so no extra permission check is needed to render the section.
  List<OperationalModule> get drafts => modules
      .where((m) => !m.isRunning && filter != ModuleFilter.running)
      .where(_matches)
      .toList();

  /// The types that could still be opened this season. A file exists at most
  /// once per season, so a type already used is not offered again. [modules] is
  /// already this season's, which is why nothing here filters by season.
  List<ModuleType> typesAvailable() {
    final taken = {for (final m in modules) m.moduleTypeId};
    return types.where((t) => !taken.contains(t.id)).toList();
  }

  @override
  List<Object?> get props => [
    status,
    modules,
    types,
    season,
    query,
    filter,
    error,
  ];

  ModulesState copyWith({String? query, ModuleFilter? filter}) => ModulesState(
    status: status,
    modules: modules,
    types: types,
    season: season,
    query: query ?? this.query,
    filter: filter ?? this.filter,
    error: error,
  );
}

class ModulesCubit extends SafeCubit<ModulesState> {
  ModulesCubit(
    this._repo,
    this._seasons, {
    this.view = ModulesView.mine,
  }) : super(const ModulesState()) {
    load();
  }

  final ModulesRepository _repo;
  final SeasonsRepository _seasons;

  /// Whether this list is somebody's work or somebody's office.
  final ModulesView view;

  Future<void> load() async {
    emit(const ModulesState(status: ModulesStatus.loading));
    try {
      // The season decides what this screen is about, so it is read first and
      // everything below is scoped to it.
      final season = await _seasons.fetchCurrentSeason();
      final modules = season == null
          ? const <OperationalModule>[]
          : switch (view) {
              // Everything the caller is allowed to see — which for a manager
              // is the whole season, drafts and all.
              ModulesView.manage => await _repo.fetchModules(
                seasonId: season.id,
              ),
              // Only the files he was actually put into. A manager sees his own
              // handful here, not the season: being allowed to open every file
              // does not make every file his work.
              ModulesView.mine => await _myModules(season.id),
            };
      final types = view == ModulesView.manage
          ? await _repo.fetchModuleTypes()
          : const <ModuleType>[];
      emit(
        ModulesState(
          status: ModulesStatus.ready,
          modules: modules,
          types: types,
          season: season,
        ),
      );
    } catch (e) {
      emit(ModulesState(status: ModulesStatus.error, error: e.toString()));
    }
  }

  /// The files this person holds a role in, this season, each once.
  ///
  /// A man may hold two roles in one file — a sector supervisor who also runs
  /// one of its towers — and the file is still one file.
  void search(String value) => emit(state.copyWith(query: value));

  void setFilter(ModuleFilter filter) => emit(state.copyWith(filter: filter));

  void clearFilters() =>
      emit(state.copyWith(query: '', filter: ModuleFilter.all));

  Future<List<OperationalModule>> _myModules(String seasonId) async {
    final me = supabase.auth.currentUser?.id;
    if (me == null) return const [];
    final assignments = await _repo.fetchAssignmentsForProfile(me);
    final seen = <String>{};
    return [
      for (final a in assignments)
        if (a.module.seasonId == seasonId && seen.add(a.module.id)) a.module,
    ];
  }
}
