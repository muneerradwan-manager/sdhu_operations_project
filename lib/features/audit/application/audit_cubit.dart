import 'package:equatable/equatable.dart';

import '../../../core/bloc/safe_cubit.dart';
import '../data/audit_repository.dart';
import '../domain/audit_event.dart';
import '../domain/audit_labels.dart';
import '../domain/audit_summary.dart';

enum AuditStatus { loading, loaded, error }

/// The season side of the filter, which has THREE states and not two.
///
/// One value rather than a season plus a flag, because two fields can be set to
/// a question that has no meaning — a filter naming 1448 *and* asking for the
/// lines belonging to no season — and then something has to arbitrate. Here
/// that state cannot be written down.
///
/// [all] is the default and is what the log has always shown. [none] is a real
/// answer and most of the log: accounts, grants, master data, place codes are
/// acts that outlive seasons, and a filter that could only ever narrow TO a
/// season would hide the majority of the log the moment it was touched.
class AuditSeasonScope extends Equatable {
  const AuditSeasonScope._(this.season, this.isNone);

  const AuditSeasonScope.of(AuditSeason season) : this._(season, false);

  /// Every line, whatever season it belongs to.
  static const all = AuditSeasonScope._(null, false);

  /// Only the lines that belong to no season at all.
  static const none = AuditSeasonScope._(null, true);

  final AuditSeason? season;
  final bool isNone;

  bool get isAll => season == null && !isNone;

  @override
  List<Object?> get props => [season, isNone];
}

/// What the reader has narrowed the log down to. Immutable and compared as a
/// whole, so changing any one knob is one `copyWith` and one reload.
class AuditFilters extends Equatable {
  const AuditFilters({
    this.action,
    this.groupKey,
    this.actor,
    this.from,
    this.to,
    this.query = '',
    this.seasonScope = AuditSeasonScope.all,
  });

  final AuditAction? action;

  /// Key into [AuditLabels.groups]; the RPC receives the group's table list.
  final String? groupKey;
  final AuditActor? actor;
  final DateTime? from;
  final DateTime? to;
  final String query;

  /// Which season's lines — one of them, the ones belonging to none, or all.
  ///
  /// Not the same question as [from]/[to], which is why it is a filter of its
  /// own: two seasons that overlap by a day are two different answers, and a
  /// window of dates cannot separate the أعمال of 1447 from the preparation of
  /// 1448 happening beside them.
  final AuditSeasonScope seasonScope;

  bool get isEmpty =>
      action == null &&
      groupKey == null &&
      actor == null &&
      from == null &&
      to == null &&
      seasonScope.isAll &&
      query.trim().isEmpty;

  List<String>? get tables => groupKey == null
      ? null
      : AuditLabels.groups
            .firstWhere((g) => g.key == groupKey)
            .tables;

  /// Nullable fields clear through sentinels rather than null-means-keep.
  AuditFilters copyWith({
    Object? action = _keep,
    Object? groupKey = _keep,
    Object? actor = _keep,
    Object? from = _keep,
    Object? to = _keep,
    String? query,
    AuditSeasonScope? seasonScope,
  }) {
    return AuditFilters(
      action: action == _keep ? this.action : action as AuditAction?,
      groupKey: groupKey == _keep ? this.groupKey : groupKey as String?,
      actor: actor == _keep ? this.actor : actor as AuditActor?,
      from: from == _keep ? this.from : from as DateTime?,
      to: to == _keep ? this.to : to as DateTime?,
      query: query ?? this.query,
      // No sentinel needed: [AuditSeasonScope.all] is how this one clears, and
      // it is a value rather than an absence.
      seasonScope: seasonScope ?? this.seasonScope,
    );
  }

  static const _keep = Object();

  @override
  List<Object?> get props => [
    action,
    groupKey,
    actor,
    from,
    to,
    query,
    seasonScope,
  ];
}

class AuditState extends Equatable {
  const AuditState({
    this.status = AuditStatus.loading,
    this.events = const [],
    this.hasMore = false,
    this.loadingMore = false,
    this.filters = const AuditFilters(),
    this.actors = const [],
    this.seasons = const [],
    this.summary,
    this.error,
  });

  final AuditStatus status;
  final List<AuditEvent> events;
  final bool hasMore;
  final bool loadingMore;
  final AuditFilters filters;

  /// Loaded once, lazily, when the person filter is first opened.
  final List<AuditActor> actors;

  /// The same, for the season filter.
  final List<AuditSeason> seasons;

  /// The shape of the same filtered set, counted server-side.
  ///
  /// Null while it is in flight and null if it FAILED, and the second is not an
  /// error state: the log is readable without its summary, and taking the whole
  /// page down because a chart could not be counted would trade the thing the
  /// reader came for against the thing above it.
  final AuditSummary? summary;

  final String? error;

  AuditState copyWith({
    AuditStatus? status,
    List<AuditEvent>? events,
    bool? hasMore,
    bool? loadingMore,
    AuditFilters? filters,
    List<AuditActor>? actors,
    List<AuditSeason>? seasons,
    Object? summary = _keep,
    String? error,
  }) {
    return AuditState(
      status: status ?? this.status,
      events: events ?? this.events,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      filters: filters ?? this.filters,
      actors: actors ?? this.actors,
      seasons: seasons ?? this.seasons,
      // Through a sentinel, because clearing it is a thing that has to be
      // sayable: a summary counted under the old filters, left standing over a
      // list reloaded under the new ones, is the exact disagreement this whole
      // arrangement exists to avoid.
      summary: summary == _keep ? this.summary : summary as AuditSummary?,
      error: error,
    );
  }

  static const _keep = Object();

  @override
  List<Object?> get props => [
    status,
    events,
    hasMore,
    loadingMore,
    filters,
    actors,
    seasons,
    summary,
    error,
  ];
}

class AuditCubit extends SafeCubit<AuditState> {
  AuditCubit(this._repo) : super(const AuditState()) {
    load();
  }

  final AuditRepository _repo;

  static const _pageSize = 50;

  /// Guards a slow page against a filter changed while it was in flight: only
  /// the newest request may write its answer into the state.
  int _requestSeq = 0;

  Future<void> load() async {
    final seq = ++_requestSeq;
    // The old summary goes with the old list. It was counted under the filters
    // that have just been replaced, and a stale chart over a fresh list reads
    // as a disagreement nobody can resolve from the screen.
    emit(
      state.copyWith(
        status: AuditStatus.loading,
        loadingMore: false,
        summary: null,
      ),
    );
    try {
      final page = await _fetch(beforeId: null);
      if (seq != _requestSeq) return;
      emit(
        state.copyWith(
          status: AuditStatus.loaded,
          events: page,
          hasMore: page.length >= _pageSize,
        ),
      );
    } catch (e) {
      if (seq != _requestSeq) return;
      emit(state.copyWith(status: AuditStatus.error, error: e.toString()));
      return;
    }
    // Counted after the page rather than beside it, and on its own error path.
    // The list is what the reader opened this screen for; the summary is what
    // sits above it, and one failing must not take the other down.
    await _summarise(seq);
  }

  Future<void> _summarise(int seq) async {
    final f = state.filters;
    try {
      final summary = await _repo.fetchSummary(
        actorId: f.actor?.id,
        actions: f.action == null ? null : [f.action!.name],
        tables: f.tables,
        from: f.from,
        to: f.to?.add(const Duration(days: 1)),
        query: f.query.trim().isEmpty ? null : f.query.trim(),
        seasonId: f.seasonScope.season?.id,
        seasonless: f.seasonScope.isNone,
      );
      if (seq != _requestSeq) return;
      emit(state.copyWith(summary: summary));
    } catch (_) {
      if (seq != _requestSeq) return;
      // Left absent. The header simply does not appear, which is honest — it
      // was never a claim the log could not be read without.
      emit(state.copyWith(summary: null));
    }
  }

  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore || state.events.isEmpty) return;
    final seq = _requestSeq;
    emit(state.copyWith(loadingMore: true));
    try {
      final page = await _fetch(beforeId: state.events.last.id);
      if (seq != _requestSeq) return;
      emit(
        state.copyWith(
          events: [...state.events, ...page],
          hasMore: page.length >= _pageSize,
          loadingMore: false,
        ),
      );
    } catch (_) {
      if (seq != _requestSeq) return;
      // The list already on screen is better than an error page; the reader
      // can scroll again to retry.
      emit(state.copyWith(loadingMore: false));
    }
  }

  Future<List<AuditEvent>> _fetch({int? beforeId}) {
    final f = state.filters;
    return _repo.fetchEvents(
      limit: _pageSize,
      beforeId: beforeId,
      actorId: f.actor?.id,
      actions: f.action == null ? null : [f.action!.name],
      tables: f.tables,
      from: f.from,
      // The picker hands back whole days; the upper bound is exclusive in the
      // RPC, so the chosen end day is pushed past its own midnight to include
      // everything that happened during it.
      to: f.to?.add(const Duration(days: 1)),
      query: f.query.trim().isEmpty ? null : f.query.trim(),
      seasonId: f.seasonScope.season?.id,
      seasonless: f.seasonScope.isNone,
    );
  }

  void setFilters(AuditFilters filters) {
    if (filters == state.filters) return;
    emit(state.copyWith(filters: filters));
    load();
  }

  void clearFilters() => setFilters(const AuditFilters());

  /// The person filter's option list, fetched on first open only.
  Future<List<AuditActor>> actors() async {
    if (state.actors.isNotEmpty) return state.actors;
    final actors = await _repo.fetchActors();
    emit(state.copyWith(actors: actors));
    return actors;
  }

  /// The season filter's option list, on the same terms: only the seasons the
  /// log actually holds something for, fetched once.
  Future<List<AuditSeason>> seasons() async {
    if (state.seasons.isNotEmpty) return state.seasons;
    final seasons = await _repo.fetchSeasons();
    emit(state.copyWith(seasons: seasons));
    return seasons;
  }
}
