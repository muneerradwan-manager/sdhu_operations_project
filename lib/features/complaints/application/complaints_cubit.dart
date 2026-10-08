import 'package:equatable/equatable.dart';

import '../../../core/bloc/safe_cubit.dart';
import '../../../core/utils/arabic_search.dart';
import '../data/complaints_repository.dart';
import '../domain/complaint.dart';

enum ComplaintsStatus { loading, ready, error }

/// Whose complaints the screen is showing.
///
/// Two lists, two doors, and not one screen with a switch on it: `mine` is
/// everybody's and hangs under العام, `all` asks for `complaints.view` and hangs
/// under الإدارة. The same screen answers both — what differs is which question
/// it asked the server, and the server refuses `all` to whoever may not ask it.
enum ComplaintsScope { mine, all }

class ComplaintsState extends Equatable {
  const ComplaintsState({
    this.scope = ComplaintsScope.mine,
    this.status = ComplaintsStatus.loading,
    this.complaints = const [],
    this.query = '',
    this.target,
    this.includeDismissed = true,
    this.error,
  });

  final ComplaintsScope scope;
  final ComplaintsStatus status;
  final List<Complaint> complaints;
  final String query;
  final ComplaintTarget? target;
  final bool includeDismissed;
  final String? error;

  bool get isNarrowed =>
      query.trim().isNotEmpty || target != null || !includeDismissed;

  /// The list after the reader's narrowing.
  ///
  /// The server can narrow too — `complaints_list` takes the same three — but
  /// it is asked only on the first read. A hundred rows are already in hand and
  /// a round trip per keystroke would be slower and no more correct.
  List<Complaint> get visible => complaints.where((c) {
    if (target != null && c.target != target) return false;
    if (!includeDismissed && c.isDismissed) return false;
    return arabicMatchesAll([
      c.targetLabel,
      c.body,
      c.complainantName,
    ], query);
  }).toList();

  ComplaintsState copyWith({
    ComplaintsScope? scope,
    ComplaintsStatus? status,
    List<Complaint>? complaints,
    String? query,
    ComplaintTarget? target,
    bool clearTarget = false,
    bool? includeDismissed,
    String? error,
  }) => ComplaintsState(
    scope: scope ?? this.scope,
    status: status ?? this.status,
    complaints: complaints ?? this.complaints,
    query: query ?? this.query,
    target: clearTarget ? null : (target ?? this.target),
    includeDismissed: includeDismissed ?? this.includeDismissed,
    error: error,
  );

  @override
  List<Object?> get props => [
    scope,
    status,
    complaints,
    query,
    target,
    includeDismissed,
    error,
  ];
}

class ComplaintsCubit extends SafeCubit<ComplaintsState> {
  ComplaintsCubit(this._repo, {ComplaintsScope scope = ComplaintsScope.mine})
    : super(ComplaintsState(scope: scope)) {
    load();
  }

  final ComplaintsRepository _repo;

  Future<void> load() async {
    emit(state.copyWith(status: ComplaintsStatus.loading, error: null));
    try {
      final complaints = await _repo.fetchList(
        all: state.scope == ComplaintsScope.all,
      );
      emit(
        state.copyWith(
          status: ComplaintsStatus.ready,
          complaints: complaints,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(status: ComplaintsStatus.error, error: e.toString()),
      );
    }
  }

  void search(String value) => emit(state.copyWith(query: value));

  void setTarget(ComplaintTarget? target) => emit(
    target == null
        ? state.copyWith(clearTarget: true)
        : state.copyWith(target: target),
  );

  void setIncludeDismissed(bool value) =>
      emit(state.copyWith(includeDismissed: value));

  void clearFilters() => emit(
    state.copyWith(query: '', clearTarget: true, includeDismissed: true),
  );
}
