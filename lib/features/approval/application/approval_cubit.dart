import 'package:equatable/equatable.dart';

import '../../../core/bloc/safe_cubit.dart';
import '../../profile/domain/profile.dart';
import '../data/approval_repository.dart';

enum ApprovalStatus { loading, loaded, error }

class ApprovalState extends Equatable {
  const ApprovalState({
    this.status = ApprovalStatus.loading,
    this.pending = const [],
    this.error,
    this.processingIds = const {},
  });

  final ApprovalStatus status;
  final List<Profile> pending;
  final String? error;

  /// Ids currently being approved/rejected (for per-row spinners).
  final Set<String> processingIds;

  ApprovalState copyWith({
    ApprovalStatus? status,
    List<Profile>? pending,
    String? error,
    Set<String>? processingIds,
  }) {
    return ApprovalState(
      status: status ?? this.status,
      pending: pending ?? this.pending,
      error: error,
      processingIds: processingIds ?? this.processingIds,
    );
  }

  @override
  List<Object?> get props => [status, pending, error, processingIds];
}

class ApprovalCubit extends SafeCubit<ApprovalState> {
  ApprovalCubit(this._repo) : super(const ApprovalState()) {
    load();
  }

  final ApprovalRepository _repo;

  Future<void> load() async {
    emit(state.copyWith(status: ApprovalStatus.loading));
    try {
      final pending = await _repo.fetchPending();
      emit(state.copyWith(status: ApprovalStatus.loaded, pending: pending));
    } catch (e) {
      emit(state.copyWith(status: ApprovalStatus.error, error: e.toString()));
    }
  }

  Future<bool> approve(String id) => _run(id, () => _repo.approve(id));

  Future<bool> reject(String id, String? reason) =>
      _run(id, () => _repo.reject(id, reason));

  Future<bool> _run(String id, Future<void> Function() action) async {
    emit(state.copyWith(processingIds: {...state.processingIds, id}));
    try {
      await action();
      final remaining = state.pending.where((p) => p.id != id).toList();
      emit(
        state.copyWith(
          pending: remaining,
          processingIds: state.processingIds.difference({id}),
        ),
      );
      return true;
    } catch (e) {
      emit(
        state.copyWith(
          error: e.toString(),
          processingIds: state.processingIds.difference({id}),
        ),
      );
      return false;
    }
  }
}
