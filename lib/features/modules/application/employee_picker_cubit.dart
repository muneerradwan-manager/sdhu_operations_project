import 'dart:async';

import 'package:equatable/equatable.dart';

import '../../../core/bloc/safe_cubit.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/domain/reference_choice.dart';
import '../data/modules_repository.dart';
import '../domain/assignable_employee.dart';

enum PickerStatus { loading, ready, error }

/// Which participants to show. The mission runs on both, and which one you are
/// looking for is usually decided before you start typing.
enum ParticipantFilter {
  all,
  internal,
  external;

  bool? get isExternal => switch (this) {
    ParticipantFilter.all => null,
    ParticipantFilter.internal => false,
    ParticipantFilter.external => true,
  };
}

/// Stands for "this argument was not passed", so that passing null CAN mean
/// null. Only the two nullable filters need it.
const Object _unset = Object();

class EmployeePickerState extends Equatable {
  const EmployeePickerState({
    this.status = PickerStatus.loading,
    this.people = const [],
    this.selected = const {},
    this.known = const {},
    this.query = '',
    this.filter = ParticipantFilter.all,
    this.jobTitleId,
    this.cityId,
    this.onlyFree = false,
    this.jobTitles = const [],
    this.cities = const [],
    this.loadingMore = false,
    this.hasMore = true,
    this.error,
  });

  final PickerStatus status;
  final List<AssignableEmployee> people;

  /// Held here rather than in the widget so it survives a search that empties
  /// the list: choosing three people, searching for a fourth and finding none
  /// must not lose the three.
  final Set<String> selected;

  /// Everyone this page has shown, across every page and every search.
  ///
  /// [selected] is ids, and ids are all a file needs — it re-reads its members.
  /// A caller who is merely NAMING people has nowhere to look those ids up
  /// again, and the three it chose may have scrolled out of [people] two
  /// searches ago. Somebody can only be selected by being tapped, and being
  /// tapped means having been shown, so this map can always answer for the
  /// whole selection.
  final Map<String, AssignableEmployee> known;

  final String query;
  final ParticipantFilter filter;

  /// Narrowed to one post, one city, or to people carrying nothing yet this
  /// season. Null and false mean "everyone", which is where the page starts.
  final String? jobTitleId;
  final String? cityId;
  final bool onlyFree;

  /// What the two dropdowns may offer. Loaded once beside the first page.
  final List<ReferenceChoice> jobTitles;
  final List<ReferenceChoice> cities;

  /// Whether anything beyond the plain list is being asked for — what the
  /// "clear" button appears for.
  bool get isNarrowed =>
      query.trim().isNotEmpty ||
      filter != ParticipantFilter.all ||
      jobTitleId != null ||
      cityId != null ||
      onlyFree;

  final bool loadingMore;

  /// False once a page came back short — there is nothing further to ask for.
  final bool hasMore;

  final String? error;

  EmployeePickerState copyWith({
    PickerStatus? status,
    List<AssignableEmployee>? people,
    Set<String>? selected,
    Map<String, AssignableEmployee>? known,
    String? query,
    ParticipantFilter? filter,
    Object? jobTitleId = _unset,
    Object? cityId = _unset,
    bool? onlyFree,
    List<ReferenceChoice>? jobTitles,
    List<ReferenceChoice>? cities,
    bool? loadingMore,
    bool? hasMore,
    String? error,
  }) {
    return EmployeePickerState(
      status: status ?? this.status,
      people: people ?? this.people,
      selected: selected ?? this.selected,
      known: known ?? this.known,
      query: query ?? this.query,
      filter: filter ?? this.filter,
      // Sentinels: null is a real value for these two — it is what "any post"
      // and "any city" mean — so `??` could never clear them.
      jobTitleId: jobTitleId == _unset
          ? this.jobTitleId
          : jobTitleId as String?,
      cityId: cityId == _unset ? this.cityId : cityId as String?,
      onlyFree: onlyFree ?? this.onlyFree,
      jobTitles: jobTitles ?? this.jobTitles,
      cities: cities ?? this.cities,
      loadingMore: loadingMore ?? this.loadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: error,
    );
  }

  @override
  List<Object?> get props => [
    status,
    people,
    selected,
    known,
    query,
    filter,
    jobTitleId,
    cityId,
    onlyFree,
    jobTitles,
    cities,
    loadingMore,
    hasMore,
    error,
  ];
}

/// Drives the page that chooses people for a role.
///
/// Every narrowing — the text, the filter, the next page — is a question put to
/// the database rather than a pass over a list held here. At five hundred
/// participants that is the difference between a page that opens and one that
/// waits for the whole roster first.
class EmployeePickerCubit extends SafeCubit<EmployeePickerState> {
  EmployeePickerCubit(
    this._repo, {
    required this.seasonId,
    Set<String> selected = const {},
    this.exclude = const {},
  }) : super(EmployeePickerState(selected: {...selected})) {
    _fetch();
    _loadFilterOptions();
  }

  final ModulesRepository _repo;
  final ProfileRepository _profiles = ProfileRepository();
  final String seasonId;

  /// Who this caller may not choose. Applied here rather than in the query
  /// because it is one id in a list of forty and the function is shared with
  /// every other caller, none of which excludes anybody.
  final Set<String> exclude;

  List<AssignableEmployee> _allowed(List<AssignableEmployee> people) =>
      exclude.isEmpty
      ? people
      : [
          for (final person in people)
            if (!exclude.contains(person.profile.id)) person,
        ];

  static const _pageSize = 40;

  Timer? _debounce;

  /// Guards against an older, slower search overwriting a newer one.
  int _generation = 0;

  /// How many rows the DATABASE has handed over for the current search — which
  /// is what the next page's offset is measured from. Not the same as the
  /// number on screen once [exclude] has dropped one: paging by what survived
  /// would ask for row 39 again and show it twice.
  int _fetched = 0;

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }

  /// Typing is not a search. Each keystroke restarts the clock, and only the
  /// pause at the end of a word reaches the database.
  void search(String value) {
    emit(state.copyWith(query: value));
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _fetch);
  }

  void setFilter(ParticipantFilter filter) {
    if (filter == state.filter) return;
    _debounce?.cancel();
    emit(state.copyWith(filter: filter));
    _fetch();
  }

  /// The post, the city, and "free only". Each narrows in the database, like
  /// the search does — the list is paged, so a filter applied here would only
  /// ever narrow the forty rows already in hand.
  void setJobTitle(String? id) {
    if (id == state.jobTitleId) return;
    _debounce?.cancel();
    emit(state.copyWith(jobTitleId: id));
    _fetch();
  }

  void setCity(String? id) {
    if (id == state.cityId) return;
    _debounce?.cancel();
    emit(state.copyWith(cityId: id));
    _fetch();
  }

  void setOnlyFree(bool value) {
    if (value == state.onlyFree) return;
    _debounce?.cancel();
    emit(state.copyWith(onlyFree: value));
    _fetch();
  }

  /// Back to the plain list, in one call rather than four round trips.
  void clearFilters() {
    if (!state.isNarrowed) return;
    _debounce?.cancel();
    emit(
      state.copyWith(
        query: '',
        filter: ParticipantFilter.all,
        jobTitleId: null,
        cityId: null,
        onlyFree: false,
      ),
    );
    _fetch();
  }

  /// What the dropdowns offer. Fetched once — the lists do not change while
  /// somebody is choosing people — and a failure here must not take the page
  /// down with it: the picker still works with the filters it already has.
  Future<void> _loadFilterOptions() async {
    try {
      final titles = await _profiles.fetchActiveJobTitles();
      final cities = await _profiles.fetchSyrianCities();
      if (isClosed) return;
      emit(state.copyWith(jobTitles: titles, cities: cities));
    } catch (_) {
      /* the filters simply stay unavailable */
    }
  }

  void toggle(String profileId) {
    final selected = {...state.selected};
    if (!selected.remove(profileId)) selected.add(profileId);
    emit(state.copyWith(selected: selected));
  }

  /// Replaces the selection outright — what a single-holder role does when a
  /// name is tapped.
  void selectOnly(String profileId) =>
      emit(state.copyWith(selected: {profileId}));

  /// Whether everybody currently narrowed to is already chosen.
  ///
  /// Asked of the LOADED rows, which is the only set this page can answer for
  /// without going back to the server — see [selectAllMatching] for what
  /// happens when there are more.
  bool get allShownSelected =>
      state.people.isNotEmpty &&
      state.people.every((p) => state.selected.contains(p.profile.id));

  /// Everybody the current filters match — not merely everybody on screen.
  ///
  /// The distinction matters and is the whole reason this is not two lines. The
  /// list arrives forty at a time, so a "select all" that took the loaded rows
  /// would quietly choose forty of four hundred and look exactly like success.
  /// Somebody putting a whole intake on one flight would then find three
  /// hundred and sixty people missing from it, days later, with nothing
  /// anywhere saying why.
  ///
  /// So the rest is fetched first. It is up to ten round trips on a season's
  /// whole roster, which is why the page shows its loading state throughout and
  /// why this is a deliberate press rather than something offered casually.
  Future<void> selectAllMatching() async {
    final generation = _generation;
    while (state.hasMore && !isClosed && generation == _generation) {
      final before = state.people.length;
      await loadMore();
      // A page that added nothing means the server has no more to give,
      // whatever `hasMore` believed. Without this the loop is unbounded.
      if (state.people.length == before) break;
    }
    if (isClosed || generation != _generation) return;
    emit(
      state.copyWith(
        selected: {
          ...state.selected,
          for (final person in state.people) person.profile.id,
        },
      ),
    );
  }

  /// Unchooses everybody — including anybody chosen before this page opened,
  /// which is what "الغاء الكل" means to the person pressing it.
  void clearSelection() => emit(state.copyWith(selected: const {}));

  /// The chosen people, resolved. Everything in [EmployeePickerState.selected]
  /// that this page has actually shown; an id handed in by the caller and never
  /// scrolled past is the caller's own to remember.
  List<AssignableEmployee> get selectedPeople => [
    for (final id in state.selected)
      if (state.known[id] != null) state.known[id]!,
  ];

  static Map<String, AssignableEmployee> _remember(
    EmployeePickerState state,
    List<AssignableEmployee> arrivals,
  ) => {
    ...state.known,
    for (final person in arrivals) person.profile.id: person,
  };

  Future<void> refresh() => _fetch();

  Future<void> _fetch() async {
    final generation = ++_generation;
    emit(state.copyWith(status: PickerStatus.loading, error: null));
    try {
      final page = await _repo.searchAssignableEmployees(
        seasonId: seasonId,
        query: state.query,
        isExternal: state.filter.isExternal,
        jobTitleId: state.jobTitleId,
        cityId: state.cityId,
        onlyFree: state.onlyFree,
        limit: _pageSize,
      );
      if (isClosed || generation != _generation) return;
      _fetched = page.length;
      final people = _allowed(page);
      emit(
        state.copyWith(
          status: PickerStatus.ready,
          people: people,
          known: {..._remember(state, people)},
          // Measured on what the DATABASE returned, not on what survived the
          // exclusion: a full page with one name dropped is still a full page,
          // and there is more behind it.
          hasMore: page.length == _pageSize,
        ),
      );
    } catch (e) {
      if (isClosed || generation != _generation) return;
      emit(state.copyWith(status: PickerStatus.error, error: e.toString()));
    }
  }

  /// The next page, appended. Does nothing while one is already in flight or
  /// once the list has run out.
  Future<void> loadMore() async {
    if (state.loadingMore ||
        !state.hasMore ||
        state.status != PickerStatus.ready) {
      return;
    }
    final generation = _generation;
    emit(state.copyWith(loadingMore: true));
    try {
      // The same filters as the first page, or the offset is applied against a
      // different result set: page two would arrive unfiltered, with rows that
      // duplicate or skip what is already showing.
      final more = await _repo.searchAssignableEmployees(
        seasonId: seasonId,
        query: state.query,
        isExternal: state.filter.isExternal,
        jobTitleId: state.jobTitleId,
        cityId: state.cityId,
        onlyFree: state.onlyFree,
        limit: _pageSize,
        offset: _fetched,
      );
      if (isClosed || generation != _generation) return;
      _fetched += more.length;
      final arrivals = _allowed(more);
      emit(
        state.copyWith(
          people: [...state.people, ...arrivals],
          known: {..._remember(state, arrivals)},
          hasMore: more.length == _pageSize,
          loadingMore: false,
        ),
      );
    } catch (_) {
      if (isClosed || generation != _generation) return;
      emit(state.copyWith(loadingMore: false));
    }
  }
}
