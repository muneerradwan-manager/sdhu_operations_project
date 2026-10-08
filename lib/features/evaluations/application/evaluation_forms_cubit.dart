import 'package:equatable/equatable.dart';

import '../../../core/bloc/safe_cubit.dart';
import '../../../core/utils/arabic_search.dart';
import '../data/evaluations_repository.dart';
import '../domain/evaluation.dart';

enum EvaluationFormsStatus { loading, ready, error }

class EvaluationFormsState extends Equatable {
  const EvaluationFormsState({
    this.status = EvaluationFormsStatus.loading,
    this.forms = const [],
    this.query = '',
    this.target,
    this.error,
  });

  final EvaluationFormsStatus status;
  final List<EvaluationFormSummary> forms;
  final String query;
  final EvaluationTarget? target;
  final String? error;

  bool get isNarrowed => query.trim().isNotEmpty || target != null;

  List<EvaluationFormSummary> get visible => forms.where((f) {
    if (target != null && f.target != target) return false;
    return arabicMatchesAll([f.title, f.description], query);
  }).toList();

  EvaluationFormsState copyWith({
    EvaluationFormsStatus? status,
    List<EvaluationFormSummary>? forms,
    String? query,
    EvaluationTarget? target,
    bool clearTarget = false,
    String? error,
  }) => EvaluationFormsState(
    status: status ?? this.status,
    forms: forms ?? this.forms,
    query: query ?? this.query,
    target: clearTarget ? null : (target ?? this.target),
    error: error,
  );

  @override
  List<Object?> get props => [status, forms, query, target, error];
}

/// The catalog of forms — إدارة التقييم, the half of this feature the office
/// owns.
class EvaluationFormsCubit extends SafeCubit<EvaluationFormsState> {
  EvaluationFormsCubit(this._repo) : super(const EvaluationFormsState()) {
    load();
  }

  final EvaluationsRepository _repo;

  Future<void> load() async {
    emit(state.copyWith(status: EvaluationFormsStatus.loading, error: null));
    try {
      final forms = await _repo.fetchForms();
      emit(
        state.copyWith(status: EvaluationFormsStatus.ready, forms: forms),
      );
    } catch (e) {
      emit(
        state.copyWith(status: EvaluationFormsStatus.error, error: e.toString()),
      );
    }
  }

  void search(String value) => emit(state.copyWith(query: value));

  void setTarget(EvaluationTarget? target) => emit(
    target == null
        ? state.copyWith(clearTarget: true)
        : state.copyWith(target: target),
  );

  void clearFilters() => emit(state.copyWith(query: '', clearTarget: true));

  /// Switching a form on and off. The one edit worth a single call: it is the
  /// difference between a form that may be assigned and one that may not, and
  /// it is made from the list far more often than from the editor.
  Future<String?> setActive(EvaluationFormSummary form, bool active) async {
    try {
      final full = await _repo.fetchForm(form.id);
      await _repo.saveForm(full.copyWith(isActive: active));
      await load();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Deleting one. The database refuses as soon as a single sheet has been
  /// opened on it — `on delete restrict` — and that refusal reaches the screen
  /// as an error rather than being predicted here, because
  /// [EvaluationFormSummary.isInUse] is a count read a moment ago and the
  /// constraint is the truth.
  Future<String?> delete(String templateId) async {
    try {
      await _repo.deleteForm(templateId);
      emit(
        state.copyWith(
          forms: [
            for (final f in state.forms)
              if (f.id != templateId) f,
          ],
        ),
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
