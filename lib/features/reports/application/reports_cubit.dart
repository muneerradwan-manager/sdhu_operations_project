import 'package:equatable/equatable.dart';

import '../../../core/bloc/safe_cubit.dart';
import '../../../core/utils/arabic_search.dart';
import '../../seasons/data/seasons_repository.dart';
import '../data/reports_repository.dart';
import '../domain/report.dart';
import '../domain/report_type.dart';

enum ReportsStatus { loading, ready, error }

/// Which reports the list is showing.
enum ReportScope {
  /// Everything the reader may see.
  all,

  /// Tied to the season being run.
  seasonal,

  /// True whichever season it is.
  general,
}

class ReportsState extends Equatable {
  const ReportsState({
    this.status = ReportsStatus.loading,
    this.reports = const [],
    this.types = const [],
    this.query = '',
    this.scope = ReportScope.all,
    this.error,
  });

  final ReportsStatus status;
  final List<Report> reports;

  /// The catalog. Kept for the report cards, which name what kind each one is;
  /// the reader is never offered the TYPE as a way of narrowing, because to
  /// them these are all simply تقارير. The scope — الكل, هذا الموسم, عام — is
  /// the only division that means anything on this screen.
  final List<ReportType> types;

  final String query;
  final ReportScope scope;
  final String? error;

  bool get isNarrowed => query.trim().isNotEmpty || scope != ReportScope.all;

  /// The list after the reader's narrowing. Done here rather than in the
  /// database: the whole list is already in hand and it is tens of rows, not
  /// thousands — a round trip per keystroke would be slower and no more
  /// correct.
  List<Report> get visible {
    return reports.where((r) {
      switch (scope) {
        case ReportScope.seasonal:
          if (!r.isSeasonal) return false;
        case ReportScope.general:
          if (r.isSeasonal) return false;
        case ReportScope.all:
          break;
      }
      return arabicMatchesAll([
        r.title,
        r.number,
        r.typeName?.ar,
        r.typeName?.en,
      ], query);
    }).toList();
  }

  ReportsState copyWith({
    ReportsStatus? status,
    List<Report>? reports,
    List<ReportType>? types,
    String? query,
    ReportScope? scope,
    String? error,
  }) => ReportsState(
    status: status ?? this.status,
    reports: reports ?? this.reports,
    types: types ?? this.types,
    query: query ?? this.query,
    scope: scope ?? this.scope,
    error: error,
  );

  @override
  List<Object?> get props => [status, reports, types, query, scope, error];
}

class ReportsCubit extends SafeCubit<ReportsState> {
  ReportsCubit(this._repo, this._seasons) : super(const ReportsState()) {
    load();
  }

  final ReportsRepository _repo;
  final SeasonsRepository _seasons;

  Future<void> load() async {
    emit(state.copyWith(status: ReportsStatus.loading, error: null));
    try {
      // The list needs the season first; the type catalog needs neither, so it
      // rides alongside instead of queueing behind them. Future.wait and not
      // the record `.wait`, so a failure surfaces as the original exception.
      final results = await Future.wait<Object?>([
        _seasons.fetchCurrentSeason().then(
          (season) => _repo.fetchReports(seasonId: season?.id),
        ),
        _repo.fetchTypes(),
      ]);
      final reports = (results[0] as List).cast<Report>();
      final types = (results[1] as List).cast<ReportType>();
      emit(
        state.copyWith(
          status: ReportsStatus.ready,
          reports: reports,
          types: types,
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: ReportsStatus.error, error: e.toString()));
    }
  }

  void search(String value) => emit(state.copyWith(query: value));
  void setScope(ReportScope scope) => emit(state.copyWith(scope: scope));

  void clearFilters() =>
      emit(state.copyWith(query: '', scope: ReportScope.all));
}
